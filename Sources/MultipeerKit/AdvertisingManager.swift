import Foundation
import MultipeerConnectivity

// MARK: - AdvertisingManagerDelegate
protocol AdvertisingManagerDelegate: AnyObject {
    func manager(_ manager: MultipeerAdvertisingManager, didReceiveJoinRequestFrom peer: MCPeerID, with inviteHandler: @escaping ((Bool, MCSession?) -> Void))
}

// Assists in advertising a device's service to other peers
class MultipeerAdvertisingManager: NSObject, ObservableObject {
    enum AdvertisingState {
        case advertisingToClients
        case notAdvertising
        case errorAdvertising(Error)
        
        var string: String {
            switch self {
            case .advertisingToClients:
                return "Advertising"
            case .notAdvertising:
                return "Not Advertising"
            case .errorAdvertising:
                return "Error"
            }
        }
        
        public static func == (lhs: MultipeerAdvertisingManager.AdvertisingState, rhs: MultipeerAdvertisingManager.AdvertisingState) -> Bool {
            switch (lhs, rhs) {
            case (.advertisingToClients, .advertisingToClients):
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
    
    public weak var delegate: AdvertisingManagerDelegate?
    
    private var advertiser: MCNearbyServiceAdvertiser
    
    @Published public var advertisingState: AdvertisingState = .notAdvertising
    
    init(peerID: MCPeerID, discoveryInfo: [String: String], serviceType: String) {
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        super.init()
        advertiser.delegate = self
    }
    
    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        advertisingState = .advertisingToClients
    }
    
    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        advertisingState = .notAdvertising
    }
}

extension MultipeerAdvertisingManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        // Call our delegate to confirm the invitation from this peer
        self.delegate?.manager(self, didReceiveJoinRequestFrom: peerID, with: invitationHandler)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Error trying to Advertise: \(error)")
        advertisingState = .errorAdvertising(error)
    }
}
