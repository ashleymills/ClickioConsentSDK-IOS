//
//  EventLogger.swift
//  ClickioSDK_Integration_Example_iOS
//

import Foundation
import os

// MARK: - EventLoggerDefaultValues
@MainActor
struct EventLoggerDefaultValues {
    // MARK: Default Logger values
    static var mode: EventLogger.Mode = .verbose
    static var logLevel: EventLogger.EventLevel = .debug
}

// MARK: - EventLogger
@MainActor
@objcMembers public final class EventLogger: NSObject {
    // MARK: Initializer
    nonisolated public override init() {
          super.init()
      }
    
    // MARK: Enums
    public enum Mode: Int {
        case disabled
        case verbose
    }
    
    public enum EventLevel: Int {
        case error = 1
        case info = 2
        case debug = 3
    }
    
    // MARK: Properties
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "ClickioSDK", category: "ClickioSDK")
    
    // MARK: Public methods
    public func setMode(_ mode: Mode) {
        EventLoggerDefaultValues.mode = mode
    }
    
    public func setLogsLevel(_ level: EventLevel) {
        EventLoggerDefaultValues.logLevel = level
    }
    
    // MARK: Internal method
    func log(_ message: String, level: EventLevel) {
        guard EventLoggerDefaultValues.mode == .verbose, level.rawValue <= EventLoggerDefaultValues.logLevel.rawValue else { return }
        print("LOG: [\(level)] \(message)")
        os_log("%{public}@", log: self.log, type: self.osLogType(for: level), message)
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
