//
//  ATTManager.swift
//  ClickioSDK_Integration_Example_iOS
//

import AppTrackingTransparency

// MARK: - ATT Manager
public final class ATTManager {
    // MARK: Singleton
    @MainActor public static let shared = ATTManager()
    var logger = EventLogger()
    
    // MARK: Initialization
    public init() {}

    // MARK: Typealias
    public typealias ATTPermissionCallback = @MainActor (_ isGrantedAccess: Bool) -> Void
    
    // MARK: Methods
    public func requestPermission(completion: @escaping ATTPermissionCallback) {
        if #available(iOS 14, *) {
            DispatchQueue.global().async {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print(status)
                    DispatchQueue.main.async {
                        completion(status == .authorized)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
}
