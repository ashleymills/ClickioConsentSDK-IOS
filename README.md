# Clickio Consent SDK Manager for iOS
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Setup and Usage](#setup-and-usage)
- [ExportData](#exportdata)
- [Integration with Third-Party Libraries for Google Consent Mode](#integration-with-third-party-libraries-for-google-consent-mode)
- [Integration with Third-Party Libraries when Google Consent Mode is disabled](#integration-with-third-party-libraries-when-google-consent-mode-is-disabled)

## Requirements

Before integrating `ClickioConsentSDKManager` (hereinafter reffered to as the `Clickio SDK`), ensure that your application meets the following requirements:

-   **Minimum iOS Version:** 15.0+
-   **Swift:** 5.0+
    
    
## Installation
 **Swift Package Manager**
-   File > Swift Packages > Add Package Dependency
-   Add  `https://github.com/ClickioTech/ClickioConsentSDK-IOS.git`
-   Select "Up to Next Major" with "1.0.6-rc"

 **CocoaPods**  
 -   You can install ClickioConsentSDKManager pod from CocoaPods library:  
  ```source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'ClickioConsentSDKManager', '~> 1.0.6-rc'
end
```

-   Or you can install ClickioConsentSDKManager pod directly from our open Github repository: 
  ```source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'ClickioConsentSDKManager', :git => 'https://github.com/ClickioTech/ClickioConsentSDK-IOS.git', :tag => '1.0.6-rc'
end
```


 **Pre-built Framework**
-  Open the release page, download the latest version of `ClickioConsentSDKManager` from the assets section.
-  Drag the  `ClickioConsentSDKManager.xcframework`  into your project and add it to the target (usually the app target).
-  Select your target, in the "General" Tab, find the "Frameworks, Libraries, and Embedded Content" section, set the  `Embed Without Signing`  to `ClickioConsentSDKManager`.

## Quick Start

Here's the minimal implementation to get started:
**Import ClickioConsentSDKManager into your project file.**
```Swift
import ClickioConsentSDKManager
```
**Make sure to replace string "Your Clickio Site ID" with yours  [Site id](https://docs.clickio.com/books/clickio-consent-cmp/page/google-consent-mode-v2-implementation#bkmrk-access-the-template%3A)**.

```Swift
let clickioSdk = ClickioConsentSDK.shared
let config = ClickioConsentSDK.Config(siteId: "Your Clickio Site ID")

Task {
    await clickioSdk.initialize(configuration: config)
    
    clickioSdk.onReady {
        clickioSdk.openDialog()
    }
}
```
In this code after successful initialization, the SDK will open the Consent Window (a transparent `UIViewController` with a `WebView`).


## Setup and Usage

### App Tracking Transparency Permission (ATT Permission)
`Clickio SDK` supports [two distinct scenarios](#available-flows-examples) for handling `ATT permissions`. If your application collects user data and shares it with third parties for tracking purposes across apps and websites, you must:​

1.  Include the [`NSUserTrackingUsageDescription`](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSUserTrackingUsageDescription)  key in your app's `Info.plist` file.​
    
2.  Select an appropriate ATT permission display scenario provided by the SDK through [`openDialog`](#opening-the-consent-dialog) method.

If your application already manages ATT permissions independently and includes the [`NSUserTrackingUsageDescription`](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSUserTrackingUsageDescription)  key, you can skip this configuration step and proceed with the integration. 

#### Important:
- **make sure that user has given permission in the ATT dialog and only then perfrom [`openDialog`](#opening-the-consent-dialog) method call! Showing CMP regardles given ATT Permission is not recommended by Apple. Moreover, [`openDialog`](#opening-the-consent-dialog) API call can be blocked by Apple until user makes their choice.**

For more information about app tracking and privacy, see [User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/) and [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

### Singleton Access

All interactions with the Clickio SDK should be done using the  `ClickioConsentSDK.shared`  property to obtain the singleton instance of the SDK.

### Initialization

To initialize the SDK, use the  `initialize`  method:

```Swift
ClickioConsentSDK.shared.initialize(config: Config)
```
The SDK requires a configuration object with the following parameters:

```Swift
class Config(
    var siteId: String, // Your Clickio Site ID
    var appLanguage: String? // Optional, two-letter language code in ISO 639-1
)
```

[ISO 639-1](https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes)

### Setup of logging

- Use the `setLogsMode` method to set-up desired logging mode: it can be `.disabled` or `.verbose`:
```Swift
ClickioConsentSDK.shared.setLogsMode(.verbose)
```  
Note: this method is optional. If you won't use it, by default you will receive logs of all levels in your console.

### Handling SDK Readiness
  
Use the  `onReady`  callback to execute actions once the SDK is fully loaded:

```Swift
ClickioConsentSDK.shared.onReady {  
    ClickioConsentSDK.shared.openDialog()
}
```

The SDK should not be used before  `onReady`  is triggered, as it may lead to outdated data or errors.

### Functionality Overview

#### Opening the Consent Dialog

Clickio SDK provides the `openDialog` method to display the consent screen both in `UIKit` and `SwiftUI` projects.

```Swift
ClickioConsentSDK.shared.openDialog(
    mode: ClickioConsentSDK.DialogMode,
    language: String? = nil, 
    in parentViewController: UIViewController? = nil,
    attNeeded: Bool
) {
     // This completion block will be called post-dismissal. Handle consent results, 
    // refresh UI, or execute post-CMP logic here.
    print("Dialog closed") 
}
```

##### Parameters:

-   **`mode`**  – Defines when the dialog should be shown. Possible values:
    -   `DialogMode.default`  – Opens the dialog if GDPR applies and user hasn't given consent.
    -   `DialogMode.resurface`  – Always forces dialog to open, regardless of the user’s jurisdiction, allowing users to modify settings for GDPR compliance or to opt out under US regulations.

-   **`language`**  – Allows you to explicitly specify language of consent dialog. This parameter is optional, and if not provided, the SDK will automatically use english language for presentation.

-   **`in`**  – Allows you to explicitly specify on which `UIViewController` the dialog will be presented. This parameter is optional, and if not provided, the SDK will automatically use the root controller for presentation.

-   **`attNeeded`**  – Allows you to specify whether an ATT permission is necessary.
    - If your app has it's own ATT Permission manager you just pass `false` in `attNeeded` parameter and call your own ATT method. 

#### Available flows examples

1. **Show ATT Permission first, then show Consent Dialog only if user has granted ATT Permission. This approach is recommended by Apple:**
```Swift
ClickioConsentSDK.shared.openDialog(
    mode: ClickioConsentSDK.DialogMode,
    attNeeded: true
) {
    print("First scenario")
}
```
2. **Show only Consent Dialog bypassing ATT Permission demonstration:**
```Swift
ClickioConsentSDK.shared.openDialog(
    mode: ClickioConsentSDK.DialogMode,
    attNeeded: false
) {
    print("Second scenario")
}
```
#### Important:
- **we suggest you to use this approach only if you handle ATT Permission on your own.**
- **make sure that user has given permission in the ATT dialog and only then perfrom [`openDialog`](#opening-the-consent-dialog) method call! Otherwise it will lead to incorrect work of the SDK: showing CMP regardles given ATT Permission is not recommended by Apple. Moreover, [`openDialog`](#opening-the-consent-dialog) API calls to SDK's domains will be blocked by Apple until user provides their permission in ATT dialog.**

----------

#### Consent Update Callback

The SDK provides an  `onConsentUpdated`  callback that is triggered whenever consent is updated:

```Swift
ClickioConsentSDK.shared.onConsentUpdated { 
    // Handle consent update logic
}
```
----------

### Logging


To enable logging, use the following method:
```Swift
ClickioConsentSDK.shared.setLogsMode(_ mode: EventLogger.Mode)

- `mode` parameter defines whether logging is enabled or not:
    -   `EventLogger.Mode.disabled` – Disables logging, default value
    -   `EventLogger.Mode.verbose`  – Enables logging
```
----------

### Checking Consent Scope
```Swift
ClickioConsentSDK.shared.checkConsentScope() -> String?
```
Returns the applicable consent scope as String.

#### Returns:

-   **"gdpr"**  – The user is subject to GDPR requirements.
-   **"us"**  – The user is subject to US requirements.
-   **"out of scope"**  – The user is not subject to GDPR/US, other cases.

----------

### Checking Consent State
```Swift
ClickioConsentSDK.shared.checkConsentState() -> ConsentState?
```
Determines the consent state based on the scope and force flag and returns ConsentState.

#### Returns:

-   **`ConsentState.notApplicable`**  – The user is not subject to GDPR/US.
-   **`ConsentState.gdprNoDecision`**  – The user is subject to GDPR but has not made a decision.
-   **`ConsentState.gdprDecisionObtained`**  – The user is subject to GDPR and has made a decision.
-   **`ConsentState.us`**  – The user is subject to US regulations.

----------

### Checking Consent for a Purpose
```Swift
ClickioConsentSDK.shared.checkConsentForPurpose(purposeId: Int) -> Bool?
```
Verifies whether consent for a specific  [TCF purpose](https://iabeurope.eu/iab-europe-transparency-consent-framework-policies/#headline-24-18959)  has been granted by using  `IABTCF_PurposeConsents`  string.

----------

### Checking Consent for a Vendor
```Swift
ClickioConsentSDK.shared.checkConsentForVendor(vendorId: Int) -> Bool?
```
Verifies whether consent for a specific  [TCF vendor](https://iabeurope.eu/vendor-list-tcf/)  has been granted by using  `IABTCF_VendorConsents`  string.

----------

## ExportData

`ExportData`  is a class designed to retrieve consent values from  `UserDefaults`. It provides methods to obtain various types of consent, including TCF, Google Consent Mode, and others.

_Example of use_
```Swift
let exportData = ExportData()
var valueOfTCString = exportData.getTCString()
var listOfconsentedTCFPurposes = exportData.getConsentedTCFPurposes()
```
----------

### Methods

### `getTCString`
```Swift
func getTCString() -> String?
```
Returns the IAB TCF v2.2 string if it exists.

----------

### `getACString`
```Swift
func getACString() -> String?
```
Returns the Google additional consent string if it exists.

----------

### `getGPPString`
```Swift
func getGPPString() -> String?
```
Returns the Global Privacy Platform (GPP) string if it exists.

----------

### `getConsentedTCFVendors`
```Swift
func getConsentedTCFVendors() -> [Int]?
```
Returns the IDs of TCF vendors that have given consent.

----------

### `getConsentedTCFLiVendors`
```Swift
func getConsentedTCFLiVendors() -> [Int]?
```
Returns the IDs of TCF vendors that have given consent for legitimate interests.

----------

### `getConsentedTCFPurposes`
```Swift
func getConsentedTCFPurposes() -> [Int]?
```
Returns the IDs of TCF purposes that have given consent.

----------

### `getConsentedTCFLiPurposes`
```Swift
func getConsentedTCFLiPurposes() -> [Int]?
```
Returns the IDs of TCF purposes that have given consent as Legitimate Interest.

----------

### `getConsentedGoogleVendors`
```Swift
func getConsentedGoogleVendors() -> [Int]?
```
Returns the IDs of Google vendors that have given consent.

----------

### `getConsentedOtherVendors`
```Swift
func getConsentedOtherVendors() -> [Int]?
```
Returns the IDs of non-TCF vendors that have given consent.

----------

### `getConsentedOtherLiVendors`
```Swift
func getConsentedOtherLiVendors() -> [Int]?
```
Returns the IDs of non-TCF vendors that have given consent for legitimate interests.

----------

### `getConsentedNonTcfPurposes`
```Swift
func getConsentedNonTcfPurposes() -> [Int]?
```
Returns the IDs of non-TCF purposes (simplified purposes) that have given consent.

----------

### `getGoogleConsentMode`
```Swift
func getGoogleConsentMode() -> GoogleConsentStatus?
```
Returns Google Consent Mode v2 flags wrapped into  `GoogleConsentStatus`  struct if Google Consent Mode enabled, otherwise will return  `false`.
```Swift
struct GoogleConsentStatus (
    var analyticsStorageGranted = false
    var adStorageGranted = false
    var adUserDataGranted = false
    var adPersonalizationGranted = false
)
```
Represents the status of Google Consent Mode.

-   `analyticsStorageGranted`  — Consent for analytics storage.
-   `adStorageGranted`  — Consent for ad storage.
-   `adUserDataGranted`  — Consent for processing user data for ads.
-   `adPersonalizationGranted`  — Consent for ad personalization.

# Integration with Third-Party Libraries for Google Consent Mode

`ClickioConsentSDK` supports automatic integration with external analytics and advertising platforms for Google Consent Mode V2 if enabled:

-   [Firebase Analytics](https://firebase.google.com/docs/analytics)
-   [Adjust](https://www.adjust.com/)
-   [Airbridge](https://www.airbridge.io/)
-   [AppsFlyer](https://www.appsflyer.com/)

#### Important:
  - Interactions with `ClickioConsentSDK` should be performed **after initializing the third-party SDKs** since `ClickioConsentSDK` only transmits consent flags.
  - **Ensure** that you have completed the required tracking setup for Adjust, Airbridge, or AppsFlyer before integrating `ClickioConsentSDK`. This includes proper initialization and configuration of the SDK according to the vendor’s documentation.
  
### Firebase Analytics

If the Firebase Analytics SDK is present in the project, the Clickio SDK will automatically send Google Consent flags to Firebase if  _Clickio Google Consent Mode_  integration  **enabled**.

ClickioConsentSDK transmits consent flags immediately if they were updated after showing the consent dialog (when  `onConsentUpdated`  is called) or during initialization if the consent has been accepted.

After successfully transmitting the flags, a log message will be displayed (if logging is enabled) confirming the successful transmission. In case of an error, an error message will appear in the logs. You may need to update Firebase Analytics to a newer version in your project.

----------

### Adjust, Airbridge, AppsFlyer

If any of these SDKs (**Adjust, Airbridge, AppsFlyer**) are present in the project,  `ClickioConsentSDK`  will automatically send Google Consent flags to them if  _Clickio Google Consent Mode_  integration  **enabled**.

However, interactions with  `ClickioConsentSDK`  should be performed after initializing the SDK since  `ClickioConsentSDK`  only transmits consent flags, while the initialization and configuration of the libraries are the responsibility of the app developer.

After successfully transmitting the flags, a log message will be displayed (if logging is enabled) to confirm the successful transmission. In case of an error, an error message will appear in the logs. You may need to update the SDK you are using (Adjust, Airbridge, or AppsFlyer) to a newer version in your project.

## Integration with other libraries

For other libraries, you can use the  `getGoogleConsentMode`  method from the  `ExportData`  class to retrieve the  `GoogleConsentStatus`.

For example, you can subscribe to the  `onConsentUpdated`  callback and call  `getGoogleConsentMode`  within it.
```Swift
let exportData = ExportData()
ClickioConsentSDK.shared.onConsentUpdated { 
    var googleConsentFlags = exportData.getGoogleConsentMode()
    if googleConsentFlags != nil {
        // Send values to other SDK
    }
}
```

If you need to send consent data on each subsequent app launch, it is recommended to wait for the  `onReady`  callback and then call  `getGoogleConsentMode`.

**Keep in mind:**  `getGoogleConsentMode`  can return  `nil`  if Google Consent Mode is disabled or unavailable.

# Integration with Third-Party libraries when Google Consent Mode is disabled

If  _Clickio Google Consent Mode_  integration is  **disabled**  you can set consent flags manually.

_Firebase Analytics example:_

```Swift
ClickioConsentSDK.shared.onConsentUpdated {

let purpose1 = ClickioConsentSDK.shared.checkConsentForPurpose(purposeId:1)
let purpose3 = ClickioConsentSDK.shared.checkConsentForPurpose(purposeId:3)
let purpose4 = ClickioConsentSDK.shared.checkConsentForPurpose(purposeId:4)
let purpose7 = ClickioConsentSDK.shared.checkConsentForPurpose(purposeId:7)
let purpose8 = ClickioConsentSDK.shared.checkConsentForPurpose(purposeId:8)
let purpose9 = ClickioConsentSDK.shared.checkConsentForPurpose(purposeId:9)

let adStorage: ConsentStatus = purpose1! ? .granted : .denied
let adUserData: ConsentStatus = (purpose1! && (purpose7 != nil)) ? .granted : .denied
let adPersonalization: ConsentStatus = (purpose3! && (purpose4 != nil)) ? .granted : .denied
let analyticsStorage: ConsentStatus = (purpose8! && (purpose9 != nil)) ? .granted : .denied

let consentSettings: [ConsentType: ConsentStatus] = [
.adStorage: adStorage,
.adUserData: adUserData,
.adPersonalization: adPersonalization,
.analyticsStorage: analyticsStorage
]

Analytics.setConsent(consentSettings)
}
```

[More about Consent Mode flags mapping with TCF and non-TCF purposes](https://docs.clickio.com/books/clickio-consent-cmp/page/google-consent-mode-v2-implementation#bkmrk-5.1.-tcf-mode)
