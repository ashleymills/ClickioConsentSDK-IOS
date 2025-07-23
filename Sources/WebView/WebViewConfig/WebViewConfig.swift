//
//  WebViewConfig.swift
//  ClickioConsentSDKManager
//

import UIKit

// MARK: - WebViewConfig
public struct WebViewConfig {
    // MARK: Properties
    public var backgroundColor: UIColor = .clear
    public var width: CGFloat? // nil = full width
    public var height: CGFloat? // nil = full height
    public var gravity: WebViewGravity = .center
    
    // MARK: Init
    public init(
        backgroundColor: UIColor = .clear,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        gravity: WebViewGravity = .center
    ) {
        self.backgroundColor = backgroundColor
        self.width = width
        self.height = height
        self.gravity = gravity
    }
}

// MARK: - WebViewGravity
public enum WebViewGravity {
    case top, center, bottom
}
