//
//  ConsentStatusDTO.swift
//  ClickioSDK_Integration_Example_iOS
//

// MARK: - ConsentStatusDTO
/**
 * Data class for sdk/consent-status response.
 */
struct ConsentStatusDTO: Decodable {
    var scope: String?
    var force: Bool?
    var error: String?
}
