//
//  File.swift
//  Gallery
//
//  Created by John Davis on 3/5/22.
//

import Foundation
import MultipeerConnectivity

public class ClientHostSessionManager: MultipeerSessionManager {
    // MARK: - Role
    /// The possible roles of this manager
    public enum Role {
        case client
        case host
    }
    
    // MARK: - Published Properties
    /// Current Host of the managed session
    @Published public var currentHost: MCPeerID?
    
    /// Current Role of the managed session. Upon modification the manager will create and destory browsers and avertisers to fulfill the new role.
    @Published public var currentRole: Role? {
        didSet {
            switch currentRole {
            case .client:
                super.sessionType = .browser
            case .host:
                super.sessionType = .advertiser
            case .none:
                super.sessionType = nil
            }
            
            objectWillChange.send()
        }
    }
    
    // MARK: - Internal Overrides
    override func handleDidEnterBackground() {
        currentHost = nil
        currentRole = nil
    }
    
    // MARK: - Overrides
    override public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let clientHostEnvelope = try? JSONDecoder().decode(ClientHostManagerEnvelope.self, from: data) else {
            super.session(session, didReceive: data, fromPeer: peerID)
            return
        }
        
        switch clientHostEnvelope.message {
        case .identifyHost:
            DispatchQueue.main.async {
                self.currentHost = peerID // The peer that sends `identifyHost` on your mesh is considered the host.
            }
        }
    }
    
    override public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        super.session(session, peer: peerID, didChange: state)
        switch state {
        case .connected:
            if currentRole == .host {
                informPeerOfHost(peerID)
            }
        case .notConnected:
            if peerID == currentHost {
                // our host got disconnected
                DispatchQueue.main.async {
                    self.currentHost = nil
                    self.currentRole = nil
                }
            }
        default:
            // No need to act on this.
            break
        }
    }
}

// MARK: - Internal Helpers
extension ClientHostSessionManager {
    private func informPeersOfHost(reliably: Bool = true) {
        do {
            let message = ClientHostManagerEnvelope(message: .identifyHost)
            let messageData = try JSONEncoder().encode(message)
            try activeSession.send(messageData, toPeers: connectedPeers, with: reliably ? .reliable : .unreliable)
        } catch {
            print("Failed to inform all peers of host: \(error)")
        }
    }
    
    private func informPeerOfHost(_ peer: MCPeerID, reliably: Bool = true) {
        do {
            let message = ClientHostManagerEnvelope(message: .identifyHost)
            let messageData = try JSONEncoder().encode(message)
            try activeSession.send(messageData, toPeers: [peer], with: reliably ? .reliable : .unreliable)
        } catch {
            print("Failed to inform peer of host: \(error)")
        }
    }
}
