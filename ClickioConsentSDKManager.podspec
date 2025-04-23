#

Pod::Spec.new do |spec|

  spec.name         = "ClickioConsentSDKManager"
  
  spec.module_name  = "ClickioConsentSDKManager"
  
  spec.version      = "1.0.1"
  
  spec.summary      = "Native SDK for managing user consents, integrating a WebView-based consent dialog into iOS apps for streamlined privacy compliance."
  
  spec.description  = <<-DESC
                      ClickioConsentSDK is a robust privacy-focused toolkit designed to simplify GDPR, CCPA, and global compliance for iOS apps. It features a fully customizable WebView-based consent dialog that seamlessly integrates with your app's UI while dynamically adapting to regional regulations. Key capabilities include:

                      * ATT-CMP Flow Orchestration: Optional App Tracking Transparency (ATT) pre-permission prompts with logic to conditionally display consent dialogs based on user choices.
                      * Real-Time Compliance: Automatic updates for consent texts/purposes via centralized configurations without app store resubmissions.
                      * Granular Control: Capture user preferences for ads, analytics, and data sharing with purpose/VendorID-level consent tracking.
                      * Cross-Platform Sync: Export standardized TC/AC Strings and Google Consent Mode signals for backend/services alignment.
                      * Developer-Centric: Objective-C, SwiftUI, UIKit support and extensible web-to-native communication layer.

                      Ideal for apps requiring scalable privacy management with minimal code footprint, ensuring audit-ready compliance across jurisdictions.'
                      DESC
  
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  
  spec.authors      = { 'Clickio' => 'app-dev@clickio.com' }
  
  spec.homepage     = "https://clickio.com/"
  
  spec.platform     = :ios, "15.0"
  
  spec.source       = { :git => "https://github.com/ClickioTech/ClickioConsentSDK-IOS.git", :tag => "#{spec.version}" }
  
  spec.source_files = ["Sources/**/*.swift"]

  spec.frameworks = "WebKit", "UIKit", "Foundation"
  
  spec.weak_frameworks = "AppTrackingTransparency", "Combine"
  
  spec.swift_version = '5.0'
  
  spec.pod_target_xcconfig = {
    'CODE_SIGNING_REQUIRED' => 'NO',
    'CODE_SIGNING_ALLOWED' => 'NO',
    'EXPANDED_CODE_SIGN_IDENTITY' => '',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO'
  }
  
  # Settings for host-project
  spec.user_target_xcconfig = {
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO'
  }

end
