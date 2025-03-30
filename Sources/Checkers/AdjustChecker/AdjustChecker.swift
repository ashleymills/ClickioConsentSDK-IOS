//
//  AdjustChecker.swift
//  ClickioConsentSDKManager
//

import Foundation

// MARK: - AdjustChecker
final class AdjustChecker {
    // MARK: Properties
    @MainActor static let logger = EventLogger()
    
    // MARK: Methods
    /*
     * Checks if the Adjust SDK is integrated into the application.
     */
    static func isAvailable() -> Bool {
        NSClassFromString("ADJThirdPartySharing") != nil
    }
    
    /* Dynamically sets consent settings for Adjust.
     * Parameters:
     * - exportData: ExportData object providing GoogleConsentMode.
     * - consentStatus: Object containing the consent status (e.g., scope).
     */
    @MainActor static func setConsentsToAdjust(exportData: ExportData?, consentStatus: ConsentStatusDTO?) {
        logger.log("Setting consent to Adjust", level: .info)
        
        guard let consent = exportData?.getGoogleConsentMode() else {
            logger.log("Google Consent Mode is unavailable", level: .info)
            return
        }
        
        let eeaValue = (consentStatus?.scope == "gdpr") ? "1" : "0"
        let adPersonalizationValue = (consent.adPersonalizationGranted == true) ? "1" : "0"
        let adUserDataValue = (consent.adUserDataGranted == true) ? "1" : "0"

        guard let sharingClass = NSClassFromString("ADJThirdPartySharing") as? NSObject.Type else {
            logger.log("ADJThirdPartySharing is NOT available", level: .error)
            return
        }
        
        let allocSelector = Selector(("alloc"))
        guard let sharingInstanceAlloc = sharingClass.perform(allocSelector)?.takeUnretainedValue() as? NSObject else {
            logger.log("Unable to allocate ADJThirdPartySharing instance", level: .error)
            return
        }
        
        let initSelector = Selector(("initWithIsEnabled:"))
        guard sharingInstanceAlloc.responds(to: initSelector) else {
            logger.log("ADJThirdPartySharing does not respond to initWithIsEnabled:", level: .error)
            return
        }
        
        guard let sharingInstanceUncasted = sharingInstanceAlloc.perform(initSelector, with: true)?.takeUnretainedValue() else {
            logger.log("Unable to initialize ADJThirdPartySharing instance", level: .error)
            return
        }
        guard let adjustSharingInstance = sharingInstanceUncasted as? NSObject else {
            logger.log("Unable to cast ADJThirdPartySharing instance to NSObject", level: .error)
            return
        }

        let addGranularOptionSelector = Selector(("addGranularOption:key:value:"))
        guard adjustSharingInstance.responds(to: addGranularOptionSelector) else {
            logger.log("ADJThirdPartySharing does not respond to addGranularOption:key:value:", level: .error)
            return
        }
        
        if let methodIMP = adjustSharingInstance.method(for: addGranularOptionSelector) {
            logger.log("MethodIMP was entered successfully", level: .debug)
            typealias Function = @convention(c) (NSObject, Selector, NSString, NSString, NSString) -> Void
           
            let function = unsafeBitCast(methodIMP, to: Function.self)

            function(adjustSharingInstance, addGranularOptionSelector, "google_dma", "eea", eeaValue as NSString)
            function(adjustSharingInstance, addGranularOptionSelector, "google_dma", "ad_personalization", adPersonalizationValue as NSString)
            function(adjustSharingInstance, addGranularOptionSelector, "google_dma", "ad_user_data", adUserDataValue as NSString)
        } else {
            logger.log("MethodIMP is unavailable", level: .error)
        }
      
        guard let adjustClass = NSClassFromString("Adjust") as? NSObject.Type else {
            logger.log("Adjust class is NOT available", level: .error)
            return
        }
        
        let trackSelector = Selector(("trackThirdPartySharing:"))
        if adjustClass.responds(to: trackSelector) {
            adjustClass.perform(trackSelector, with: adjustSharingInstance)
            logger.log("Adjust.trackThirdPartySharing called dynamically", level: .info)
            logger.log("Sending parameters to selector method: \(eeaValue), \(adPersonalizationValue), \(adUserDataValue)", level: .debug)
        } else {
            logger.log("Adjust does not respond to trackThirdPartySharing:", level: .error)
        }
        logger.log("Consent sent to Adjust", level: .info)
    }
}
