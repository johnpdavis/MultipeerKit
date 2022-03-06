//
//  File.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import Foundation
import MultipeerConnectivity

public protocol ServiceBrowserProtocol: AnyObject {
    var delegate: MCNearbyServiceBrowserDelegate? { get set }
    
    func startBrowsingForPeers()
    func stopBrowsingForPeers()
    
    func invitePeer(_ peerID: MCPeerID, to session: MCSession, withContext context: Data?, timeout: TimeInterval)
}

extension MCNearbyServiceBrowser: ServiceBrowserProtocol { }
