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
    }
}
