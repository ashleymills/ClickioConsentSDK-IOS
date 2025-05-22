//
//  NetworkStatusChecker.swift
//  ClickioConsentSDKManager
//

import Foundation
import SystemConfiguration

// MARK: - NetworkStatusChecker
@objcMembers public final class NetworkStatusChecker: NSObject {
    // MARK: Initialization
    private override init() {
        super.init()
        self.isConnectedToNetwork()
    }
    
    // MARK: Properties
    @MainActor public static let shared = NetworkStatusChecker()
    
    // MARK: Methods
    func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
}
