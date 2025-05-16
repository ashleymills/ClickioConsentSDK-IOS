//
//  NetworkStatusChecker.swift
//  ClickioConsentSDKManager
//

import Foundation
import Network

// MARK: - NetworkStatusChecker
@objcMembers public final class NetworkStatusChecker: NSObject, @unchecked Sendable {
    // MARK: Properties
    @MainActor public static let shared = NetworkStatusChecker()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    public private(set) var isConnected: Bool = false
    
    // MARK: Initialization
    private override init() {
        super.init()
        monitor.start(queue: queue)
        isConnected = (monitor.currentPath.status == .satisfied)
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }
    }
}
