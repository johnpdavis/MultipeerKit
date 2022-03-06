//
//  ClientHostManagerEnvelope.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import Foundation

// MARK: - ClientHostManagerEnvelope
struct ClientHostManagerEnvelope: Codable {
    enum Message: Codable {
        case identifyHost
    }
    
    let message: Message
}
