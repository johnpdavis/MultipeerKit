import Foundation
import MultipeerConnectivity

// MARK: - AdvertisingManagerDelegate
public protocol AdvertisingManagerDelegate: AnyObject {
    func manager(_ manager: AdvertisingManager, didReceiveJoinRequestFrom peer: MCPeerID, with inviteHandler: @escaping ((Bool, MCSession?) -> Void))
}

// MARK: - AdvertisingManager
// Assists in advertising a device's service to other peers
public class AdvertisingManager: NSObject, ObservableObject {
    // MARK: - AdvertisingState
    public enum AdvertisingState: Equatable {
        case advertising
        case notAdvertising
        case errorAdvertising(Error)
        
        public var string: String {
            switch self {
            case .advertising:
                return "Advertising"
            case .notAdvertising:
                return "Not Advertising"
            case .errorAdvertising:
                return "Error"
            }
        }
        
        public static func == (lhs: AdvertisingManager.AdvertisingState, rhs: AdvertisingManager.AdvertisingState) -> Bool {
            switch (lhs, rhs) {
            case (.advertising, .advertising):
                return true
            case (.notAdvertising, .notAdvertising):
                return true
            case let (.errorAdvertising(lError), .errorAdvertising(rError)):
                return lError == rError
            default:
                return false
            }
        }
    }
    
    // MARK: - Exposed Properties
    public weak var delegate: AdvertisingManagerDelegate?
    
    // MARK: - Published Properties
    @Published public var advertisingState: AdvertisingState = .notAdvertising
    
    // MARK: - Internal Properties
    private var advertiser: ServiceAdvertiserProtocol
    
    // MARK: - Initialization
    public init(peerID: MCPeerID, discoveryInfo: [String: String], serviceType: String) {
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        super.init()
        advertiser.delegate = self
    }
    
    public init(advertiser: ServiceAdvertiserProtocol) {
        self.advertiser = advertiser
        super.init()
        advertiser.delegate = self
    }
    
    // MARK: - Advertiser Control
    public func startAdvertising() {
        advertiser.startAdvertisingPeer()
        advertisingState = .advertising
    }
    
    public func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        advertisingState = .notAdvertising
    }
}

// MARK: - Internal Helpers
extension AdvertisingManager {
    // MARK: - Browser Feedback
    func handleAdvertisingError(_ error: Error) {
        advertiser.stopAdvertisingPeer()
        advertisingState = .errorAdvertising(error)
    }
    
    func handleInvitationReceivedFromPeer(_ peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Call our delegate to confirm the invitation from this peer
        self.delegate?.manager(self, didReceiveJoinRequestFrom: peerID, with: invitationHandler)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension AdvertisingManager: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        handleInvitationReceivedFromPeer(peerID, withContext: context, invitationHandler: invitationHandler)
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Error trying to Advertise: \(error)")
        handleAdvertisingError(error)
    }
}
