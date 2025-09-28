//
//  WebViewController.swift
//  ClickioSDK_Integration_Example_iOS
//

import UIKit
import WebKit

// MARK: - WebViewController
public final class WebViewController: UIViewController {
    // MARK: Properties
    var webView: WKWebView!
    var url: URL?
    var isWriteCalled = false
    var completion: (() -> Void)?
    private var logger = EventLogger()
    var customConfig: WebViewConfig?
    private let consentUpdatedCallback = ClickioConsentSDK.shared.getConsentUpdatedCallback()
    
    fileprivate let sharedProcessPool = WKProcessPool()
    
    // MARK: Methods
    public override func viewDidLoad() {
        super.viewDidLoad()
        // WebView configuration
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.processPool = sharedProcessPool
        webConfiguration.allowsInlineMediaPlayback = true
        let sharedDataStore = WKWebsiteDataStore.default()
        
        let userContentController = WKUserContentController()
        
        if customConfig != nil {
            let readBridge = """
            (function() {
                window.clickioSDK = window.clickioSDK || {};
                const originalRead = window.clickioSDK.read;
            
                window.clickioSDK.read = function(key) {
                    window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'read', data: key });
                    if (originalRead) originalRead.apply(this, arguments);
                };
            })();
            """
            userContentController.addUserScript(
                WKUserScript(
                    source: readBridge,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
        } else {
            let fullBridge = """
            (function() {
                window.clickioSDK = window.clickioSDK || {};
                const originalWrite = window.clickioSDK.write;
                const originalRead = window.clickioSDK.read;
                const originalReady = window.clickioSDK.ready;

                window.clickioSDK.write = function(data) {
                    window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'write', data });
                    if (originalWrite) originalWrite.apply(this, arguments);
                };

                window.clickioSDK.read = function(key) {
                    window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'read', data: key });
                    if (originalRead) originalRead.apply(this, arguments);
                };

                window.clickioSDK.ready = function() {
                    window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'ready' });
                    if (originalReady) originalReady.apply(this, arguments);
                };
            })();
            """
            
            userContentController.addUserScript(WKUserScript(
                source: fullBridge,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false))
        }
        
        // Initialize the webView with the configuration
        webConfiguration.userContentController = userContentController
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        userContentController.add(self, name: "clickioSDK")
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        view.addSubview(webView)
        
        webView.isOpaque = false
        webView.backgroundColor = customConfig?.backgroundColor ?? .clear
        webView.scrollView.backgroundColor = customConfig?.backgroundColor ?? .clear
        
        // Layout constraints based on custom config
             if let cfg = customConfig {
                 if let w = cfg.width {
                     webView.widthAnchor.constraint(equalToConstant: w).isActive = true
                 } else {
                     webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                     webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
                 }
                 if let h = cfg.height {
                     webView.heightAnchor.constraint(equalToConstant: h).isActive = true
                 } else {
                     webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
                     webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
                 }
                 // Vertical position
                 switch cfg.gravity {
                 case .top:
                     NSLayoutConstraint.activate([
                         webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
                     ])
                 case .center:
                     NSLayoutConstraint.activate([
                         webView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                         webView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
                     ])
                 case .bottom:
                     NSLayoutConstraint.activate([
                        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                     ])
                 }
             } else {
                 // Default full screen
                 NSLayoutConstraint.activate([
                     webView.topAnchor.constraint(equalTo:  view.safeAreaLayoutGuide.topAnchor),
                     webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                     webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                     webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                 ])
             }
        
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hiding navigation bar
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // Disabling pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Returning navigation bar
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        // Enabling pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        
        if let completion = completion {
            completion()
            self.completion = nil
        }
    }
}

// MARK: - WKScriptMessageHandler
extension WebViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.log("Received script message: \(message.body)", level: .debug)
        guard message.name == "clickioSDK",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        if customConfig != nil {
            guard action == "read" else { return }
            if let key = body["data"] as? String {
                handleReadAction(key: key)
            }
        } else {
            switch action {
            case "write":
                if let jsonString = body["data"] as? String {
                    handleWriteAction(jsonString: jsonString)
                }
            case "read":
                if let key = body["data"] as? String {
                    handleReadAction(key: key)
                }
            case "ready":
                handleReadyAction()
            default:
                break
            }
        }
    }
    
    // MARK: Methods for handling Consent Data
    private func handleWriteAction(jsonString: String) {
        logger.log("Write method was called with json: \(jsonString)", level: .info)
        isWriteCalled = true
        let success = ConsentDataManager.shared.updateFromJson(jsonString: jsonString)
        if success {
            logger.log("Write action completed successfully", level: .info)
        } else {
            logger.log("Write action failed", level: .error)
        }
    }
    
    private func handleReadAction(key: String) {
        logger.log("Read method was called with key: \(key)", level: .info)
        
        let userDefaults = UserDefaults.standard
        if let value = userDefaults.value(forKey: key) {
            logger.log("Value for key '\(key)': \(value)", level: .debug)
            let script = "window.clickioSDK.onRead('\(key)', \(value));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        } else {
            logger.log("No value found for key '\(key)'", level: .debug)
            let script = "window.clickioSDK.onRead('\(key)', null);"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    private func handleReadyAction() {
        logger.log("Ready method was called", level: .info)
        ClickioConsentSDK.shared.updateConsentStatus()
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        dismiss(animated: true) {
            self.completion?()
            self.logger.log("Failed to open Consent Dialog. Please, try again", level: .error)
        }
    }
}

// MARK: - WKUIDelegate
extension WebViewController: WKUIDelegate {
    public func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else {
            return nil
        }
        
        UIApplication.shared.open(url)
        return nil
    }
}

// MARK: - Cleanup
extension WebViewController {
    /*
     Safely release webview resources and detach handlers — call before removing the controller.
     */
    public func cleanup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let wk = self.webView {
                wk.navigationDelegate = nil
                wk.uiDelegate = nil
                wk.stopLoading()
                wk.configuration.userContentController.removeScriptMessageHandler(forName: "clickioSDK")
            }
            // avoid retaining cycles
            self.completion = nil
        }
    }
}
