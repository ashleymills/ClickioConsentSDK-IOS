//
//  WebViewController.swift
//  ClickioSDK_Integration_Example_iOS
//

import UIKit
import WebKit

// MARK: - WebViewController
class WebViewController: UIViewController {
    // MARK: Properties
    var webView: WKWebView!
    var url: URL?
    var isWriteCalled = false
    var completion: (() -> Void)?
    private var logger = EventLogger()
    private let consentUpdatedCallback = ClickioConsentSDK.shared.getConsentUpdatedCallback()
    
    // MARK: Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        self.isModalInPresentation = true
        // WebView configuration
        let webConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // Adding the script that communicates with the web content
        let scriptSource = """
        (function() {
            window.clickioSDK = window.clickioSDK || {};
        
            const originalWrite = window.clickioSDK.write;
            const originalRead = window.clickioSDK.read;
            const originalReady = window.clickioSDK.ready;
        
            window.clickioSDK.write = function(data) {
                console.log('[WebView Log] clickioSDK.write called with:', data);
                window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'write', data: data });
                if (originalWrite) originalWrite.apply(this, arguments);
            };
        
            window.clickioSDK.read = function(key) {
                console.log('[WebView Log] clickioSDK.read called with key:', key);
                window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'read', data: key });
                if (originalRead) originalRead.apply(this, arguments);
            };
        
            window.clickioSDK.ready = function() {
                console.log('[WebView Log] clickioSDK.ready called');
                window.webkit.messageHandlers.clickioSDK.postMessage({ action: 'ready' });
                if (originalReady) originalReady.apply(this, arguments);
            };
        })();
        """
        
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(script)
        userContentController.add(self, name: "clickioSDK")
        
        // Initialize the webView with the configuration
        webConfiguration.userContentController = userContentController
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hiding navigation bar
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // Disabling pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Returning navigation bar
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        // Enabling pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}

// MARK: - WKScriptMessageHandler
extension WebViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.log("Received script message: \(message.body)", level: .debug)
        guard message.name == "clickioSDK",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
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
        if isWriteCalled { consentUpdatedCallback?() }
        ClickioConsentSDK.shared.updateConsentStatus()
        completion?()
        self.dismiss(animated: true, completion: nil)
    }
}
