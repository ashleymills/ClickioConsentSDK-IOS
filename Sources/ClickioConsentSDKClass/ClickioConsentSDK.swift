//
//  ClickioConsentSDK.swift
//  ClickioSDK_Integration_Example_iOS
//

import UIKit
import WebKit
import Combine

// MARK: - ClickioConsentSDK
@objcMembers public final class ClickioConsentSDK: NSObject, WKUIDelegate {
    // MARK: Singleton
    @objc @MainActor public static let shared = ClickioConsentSDK()
    
    // MARK: Properties
    private var webViewManager: WebViewManager?
    private(set) var configuration: Config?
    private let logger = EventLogger()
    private var consentStatus: ConsentStatusDTO?
    private var exportData: ExportData?
    private var onConsentUpdatedListener: (() -> Void)?
    private var onReadyListener: (() -> Void)?
    private var isReady = false
    private var cancellables = Set<AnyCancellable>()
    private let baseConsentStatusURL = "https://clickiocdn.com/sdk/consent-status?"
    
    // MARK: Scope properties
    private let gdprScope = "gdpr"
    private let usScope = "us"
    private let outOfScope = "out_of_scope"
    
    // MARK: Initialization
    private override init() {
        super.init()
        subscribeToConsentUpdates()
    }
    
    // MARK: Methods
    func getConsentUpdatedCallback() -> (() -> Void)? {
        onConsentUpdatedListener
    }
    
    /**
     * Updates consent status.
     */
    func updateConsentStatus() {
        if var status = consentStatus {
            status.force = false
            consentStatus = status
        }
    }
    
    // MARK: - Public methods
    /**
     * Initializes the SDK with the provided configuration.
     - Parameter configuration: The configuration object containing client ID and app language.
     */
    @MainActor public func initialize(configuration: Config) async {
        logger.log("Initialization started", level: .info)
        self.exportData = ExportData()
        self.configuration = configuration
        await fetchConsentStatus()
        
        if let error = consentStatus?.error {
            logger.log("Initialization failed: \(error)", level: .error)
        } else { onReadyListener?() }
        setConsentsIfApplicable()
    }
    
    /**
     * Sets a listener that is called when the SDK is ready.
     - Parameter listener: A closure to be called when the SDK is ready.
     */
    public func onReady(listener: @escaping () -> Void) {
        self.onReadyListener = listener
        if isReady { listener() }
    }
    
    /**
     * Sets a listener that is called when the consent is updated.
     - Parameter listener: A closure to be called when the consent is updated.
     */
    public func onConsentUpdated(listener: @escaping () -> Void) {
        self.onConsentUpdatedListener = listener
    }
    
    /**
     * Checks the consent scope that applies to the user.
     - Returns: The applicable consent scope (the sdk/consent-status scope output).
     */
    public func checkConsentScope() -> String? {
        guard let scope = consentStatus?.scope else {
            logger.log("Consent scope is not loaded, possible reason: \(consentStatus?.error?.debugDescription)", level: .error)
            return nil
        }
        return scope
    }
    
    /**
     * Checks the current consent state of the user.
     - Returns: The current consent state:
     * - not_applicable (if scope = ‘out of scope’),
     * - gdpr_no_decision - scope = gdpr and force = true and force state is not changed during app session,
     * - gdpr_decision_obtained - scope = gdpr and force = false,
     * - us - scope = us.
     */
    public func checkConsentState() -> ConsentState? {
        guard let scope = consentStatus?.scope else {
            logger.log("Consent status is not loaded, possible reason: \(consentStatus?.error?.debugDescription)", level: .error)
            return nil
        }
       
        switch (scope, consentStatus?.force) {
        case (outOfScope, _):
            return .notApplicable
        case (gdprScope, true):
            return .gdprNoDecision
        case (gdprScope, false):
            return .gdprDecisionObtained
        case (usScope, _):
            return .us
        default:
            return nil
        }
    }
    
    /**
     * Verifies whether consent for a specific purpose has been granted.
     * It checks the UserDefaults area for the consents accepted or rejected, and filter the ID passed as a parameter, returning true if the consent was accepted or false otherwise.
     * - Parameter purposeId: The identifier of the purpose.
     * - Returns: `true` if consent has been granted; otherwise, `false`.
     */
    public func checkConsentForPurpose(purposeId: Int) -> Bool? {
        exportData?.getConsentedTCFPurposes()?.contains(purposeId)
    }
    
    /**
     *  Verifies whether consent for a specific vendor has been granted.
     * - Parameter vendorId: The identifier of the vendor.
     * - Returns `true` if consent has been granted; otherwise, `false`.
     */
    public func checkConsentForVendor(vendorId: Int) -> Bool? {
        exportData?.getConsentedTCFVendors()?.contains(vendorId)
    }
    
