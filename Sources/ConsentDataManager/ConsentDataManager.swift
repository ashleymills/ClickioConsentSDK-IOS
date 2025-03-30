//
//  ConsentDataManager.swift
//  ClickioSDK_Integration_Example_iOS
//

import Foundation
import WebKit
import Combine

// MARK: - ConsentDataManager
@objcMembers public final class ConsentDataManager: NSObject {
    
    // MARK: Singleton
    @MainActor public static let shared = ConsentDataManager()
    
    // MARK: Properties
    private var logger = EventLogger()
    private let consentUpdatedSubject = PassthroughSubject<Void, Never>()
    public var consentUpdatedPublisher: AnyPublisher<Void, Never> {
        consentUpdatedSubject.eraseToAnyPublisher()
    }
    
    // MARK: Initialization
    private override init() {}
    
    // MARK: Public methods
    /**
     * Reads the stored consent data.
     * - Parameter key: The key to retrieve from UserDefaults.
     * - Returns: The value associated with the key, or `nil` if not found.
     */
     func read(key: String) -> String? {
        let storedData = UserDefaults.standard.object(forKey: key)
        return storedData as? String
    }
    
    /**
     * Updates multiple keys in UserDefaults from a JSON string.
     * - Parameter jsonString: The JSON string with updated data.
     */
    func updateFromJson(jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            logger.log("Failed to convert jsonString to Data", level: .error)
            return false
        }
        logger.log("UpdateFromJSON: received JSON: \(jsonString)", level: .debug)

        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                logger.log("JSON deserialization failed", level: .error)
                return false
            }
            
            let userDefaults = UserDefaults.standard
            
            for (key, value) in json {
                if value is NSNull {
                    userDefaults.removeObject(forKey: key)
                    logger.log("Removed key: \(key)", level: .debug)
                } else {
                    if JSONSerialization.isValidJSONObject([value]) {
                        userDefaults.set(value, forKey: key)
                        logger.log("Stored key: \(key) with value: \(value)", level: .debug)
                    } else {
                        userDefaults.set("\(value)", forKey: key)
                        logger.log("Stored key: \(key) as string with value: \(value)", level: .debug)
                    }
                }
            }
            userDefaults.synchronize()
            consentUpdatedSubject.send()
            logger.log("Successfully updated consent data from JSON", level: .debug)
            return true
        } catch {
            logger.log("JSON parse error: \(error.localizedDescription)", level: .error)
            return false
        }
    }
}
