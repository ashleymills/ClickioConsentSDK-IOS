//
//  ExportData.swift
//  ClickioSDK_Integration_Example_iOS
//

import Foundation

// MARK: - ExportData
@objcMembers public final class ExportData: NSObject {
    // MARK: Properties
    private let userDefaults = UserDefaults.standard
    private let granted = "granted"
    
    // MARK: Private methods
    private func parseBinaryString(_ binaryString: String?) -> [Int]? {
        guard let binaryString = binaryString, !binaryString.isEmpty else { return nil }
        return binaryString.enumerated().compactMap { index, char in
            char == "1" ? index + 1 : nil
        }
    }
    
    // MARK: Public methods
    /**
     * Returns IAB TCF v2.2 string if exists.
     */
    public func getTCString() -> String? {
        let key = "IABTCF_TCString"
        return userDefaults.string(forKey: key)
    }
    
    /**
     * Returns the Google additional consent ID if exists.
     */
    public func getACString() -> String? {
        let key = "IABTCF_AddtlConsent"
        return userDefaults.string(forKey: key)
    }
    
    /**
     * Returns Global Privacy Platform String if exists.
     */
    public func getGPPString() -> String? {
        let key = "IABGPP_HDR_GppString"
        return userDefaults.string(forKey: key)
    }
    
    /**
     *  Returns Google Consent Mode v2 flags.
     */
    public func getGoogleConsentMode() -> GoogleConsentStatus? {
        let adStorageString = userDefaults.string(forKey: "CLICKIO_CONSENT_GOOGLE_ANALYTICS_adStorage")
        let analyticsStorageString = userDefaults.string(forKey: "CLICKIO_CONSENT_GOOGLE_ANALYTICS_analyticsStorage")
        let adUserDataString = userDefaults.string(forKey: "CLICKIO_CONSENT_GOOGLE_ANALYTICS_adUserData")
        let adPersonalizationString = userDefaults.string(forKey: "CLICKIO_CONSENT_GOOGLE_ANALYTICS_adPersonalization")
        
        if adStorageString?.isEmpty == true
            && analyticsStorageString?.isEmpty == true
            && adUserDataString?.isEmpty == true
            && adPersonalizationString?.isEmpty == true {
            return nil
        }
        
        return GoogleConsentStatus(
            analyticsStorageGranted: analyticsStorageString == granted,
            adStorageGranted: adStorageString == granted,
            adUserDataGranted: adUserDataString == granted,
            adPersonalizationGranted: adPersonalizationString == granted
        )
    }
    
    /**
     * Returns id's of TCF Vendors that given consent.
     */
    public func getConsentedTCFVendors() -> [Int]? {
        let key = "IABTCF_VendorConsents"
        return parseBinaryString(userDefaults.string(forKey: key))
    }
    
    /**
     * Returns id's of TCF Vendors that given consent for legitimate interests.
     */
    public func getConsentedTCFLiVendors() -> [Int]? {
        let key = "IABTCF_VendorLegitimateInterests"
        return parseBinaryString(userDefaults.string(forKey: key))
    }
    
    /**
     * Returns id's of TCF purposes that given consent.
     */
    public func getConsentedTCFPurposes() -> [Int]? {
        let key = "IABTCF_PurposeConsents"
        return parseBinaryString(userDefaults.string(forKey: key))
    }
    
    /**
     * Returns id's of TCF purposes that given consent as Legitimate Interest.
     */
    public func getConsentedTCFLiPurposes() -> [Int]? {
        let key = "IABTCF_PurposeLegitimateInterests"
        return parseBinaryString(userDefaults.string(forKey: key))
    }
    
    /**
     * Returns id's of Google Vendors that given consent.
     */
    public func getConsentedGoogleVendors() -> [Int]? {
        let key = "IABTCF_AddtlConsent"
        guard let consentString = userDefaults.string(forKey: key) else { return nil }
        let parts = consentString.split(separator: "~")
        if parts.count > 1 { return parts[1].split(separator: ".").compactMap { Int($0) } }
        return nil
    }
    
    /**
     * Returns id's of non-TCF Vendors that given consent.
     */
    public func getConsentedOtherVendors() -> [Int]? {
        let key = "CLICKIO_CONSENT_other_vendors_consent"
        return userDefaults.string(forKey: key)?
            .split(separator: ",")
            .compactMap { Int($0) }
    }
    
    /**
     * Returns id's of non-TCF Vendors that given consent for legitimate interests.
     */
    public func getConsentedOtherLiVendors() -> [Int]? {
        let key = "CLICKIO_CONSENT_other_vendors_leg_int"
        return userDefaults.string(forKey: key)?
            .split(separator: ",")
            .compactMap { Int($0) }
    }
    
    /**
     * Returns id's of non-TCF purposes (simplified purposes) that given consent.
     */
    public func getConsentedNonTcfPurposes() -> [Int]? {
        let key = "CLICKIO_CONSENT_other_purposes_consent"
        return userDefaults.string(forKey: key)?
            .split(separator: ",")
            .compactMap { Int($0) }
    }
}

// MARK: - GoogleConsentStatus
public struct GoogleConsentStatus {
    public var analyticsStorageGranted = false
    public var adStorageGranted = false
    public var adUserDataGranted = false
    public var adPersonalizationGranted = false
}
