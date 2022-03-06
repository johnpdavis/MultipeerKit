//
//  File.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import Foundation
import MultipeerConnectivity

public protocol ServiceAdvertiserProtocol: AnyObject {
    var delegate: MCNearbyServiceAdvertiserDelegate? { get set }
    
    func startAdvertisingPeer()
    func stopAdvertisingPeer()
}

extension MCNearbyServiceAdvertiser: ServiceAdvertiserProtocol { }
