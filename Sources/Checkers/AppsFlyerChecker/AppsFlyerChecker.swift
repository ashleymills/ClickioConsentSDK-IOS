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
        guard appsFlyerClass.responds(to: sharedSelector),
              let instance = appsFlyerClass.perform(sharedSelector).takeUnretainedValue() as? NSObject else {
            logger.log("AppsFlyer.shared instance is not available", level: .error)
            return
        }
        
        let consentData: [String: Any] = [
            "is_eea": (consentStatus?.scope == "gdpr") ? true : false,
            "ad_user_data": consent.adUserDataGranted == true ? "granted" : "denied",
            "ad_personalization": consent.adPersonalizationGranted == true ? "granted" : "denied"
        ]
        
        let selector = Selector(("setConsentData:"))
        guard instance.responds(to: selector) else {
            logger.log("AppsFlyerLib does not respond to setConsentData:", level: .error)
            return
        }
        
        instance.perform(selector, with: NSDictionary(dictionary: consentData))
        logger.log("Consent sent to AppsFlyer", level: .info)
    }
}
