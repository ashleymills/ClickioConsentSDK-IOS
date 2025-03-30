//
//  FirebaseChecker.swift
//  ClickioConsentSDKManager
//

import Foundation

// MARK: - FirebaseChecker
final class FirebaseChecker {
    // MARK: Properties
    @MainActor static let logger = EventLogger()
    
    // MARK: Methods
    /*
     * Checks if the Firebase SDK is integrated into the application.
     */
    static func isAvailable() -> Bool {
        NSClassFromString("FIRApp") != nil
    }
    
    /*
     * Maps isGranted parameter into string format for Firebase Analytics.
     */
    static func mapToFirebaseConsentStatus(isGranted: Bool?) -> Any {
        return isGranted == true ? "granted" : "denied"
    }
    
    /* Dynamically sets consent settings for Firebase Analytics.
     * Parameters:
     * - exportData: ExportData object providing GoogleConsentMode.
     */
    @MainActor static func setConsentsToFirebaseAnalytics(exportData: ExportData?) {
        logger.log("Setting consent to Firebase", level: .info)
        
        guard let consent = exportData?.getGoogleConsentMode() else {
            logger.log("Google Consent Mode is unavailable", level: .error)
            return
        }
        
        let consentDictionary: [String: Any] = [
            "ad_storage": mapToFirebaseConsentStatus(isGranted: consent.adStorageGranted),
            "analytics_storage": mapToFirebaseConsentStatus(isGranted: consent.analyticsStorageGranted),
            "ad_user_data": mapToFirebaseConsentStatus(isGranted: consent.adUserDataGranted),
            "ad_personalization": mapToFirebaseConsentStatus(isGranted: consent.adPersonalizationGranted)
        ]
        
        guard let analyticsClass = NSClassFromString("FIRAnalytics") as? NSObject.Type else {
            logger.log("FIRAnalytics is NOT available", level: .error)
            return
        }
        
        let setConsentSelector = Selector(("setConsent:"))
        logger.log("setConsentSelector is \(setConsentSelector)", level: .debug)
                
        if analyticsClass.responds(to: setConsentSelector) {
            logger.log("FIRAnalytics.setConsent called dynamically", level: .info)
            logger.log("Sending consent dictionary to selector method: \(consentDictionary)", level: .debug)
            analyticsClass.perform(setConsentSelector, with: consentDictionary)
        } else {
            logger.log("FIRAnalytics does not respond to setConsent:", level: .error)
        }
        
        if let analyticsClass = NSClassFromString("FIRAnalytics") as? NSObject.Type,
           analyticsClass.responds(to: Selector(("logEventWithName:parameters:"))) {
            logger.log("Start logging updated flags", level: .debug)
            let eventName = "consent_flags_updated"
            let parameters = consentDictionary as NSDictionary
            
            analyticsClass.perform(
                Selector(("logEventWithName:parameters:")),
                with: eventName,
                with: parameters
            )
            logger.log("Finish logging updated flags", level: .debug)
        }
        logger.log("Consent sent to Firebase Analytics", level: .info)
    }
}
