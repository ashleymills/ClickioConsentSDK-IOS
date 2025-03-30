//
//  EventLogger.swift
//  ClickioSDK_Integration_Example_iOS
//

import Foundation
import os

// MARK: - EventLogger
@objcMembers public final class EventLogger: NSObject {
    // MARK: Enums
    public enum Mode {
        case disabled
        case verbose
    }
    
    public enum EventLevel: Int {
        case error = 1
        case info = 2
        case debug = 3
    }
    
    // MARK: Properties
    private var mode: Mode = .disabled
    private var currentLevel: EventLevel = .error
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "ClickioSDK", category: "ClickioSDK")
    
    // MARK: Public methods
    public func setMode(_ mode: Mode) {
        self.mode = mode
    }
    
    public func setLogLevel(_ level: EventLevel) {
        self.currentLevel = level
    }
    
    // MARK: Internal method
    func log(_ message: String, level: EventLevel) {
        print("LOG: [\(level)] \(message)")
        guard mode == .verbose, level.rawValue <= currentLevel.rawValue else { return }
        os_log("%{public}@", log: log, type: osLogType(for: level), message)
    }
    
    // MARK: Private method
    private func osLogType(for level: EventLevel) -> OSLogType {
        switch level {
        case .error:
            return .error
        case .info:
            return .info
        case .debug:
            return .debug
        }
    }
}
