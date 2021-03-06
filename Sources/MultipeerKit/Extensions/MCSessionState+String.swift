//
//  File.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import Foundation
import MultipeerConnectivity

// MARK: - MCSessionState
public extension MCSessionState {
    
    /// A string representation of an MCSessionState.
    public var string: String {
        switch self {
        case .notConnected:
            return "Not Connected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        @unknown default:
            return "Unknown(\(rawValue))"
        }
    }
}
