//
//  AppsFlyerChecker.swift
//  ClickioConsentSDKManager
//

import Foundation

// MARK: - AppsFlyerChecker
final class AppsFlyerChecker {
    // MARK: Properties
    @MainActor static let logger = EventLogger()
    
    // MARK: Methods
    /*
     * Checks if the AppsFlyer SDK is integrated into the application.
     */
    static func isAvailable() -> Bool {
        NSClassFromString("AppsFlyerLib") != nil
    }
    
    /*
     * Dynamically sets consent settings for AppsFlyer.
     * Parameters:
     * - exportData: ExportData object providing GoogleConsentMode.
     * - consentStatus: Object containing consent status (e.g., scope).
     */
    @MainActor static func setConsentsToAppsFlyer(exportData: ExportData?, consentStatus: ConsentStatusDTO?) {
        logger.log("Setting consent to AppsFlyer", level: .info)
        
        guard let consent = exportData?.getGoogleConsentMode() else {
            logger.log("Google Consent Mode is unavailable", level: .error)
            return
        }
        
        guard let appsFlyerClass = NSClassFromString("AppsFlyerLib") as? NSObject.Type else {
            logger.log("AppsFlyer SDK is not found", level: .error)
            return
        }
        
        let sharedSelector = Selector(("shared"))
        guard let sharedObj = appsFlyerClass.perform(sharedSelector)?
            .takeUnretainedValue() as? NSObject else {
            logger.log("AppsFlyer.shared() is not available", level: .error)
            return
        }
        
        guard let consentClass = NSClassFromString("AppsFlyerConsent") as? NSObject.Type else {
            logger.log("AppsFlyerConsent class not found, falling back to TCF", level: .error)
            enableAutomaticTCF(on: appsFlyerClass)
            return
        }
        
        let afConsent = consentClass.init()
        let isEEA = NSNumber(value: consentStatus?.scope == "gdpr")
        afConsent.setValue(isEEA, forKey: "isUserSubjectToGDPR")
        
        if isEEA.boolValue {
            let dataUsage = consent.adUserDataGranted ? "granted" : "denied"
            let adsPers = consent.adPersonalizationGranted ? "granted" : "denied"
            
            afConsent.setValue(dataUsage, forKey: "hasConsentForDataUsage")
            afConsent.setValue(adsPers, forKey: "hasConsentForAdsPersonalization")
        }
        
        let setConsentSel = Selector(("setConsentData:"))
        if sharedObj.responds(to: setConsentSel) {
            sharedObj.perform(setConsentSel, with: afConsent)
            logger.log("Consent sent via AppsFlyerConsent object", level: .info)
        } else {
            logger.log("setConsentData: selector not found, falling back to TCF", level: .error)
            enableAutomaticTCF(on: appsFlyerClass)
        }
    }
    
    @MainActor
    private static func enableAutomaticTCF(on afClass: NSObject.Type) {
        let tcfSel = Selector(("enableTCFDataCollection:"))
        if afClass.responds(to: tcfSel) {
            afClass.perform(tcfSel, with: true)
            logger.log("Automatic TCF collection enabled", level: .info)
        } else {
            logger.log("enableTCFDataCollection: selector not found", level: .error)
        }
    }
}
