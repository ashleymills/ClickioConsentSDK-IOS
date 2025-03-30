//
//  AirBridgeChecker.swift
//  ClickioConsentSDKManager
//

import Foundation

// MARK: - AirBridgeChecker
final class AirBridgeChecker {
    // MARK: Properties
    @MainActor static let logger = EventLogger()
    
    // MARK: Methods
    /// Checks if the AirBridge SDK is integrated into the application.
    static func isAvailable() -> Bool {
        NSClassFromString("AirBridge") != nil
    }
    
    /*
     * Dynamically sets consent settings for Airbridge.
     * Parameters:
     * - exportData: ExportData object providing consent settings (GoogleConsentMode).
     * - consentStatus: Object containing consent status (e.g., scope).
     */
    @MainActor static func setConsentsToAirbridge(exportData: ExportData?, consentStatus: ConsentStatusDTO?) {
        logger.log("Setting consent to AirBridge", level: .info)
        
        guard let consent = exportData?.getGoogleConsentMode() else {
            logger.log("Google Consent Mode is unavailable", level: .error)
            return
        }
        
        guard let airbridgeClass = NSClassFromString("AirBridge") as? NSObject.Type else {
            logger.log("No Google consent mode data or AirBridge is unavailable", level: .info)
            return
        }
        
        let stateSelector = Selector(("state"))
        guard airbridgeClass.responds(to: stateSelector),
              let state = airbridgeClass.perform(stateSelector).takeUnretainedValue() as? NSObject else {
            logger.log("AirBridge.state not found", level: .error)
            return
        }
        
        let setDeviceAliasSelector = Selector(("setDeviceAliasWithKey:value:"))
        guard state.responds(to: setDeviceAliasSelector) else {
            logger.log("AirBridgeState does not respond to setDeviceAliasWithKey:value:", level: .error)
            return
        }
        
        let eeaValue = (consentStatus?.scope == "gdpr") ? "1" : "0"
        let adPersonalizationValue = consent.adPersonalizationGranted ? "1" : "0"
        let adUserDataValue = consent.adUserDataGranted ? "1" : "0"
        
        let performSelector = { (key: String, value: String) in
            let _ = state.perform(setDeviceAliasSelector, with: key, with: value)
        }
        
        performSelector("eea", eeaValue)
        performSelector("adPersonalization", adPersonalizationValue)
        performSelector("adUserData", adUserDataValue)
        
        logger.log("Consent sent to AirBridge", level: .info)
    }
}
