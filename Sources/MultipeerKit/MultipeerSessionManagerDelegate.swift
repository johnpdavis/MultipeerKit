//
//  MultipeerHelperDelegate.swift
//
//
//  Created by Max Cobb on 11/22/19.
//  Changed up by John Davis on 03/05/2022
//

import Foundation
import MultipeerConnectivity

/// Delegate for some useful multipeer connectivity methods
protocol MultipeerSessionManagerDelegate: AnyObject {
    
    /// The Session Manager will call this when the active MCSession  is set to nil
    func managerEndingSession(_ manager: MultipeerSessionManager)
    
    /// Data that has been recieved from another peer
    /// - Parameters:
    ///     - manager: Manager calling the method
    ///     - data: The Data being received
    ///     - peer: The peer who sent the data
    func manager(_ manager: MultipeerSessionManager, received data: Data, from peer: MCPeerID)
    
    /// Callback for when a peer joins the network
    /// - Parameters:
    ///     - manager: Manager calling the method
    ///     - peer: The peer that connected
    func manager(_ manager: MultipeerSessionManager, peerDidJoin peer: MCPeerID)
    
    /// Callback for when a peer leaves the network
    /// - Parameters:
    ///     - manager: Manager calling the method
    ///     - peer: The peer that disconnected
    func manager(_ manager: MultipeerSessionManager, peerDidLeave peer: MCPeerID)
    
    /// Callback for when a new peer has been found.
    ///  [init(peer:discoveryInfo:serviceType:)](apple-reference-documentation://ls%2Fdocumentation%2Fmultipeerconnectivity%2Fmcnearbyserviceadvertiser%2F1407102-init) in [MCNearbyServiceAdvertiser](apple-reference-documentation://ls%2Fdocumentation%2Fmultipeerconnectivity%2Fmcnearbyserviceadvertiser).
    /// - Returns: Bool if the peer request to join the network or not
    func manager(manager: MultipeerSessionManager, shouldInvitePeer peer: MCPeerID, with discoveryInfo: [String: String]?) -> Bool
    
    /// Handle when a peer has requested to join the network
    /// - Parameters:
    /// - Returns: Bool if the peer's join request should be accepted
    func manager(_ manager: MultipeerSessionManager, shouldAcceptJoinRequestFrom peer: MCPeerID, context: Data?) -> Bool
    
    /// This will be set as the base for the discoveryInfo, which is sent out by the advertiser (host).
    /// The key "MultipeerHelper.compTokenKey" is in use by MultipeerHelper, for checking the
    /// compatibility of RealityKit versions.
    /// - Returns: Discovery Info
    func setDiscoveryInfo() -> [String: String]
    
    /// Peer can no longer be found on the network, and thus cannot receive data
    /// - Parameters:
    ///   - peerHelper: The ``MultipeerHelper`` session that manages the nearby peer whose state changed
    ///   - peer: If a peer has left the network in a non typical way
    func manager(_ manager: MultipeerSessionManager, lostPeer peer: MCPeerID)
    
    /// Received a byte stream from remote peer.
    /// - Parameters:
    ///   - peerHelper: The ``MultipeerHelper`` session through which the byte stream was opened
    ///   - stream: An NSInputStream object that represents the local endpoint for the byte stream.
    ///   - streamName: The name of the stream, as provided by the originator.
    ///   - peerID: The peer ID of the originator of the stream.
    func manager(_ manager: MultipeerSessionManager, receivedStream stream: InputStream, named streamName: String, from peer: MCPeerID)
    
    /// Start receiving a resource from remote peer.
    /// - Parameters:
    ///   - peerHelper: The ``MultipeerHelper`` session that started receiving the resource
    ///   - resourceName: name of the resource, as provided by the sender.
    ///   - peerID: sender’s peer ID.
    ///   - progress: NSProgress object that can be used to cancel the transfer or queried to determine how far the transfer has progressed.
    func manager(_ manager: MultipeerSessionManager, startingReceiveOf resourceName: String, from peer: MCPeerID, progress: Progress
    )
    
    /// Received a resource from remote peer.
    /// - Parameters:
    ///   - peerHelper: The ``MultipeerHelper`` session through which the data were received
    ///   - resourceName: The name of the resource, as provided by the sender.
    ///   - peerID: The peer ID of the sender.
    ///   - localURL: An NSURL object that provides the location of a temporary file containing the received data.
    ///   - error: An error object indicating what went wrong if the file was not received successfully, or nil.
    func manager( _ manager: MultipeerSessionManager, didReceiveResource resourceName: String, from peerID: MCPeerID, localURL: URL?, error: Error?
    )
    /// Made first contact with peer and have identity information about the
    /// remote peer (certificate may be nil).
    /// - Parameters:
    ///   - peerHelper: The ``MultipeerHelper`` session that manages the nearby peer whose state changed
    ///   - certificate: A certificate chain, presented as an array of SecCertificateRef certificate objects. The first certificate in this chain is the peer’s certificate, which is derived from the identity that the peer provided when it called the `initWithPeer:securityIdentity:encryptionPreference:` method. The other certificates are the (optional) additional chain certificates provided in that same array.
    ///   If the nearby peer did not provide a security identity, then this parameter’s value is nil.
    ///   - peerID: The peer ID of the sender.
    func manager(_ manager: MultipeerSessionManager, receivedCertificate certificate: [Any]?, from peer: MCPeerID) -> Bool
}

#if canImport(RealityKit)
import RealityKit
extension MultipeerSessionManagerDelegate {
    /// Checks whether the discovered session is using a compatible version of RealityKit
    /// For collaborative sessions.
    /// - Parameter discoveryInfo: The discoveryInfo from the advertiser
    /// picked up by a browser.
    /// - Returns: Boolean representing whether or not the two devices
    /// have compatible versions of RealityKit.
    public static func checkPeerToken(with discoveryInfo: [String: String]?) -> Bool {
        guard let compTokenStr = discoveryInfo?[MultipeerSessionManager.compTokenKey]
        else {
            return false
        }
        if #available(iOS 13.4, macOS 10.15.4, *) {
            if let tokenData = compTokenStr.data(using: .utf8),
               let compToken = try? JSONDecoder().decode(
                NetworkCompatibilityToken.self,
                from: tokenData
               ) {
                return compToken.compatibilityWith(.local) == .compatible
            }
        }
        return false
    }
}
#endif