    // MARK: - Dialog manipulations & debug
    /**
     *  Opens the consent dialog regardless ATT permission status.
     * - Parameter mode: The mode in which to open the dialog (`default` or `resurface`).
     * - Parameter language: optional, two-letter language code (e.g. en) - forces UI language.
     * - Parameter showATTFirst:`true` if ATT should be displayed first.
     * - Parameter alwaysShowCMP: `true` if CMP should be displayed regardless ATT choice.
     * - Parameter attNeeded: `true` if ATT is necessary.
     * - language:   An optional parameter to force the UI language.
     */
    public func openDialog(
        mode: DialogMode = .default,
        language: String? = nil,
        in parentViewController: UIViewController? = nil,
        showATTFirst: Bool,
        alwaysShowCMP: Bool,
        attNeeded: Bool,
        completion: (() -> Void)? = nil
    ) {
        let presentingVC: UIViewController
        if let parent = parentViewController {
            presentingVC = parent
        } else if let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })?.rootViewController {
            presentingVC = rootVC
        } else {
            logger.log("No available ViewController for WebView presentation", level: .error)
            return
        }
        
        logger.log("Consent Status: \(String(describing: consentStatus))", level: .debug)
        logger.log("Scope: \(String(describing: consentStatus?.scope)), Force: \(String(describing: consentStatus?.force))", level: .debug)
        
        switch mode {
        case .default:
            if consentStatus?.scope == gdprScope && consentStatus?.force == true {
                handleConsentAndATTFlow(
                    language: language,
                    showATTFirst: showATTFirst,
                    alwaysShowCMP: alwaysShowCMP,
                    attNeeded: attNeeded,
                    in: presentingVC
                )
            }
        case .resurface:
            if consentStatus?.scope != outOfScope {
                handleConsentAndATTFlow(
                    language: language,
                    showATTFirst: showATTFirst,
                    alwaysShowCMP: alwaysShowCMP,
                    attNeeded: attNeeded,
                    in: presentingVC
                )
            }
        }
    }
    
    /**
     *  Allows the SDK user to set the logging mode.
     *  - Parameter mode: The desired logging mode.
     */
    public func setLogsMode(_ mode: EventLogger.Mode) {
        logger.setMode(mode)
    }
}

// MARK: - Handling of consent & ATT permission
private extension ClickioConsentSDK {
    /**
     * Handles available ATT & CMP flows supported by SDK.
     * - Parameter language: optional, two-letter language code (e.g. en) - forces UI language.
     * - Parameter showATTFirst:`true` if ATT should be displayed first.
     * - Parameter alwaysShowCMP: `true` if CMP should be displayed regardless ATT choice.
     * - Parameter attNeeded: `true` if ATT is necessary.
     */
    func handleConsentAndATTFlow(
        language: String? = nil,
        showATTFirst: Bool,
        alwaysShowCMP: Bool,
        attNeeded: Bool,
        in parentViewController: UIViewController
    ) {
        self.webViewManager = WebViewManager(parentViewController: parentViewController)
        
        if !attNeeded {
            // Flow 4: Bypassing ATT flow as not required
            logger.log("Bypassing ATT flow as not required", level: .info)
            showWebViewManager(in: parentViewController, language: language)
        } else if showATTFirst && !alwaysShowCMP {
            // Flow 1: Show ATT first, then display CMP only if ATT consent is granted
            logger.log("Flow 1: Show ATT first, then display CMP only if ATT consent is granted", level: .info)
            if #available(iOS 14, *) {
                ATTManager.shared.requestPermission { [weak self] granted in
                    if granted {
                        self?.showWebViewManager(in: parentViewController, language: language)
                    } else {
                            self?.webViewManager?.rejectToAll(in: parentViewController)
                    }
                }
            } else {
                showWebViewManager(in: parentViewController, language: language)
            }
        } else if !showATTFirst && alwaysShowCMP {
            // Flow 2: Display CMP first, then always request ATT permission irrespective of CMP choice
            logger.log("Flow 2: Display CMP first, then always request ATT permission irrespective of CMP choice", level: .info)
            showWebViewManager(in: parentViewController, language: language, completion: {
                if #available(iOS 14, *) {
                    ATTManager.shared.requestPermission { _ in
                        // ATT result doesn't impact CMP here
                    }
                }
            })
        } else if showATTFirst && alwaysShowCMP {
            // Flow 3: Show ATT first, then display CMP regardless of ATT result
            self.logger.log("Flow 3: Show ATT, then display CMP regardless of ATT result", level: .info)
            if #available(iOS 14, *) {
                ATTManager.shared.requestPermission { [weak self] _ in
                    self?.showWebViewManager(in: parentViewController, language: language)
                }
            } else {
                showWebViewManager(in: parentViewController, language: language)
            }
        } else {
            // Fallback: Presenting CMP
            logger.log("Fallback: Presenting CMP", level: .info)
            showWebViewManager(in: parentViewController, language: language)
        }
    }
    
    func showWebViewManager(
        in parentViewController: UIViewController,
        language: String? = nil,
        completion: (() -> Void)? = nil
    ) {
            self.webViewManager?.presentConsentDialog(in: parentViewController, language: language)
    }
}

