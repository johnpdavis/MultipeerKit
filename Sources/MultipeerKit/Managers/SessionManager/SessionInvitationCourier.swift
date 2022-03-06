//
//  SessionInvitationCourier.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import MultipeerConnectivity


/// A class that retains an invitation handler from the MultipeerConnectivity framework so it can be used statefully in a SwiftUI context.
/// Will accept or decline the peer on the session that the request was received on. 
public class SessionInvitationCourier: Equatable {
    
    // MARK: - Exposed Properties
    /// Peer doing request came from
    public let peer: MCPeerID
    
    // MARK: - Internal Properties
    /// Session the request is on
    private let session: MCSession
    
    /// Invitation Handler provided by the `MultipeerConnectivity` framework's Advertiser delegate method
    private let invitationHandler: ((Bool, MCSession?) -> Void)
    
    // MARK: - Initialization
    public init(peer: MCPeerID, session: MCSession, invitationHandler: @escaping ((Bool, MCSession?) -> Void)) {
        self.peer = peer
        self.session = session
        self.invitationHandler = invitationHandler
    }
    
    // MARK: - Public Interface
    public func accept() {
        invitationHandler(true, session)
    }
    
    public func decline() {
        invitationHandler(false, nil)
    }
    
    // MARK: - Equatability
    public static func == (lhs: SessionInvitationCourier, rhs: SessionInvitationCourier) -> Bool {
        lhs.peer == rhs.peer &&
        lhs.session == rhs.session
    }
}
