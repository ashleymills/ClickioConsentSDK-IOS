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
    private let networkChecker: NetworkStatusChecker = NetworkStatusChecker.shared
    
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
    private let outOfScope = "out of scope"
    
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
        onReadyListener?()
        logger.log("Initialization finished", level: .info)
        guard networkChecker.isConnectedToNetwork() else {
            logger.log("Bad network connection. Please ensure you are connected to the internet and try again", level: .error)
            return
        }
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
     * - Parameter in parentViewController: optional, defines view controller on which WebView should be presented.
     * - Parameter attNeeded: `true` if ATT is necessary.
     * - language:   An optional parameter to force the UI language.
     */
    public func openDialog(
        mode: DialogMode = .default,
        language: String? = nil,
        in parentViewController: UIViewController? = nil,
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
        
        self.webViewManager = WebViewManager(parentViewController: presentingVC)
        
        guard networkChecker.isConnectedToNetwork() else {
            logger.log("Bad network connection. Please ensure you are connected to the internet and try again", level: .error)
            return
        }
        
        switch mode {
        case .default:
            guard mode == .default else { return }
            if attNeeded {
                logger.log("Showing ATT dialog first, then displaying CMP in default mode only if ATT consent is granted", level: .info)
                ATTManager.shared.requestPermission { isGranted in
                    if isGranted {
                        self.showDefaultDialog(
                            mode: mode,
                            in: presentingVC,
                            language: language,
                            completion: completion
                        )
                    } else {
                        self.logger.log("Dialog not shown: user rejected ATT permission", level: .info)
                    }
                }
            } else {
                logger.log("Bypassing ATT flow as not required and showing CMP in default mode", level: .info)
                self.showDefaultDialog(
                    mode: mode,
                    in: presentingVC,
                    language: language,
                    completion: completion
                )
            }
            
        case .resurface:
            if attNeeded {
                logger.log("Showing ATT dialog first, then displaying CMP in resurface mode only if ATT consent is granted", level: .info)
                ATTManager.shared.requestPermission { isGranted in
                    if isGranted {
                        self.showResurfaceDialog(
                            mode: mode,
                            in: presentingVC,
                            language: language,
                            completion: completion
                        )
                    } else {
                        self.logger.log("Dialog not shown: user rejected ATT permission", level: .info)
                    }
                }
            } else {
                logger.log("Bypassing ATT flow as not required and showing CMP in resurface mode", level: .info)
                showResurfaceDialog(
                    mode: mode,
                    in: presentingVC,
                    language: language,
                    completion: completion
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

// MARK: - Handling webView dialog appearance
private extension ClickioConsentSDK {
    func showDefaultDialog(
        mode: DialogMode,
        in vc: UIViewController,
        language: String?,
        completion: (() -> Void)?
    ) {
        if let fetchedStatus = self.consentStatus {
            if self.consentStatus?.scope == self.gdprScope && self.consentStatus?.force == true {
                self.showWebViewManager(
                    in: vc,
                    language: language,
                    completion: completion
                )
            } else {
                self.logger.log("Dialog not shown: decision already saved or user is located outside the EEA, GB, or CH regions", level: .info)
            }
        } else {
            Task {
                await self.fetchConsentStatus()
                if self.consentStatus?.scope == self.gdprScope && self.consentStatus?.force == true {
                    self.showWebViewManager(
                        in: vc,
                        language: language,
                        completion: completion
                    )
                } else {
                    self.logger.log("Dialog not shown: decision already saved or user is located outside the EEA, GB, or CH regions", level: .info)
                }
            }
        }
    }
    
    func showResurfaceDialog(
        mode: DialogMode,
        in vc: UIViewController,
        language: String?,
        completion: (() -> Void)?
    ) {
        if let fetchedStatus = self.consentStatus {
            if self.consentStatus?.scope != self.outOfScope {
                self.showWebViewManager(
                    in: vc,
                    language: language,
                    completion: completion
                )
            } else {
                self.logger.log("Dialog not shown: user is located outside EEA, GB, or CH regions", level: .info)
            }
        } else {
            Task {
                await self.fetchConsentStatus()
                if self.consentStatus?.scope != self.outOfScope {
                    self.showWebViewManager(
                        in: vc,
                        language: language,
                        completion: completion
                    )
                } else {
                    self.logger.log("Dialog not shown: user is located outside EEA, GB, or CH regions", level: .info)
                }
            }
        }
    }
    
    func showWebViewManager(
        in parentViewController: UIViewController,
        language: String?,
        completion: (() -> Void)? = nil
    ) {
        let webviewClosed = {
            Task {
                self.updateConsentStatus()
                DispatchQueue.main.async {
                    self.onConsentUpdatedListener?()
                }
            }
            completion?()
        }

        guard networkChecker.isConnectedToNetwork() else {
            logger.log("Bad network connection. Please ensure you are connected to the internet and try again", level: .error)
            return
        }

        webViewManager?.presentConsentDialog(
            in: parentViewController,
            language: language,
            completion: webviewClosed
        )
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
        
        guard networkChecker.isConnectedToNetwork() else {
            logger.log("Bad network connection. Please ensure you are connected to the internet and try again", level: .error)
            return
        }
        
        guard let configuration = configuration else {
            logger.log("Missing configuration", level: .error)
            return
        }
        
        var urlComponents = URLComponents(string: baseConsentStatusURL)
        var queryItems: [URLQueryItem] = []
        
        queryItems.append(URLQueryItem(name: "s", value: configuration.siteId))
        
        if let version = UserDefaults.standard.string(forKey: "CLICKIO_CONSENT_server_request"),
           !version.isEmpty {
            queryItems.append(URLQueryItem(name: "v", value: version))
        }
        
        urlComponents?.queryItems = queryItems
        
        logger.log("Fetching URL: \(urlComponents?.url?.absoluteString ?? "Invalid URL")", level: .debug)
        
        guard let url = urlComponents?.url else { return }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 10
        sessionConfig.waitsForConnectivity = false
        
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
                
                logger.log("Current consent status: Scope: \(String(describing: consentStatus?.scope)), Force: \(String(describing: consentStatus?.force))", level: .debug)

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

// MARK: - ClickioConsentSDK Extension for Custom URL Loading
public extension ClickioConsentSDK {
    /// Opens a custom WebView with provided URL and layout config
    func webViewLoadUrl(
        urlString: String,
        attNeeded: Bool,
        config: WebViewConfig = WebViewConfig(),
        in parentViewController: UIViewController? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let url = URL(string: urlString) else {
            logger.log("Invalid URL: \(urlString)", level: .error)
            return
        }
        
        let presentingVC: UIViewController
        if let parent = parentViewController {
            presentingVC = parent
        } else if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController {
            presentingVC = rootVC
        } else {
            logger.log("No available ViewController for custom WebView presentation", level: .error)
            return
        }
        
        self.webViewManager = WebViewManager(parentViewController: presentingVC)
        
        guard networkChecker.isConnectedToNetwork() else {
            logger.log("Bad network connection. Please ensure you are connected to the internet and try again", level: .error)
            return
        }
        
        if attNeeded {
            logger.log("Showing ATT dialog first, then displaying custom CMP only if ATT consent is granted", level: .info)
            ATTManager.shared.requestPermission { isGranted in
                if isGranted {
                    self.webViewManager?.presentCustomWebView(
                        in: presentingVC,
                        url: url,
                        config: config,
                        completion: completion
                    )
                } else {
                    self.logger.log("Dialog not shown: user rejected ATT permission", level: .info)
                }
            }
        } else {
            logger.log("Bypassing ATT flow as not required and showing custom CMP", level: .info)
            webViewManager?.presentCustomWebView(
                in: presentingVC,
                url: url,
                config: config,
                completion: completion
            )
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
