//
//  WebViewManager.swift
//  ClickioSDK_Integration_Example_iOS
//

import UIKit
import WebKit

// MARK: - WebViewManager
@MainActor @objcMembers final class WebViewManager: NSObject {
    // MARK: Properties
    private let logger = EventLogger()
    private var configuration: ClickioConsentSDK.Config?
    private let baseConsentURL = "https://clickiocmp.com/t/static/consent_app.html?"
    
    // MARK: Initialization
    init(parentViewController: UIViewController) {
        super.init()
        self.configuration = ClickioConsentSDK.shared.configuration
    }
    
    // MARK: Methods
    /**
     * Opens a WebView screen. Launchs a transparent ViewController with WebView, passing config, onConsentUpdated callback, logger.
     */
    func presentConsentDialog(
        in parentViewController: UIViewController,
        language: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let configuration = configuration else { return }
        var urlString: String {
            return baseConsentURL + (configuration.appLanguage?.isEmpty ?? true ? "sid=\(configuration.siteId)" : "sid=\(configuration.siteId)&lang=\(configuration.appLanguage!)")
        }
        guard let url = URL(string: urlString) else {
            logger.log("Invalid URL for CMP: \(urlString)", level: .error)
            return
        }

        let webViewController = WebViewController()
        webViewController.url = url
        webViewController.completion = completion
        
        parentViewController.present(webViewController, animated: true)
    }
    
    /**
     *  Programmatically triggers the CMP’s “reject to all” action within the WebView, required for recommended ATT flow.
     */
    func rejectToAll(in parentViewController: UIViewController) {
        guard let configuration = configuration else { return }
        let urlString = "\(baseConsentURL)sid=\(configuration.siteId)&lang=\(configuration.appLanguage ?? "en")&mode=denyAll"
        guard let url = URL(string: urlString) else {
            logger.log("Invalid URL for rejectToAll: \(urlString)", level: .error)
            return
        }

        // Sending url to WebViewController
        let webViewController = WebViewController()
        webViewController.url = url
        
        webViewController.modalPresentationStyle = .overCurrentContext
        parentViewController.present(webViewController, animated: false)
    }
}
