//
//  File.swift
//  Gallery
//
//  Created by John Davis on 3/5/22.
//

import Foundation
import MultipeerConnectivity

struct ClientHostManagerEnvelope: Codable {
    enum Message: Codable {
        case identifyHost
    }
    
    let message: Message
}

class ClientHostSessionManager: MultipeerSessionManager {
    enum Role {
        case client
        case host
    }
    
    @Published var currentRole: Role? {
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
    
    @Published var currentHost: MCPeerID?
    
    override func handleDidEnterBackground() {
        currentHost = nil
        currentRole = nil
    }
    
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
    
    override func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
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
    
    override func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
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
