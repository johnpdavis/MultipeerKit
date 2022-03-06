import MultipeerConnectivity

// MARK: - BrowsingManagerDelegate
protocol BrowsingManagerDelegate: AnyObject {
    func manager(_ manager: BrowsingManager, validatePeer: MCPeerID, withDiscoveryInfo info: [String : String]?) throws
}

// MARK: - MultipeerBrowsingManagerError
enum BrowsingManagerError: Error {
    case invitedImpossiblePeer
}

// MARK: - BrowsingManager
public class BrowsingManager: NSObject, ObservableObject {
    /// Type that represents the browsing state of the BrowsingManager and it's internal BrowsingService
    public enum BrowsingState: Equatable {
        case browsing
        case notBrowsing
        case errorBrowsing(Error)
        
        public var string: String {
            switch self {
            case .browsing:
                return "Browsing"
            case .notBrowsing:
                return "Not Browsing"
            case .errorBrowsing(_):
                return "Error"
            }
        }
        
        public static func == (lhs: BrowsingManager.BrowsingState, rhs: BrowsingManager.BrowsingState) -> Bool {
            switch (lhs, rhs) {
            case (.browsing, .browsing):
                return true
            case (.notBrowsing, .notBrowsing):
                return true
            case let (.errorBrowsing(lError), .errorBrowsing(rError)):
                return lError == rError
            default:
                return false
            }
        }
    }
    
    // MARK: - Internal Properties
    public private(set) var serviceBrowser: ServiceBrowserProtocol
    
    
    // MARK: - Published Properties
    @Published public var browsingState: BrowsingState = .notBrowsing
    @Published public var possiblePeers: [MCPeerID] = []
    
    // MARK: - Exposed Properties
    weak var delegate: BrowsingManagerDelegate?
    
    // MARK: - Initialization
    public init(peerID: MCPeerID, serviceType: String) {
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        super.init()
        
        serviceBrowser.delegate = self
    }
    
    public init(serviceBrowser: ServiceBrowserProtocol) {
        self.serviceBrowser = serviceBrowser
        super.init()
        
        self.serviceBrowser.delegate = self
    }
    
    // MARK: - Browser Control
    public func startBrowsing() {
        serviceBrowser.startBrowsingForPeers()
        browsingState = .browsing
    }
    
    public func stopBrowsing() {
        serviceBrowser.stopBrowsingForPeers()
        possiblePeers = []
        browsingState = .notBrowsing
    }
    
    // MARK: - Peer Invitation
    /// Instructs the internal browser to invite the provided peer
    /// - Parameters:
    ///   - peer: Peer to invite
    ///   - session: Session to invite peer to
    ///   - context: An arbitrary piece of data that is passed to the nearby peer. This can be used to provide further information to the user about the nature of the invitation.
    ///   - timeout: The amount of time to wait for the peer to respond to the invitation.
    ///
    ///     This timeout is measured in seconds, and must be a positive value. If a negative value or zero is specified, the default timeout (30 seconds) is used.
    func invitePeer(_ peer: MCPeerID, session: MCSession, context: Data?, timeout: TimeInterval) throws {
        guard possiblePeers.contains(peer) else {
            throw BrowsingManagerError.invitedImpossiblePeer
        }
        
        serviceBrowser.invitePeer(peer, to: session, withContext: context, timeout: timeout)
    }
}

// MARK: - Internal Helpers
extension BrowsingManager {
    // MARK: - Browser Feedback
    func handleBrowsingError(_ error: Error) {
        serviceBrowser.stopBrowsingForPeers()
        possiblePeers = []
        browsingState = .errorBrowsing(error)
    }
    
    func handleFoundPeer(_ peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        do {
            try delegate?.manager(self, validatePeer: peerID, withDiscoveryInfo: info)
            
            possiblePeers.append(peerID)
        } catch {
            print("Found peer with info: \(info ?? [:]) was determined to be invalid")
            print(error)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension BrowsingManager: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Error trying to browse for peers: \(error)")
        handleBrowsingError(error)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        possiblePeers.removeAll(where: { $0 == peerID })
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        handleFoundPeer(peerID, withDiscoveryInfo: info)
    }
}