// MARK: - Consent manipulations methods
private extension ClickioConsentSDK {
    /**
     * Subscribes to consent updates.
     */
    func subscribeToConsentUpdates() {
        ConsentDataManager.shared.consentUpdatedPublisher
            .sink { [weak self] in
                self?.onConsentUpdatedListener?()
                self?.setConsentsIfApplicable()
            }
            .store(in: &cancellables)
    }
    
    /**
     * Fetches the current consent status.
     */
    func fetchConsentStatus() async {
        logger.log("Started fetching consent status", level: .debug)
        
        guard let configuration = configuration else {
            logger.log("Missing configuration", level: .error)
            return
        }
        
        var urlComponents = URLComponents(string: baseConsentStatusURL)
        urlComponents?.queryItems = [
            URLQueryItem(name: "s", value: configuration.siteId),
            URLQueryItem(name: "v", value: UserDefaults.standard.string(forKey: "CLICKIO_CONSENT_server_request") ?? "")
        ]
        
        logger.log("Fetching URL: \(urlComponents?.url?.absoluteString ?? "Invalid URL")", level: .debug)
        
        guard let url = urlComponents?.url else { return }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 10
        sessionConfig.waitsForConnectivity = true
        
        let session = URLSession(configuration: sessionConfig)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.log("Invalid response from server", level: .error)
                return
            }
            
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            logger.log("Fetched JSON: \(jsonObject)", level: .debug)
            
            if httpResponse.statusCode == 200 {
                logger.log("The server returned response code: OK", level: .debug)
                
                let status = ConsentStatusDTO(
                    scope: jsonObject["scope"] as? String,
                    force: jsonObject["force"] as? Bool ?? false
                )
                
                consentStatus = status
                isReady = true
                
                DispatchQueue.main.async {
                    self.logger.log("Calling onReady", level: .debug)
                    self.onReadyListener?()
                }
            } else {
                logger.log("Server response is not OK: \(httpResponse.statusCode)", level: .error)
                logger.log("Error response json: \(jsonObject)", level: .debug)
                consentStatus = ConsentStatusDTO(error: jsonObject["error"] as? String)
            }
        } catch {
            logger.log("Exception occurred: \(error.localizedDescription)", level: .error)
        }
    }
    
    func setConsentsIfApplicable() {
        logger.log("Calling setConsentsIfApplicable", level: .debug)
        
        // Check whether Firebase Analytics is available
        if FirebaseChecker.isAvailable() {
            logger.log("Firebase Analytics is available. Starting set consents to Firebase Analytics", level: .info)
            FirebaseChecker.setConsentsToFirebaseAnalytics(exportData: exportData)
        }
        
        // Check whether AirBridge is available
        if AirBridgeChecker.isAvailable() {
            logger.log("AirBridge is available. Starting set consents to AirBridge", level: .info)
            AirBridgeChecker.setConsentsToAirbridge(exportData: exportData, consentStatus: consentStatus)
        }
        
        // Check whether Adjust is available
        if AdjustChecker.isAvailable() {
            logger.log("Adjust is available. Starting set consents to Adjust", level: .info)
            AdjustChecker.setConsentsToAdjust(exportData: exportData, consentStatus: consentStatus)
        }
        
        // Check whether AppsFlyerChecker is available
        if AppsFlyerChecker.isAvailable() {
            logger.log("AppsFlyerChecker is available. Starting set consents to AppsFlyerChecker", level: .info)
            AppsFlyerChecker.setConsentsToAppsFlyer(exportData: exportData, consentStatus: consentStatus)
        }

        logger.log("Finishing setConsentsIfApplicable call", level: .debug)
    }
}

// MARK: - Config
extension ClickioConsentSDK {
    @objcMembers public class Config: NSObject {
        // MARK: Properties
        var siteId: String
        var appLanguage: String?
        
        // MARK: Initialization
        public init(siteId: String, appLanguage: String? = nil) {
            self.siteId = siteId
            self.appLanguage = appLanguage
            super.init()
        }
    }
}

// MARK: - Enums
extension ClickioConsentSDK {
    // MARK: ConsentState
    public enum ConsentState {
        case notApplicable
        case gdprNoDecision
        case gdprDecisionObtained
        case us
        
        public var rawValue: String {
            switch self {
            case .notApplicable:
                return "notApplicable"
            case .gdprNoDecision:
                return "gdprNoDecision"
            case .gdprDecisionObtained:
                return "gdprDecisionObtained"
            case .us:
                return "us"
            }
        }
    }
    
    ///   - default: if scope = gdpr and force = true then open the dialog
    ///   - resurface: check if user in consent scope (scope != out of scope) and open the dialog
    // MARK: DialogMode
    public enum DialogMode {
        case `default`
        case resurface
    }
}
