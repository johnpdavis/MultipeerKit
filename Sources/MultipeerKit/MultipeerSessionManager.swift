import Combine
import Foundation
import MultipeerConnectivity
import RealityKit

extension MCSessionState {
    var string: String {
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

class SessionInvitationCourier: Equatable {
    
    public let peer: MCPeerID
    private let session: MCSession
    private let invitationHandler: ((Bool, MCSession?) -> Void)
    
    public init(peer: MCPeerID, session: MCSession, invitationHandler: @escaping ((Bool, MCSession?) -> Void)) {
        self.peer = peer
        self.session = session
        self.invitationHandler = invitationHandler
    }
    
    public func accept() {
        invitationHandler(true, session)
    }
    
    public func decline() {
        invitationHandler(false, nil)
    }
    
    static func == (lhs: SessionInvitationCourier, rhs: SessionInvitationCourier) -> Bool {
        lhs.peer == rhs.peer &&
        lhs.session == rhs.session 
    }
}

// Maintain the Multipeer session. 
// Provide nuke-ability if needed
// 
class MultipeerSessionManager: NSObject, ObservableObject {
    /// Key added to discovery info to check RealityKit compatibility token
    public static let compTokenKey = "com.johndavis.gallery.CompToken"
    /// Key added to discovery info to show OS version
    public static let osVersionKey = "com.johndavis.gallery.OSVersion"
    /// Key added to discovery info to show device platform
    public static let platformKey = "com.johndavis.gallery.Platform"
    
    enum SessionType {
        case advertiser
        case browser
        case both
        
        var isHost: Bool {
            switch self {
            case .advertiser, .both:
                return true
            case .browser:
                return false
            }
        }
        
        var isPeer: Bool {
            switch self {
            case .browser, .both:
                return true
            case .advertiser:
                return false
            }
        }
    }

    @Published var connectedPeers: [MCPeerID] = []
    @Published var peersToConnectionState: [MCPeerID: MCSessionState] = [:]
    @Published var activeInvitationCourier: SessionInvitationCourier?
    
    public weak var delegate: MultipeerSessionManagerDelegate?

    /// Name of the service, created at initialisation
    public let serviceName: String
    
    @Published public var sessionType: SessionType? {
        willSet {
            // only handle a set if the value is changing
            guard newValue != sessionType else { return }
            
            // Handle the movement AWAY from a particular state
            let stateWeAreMovingFrom = sessionType
            switch stateWeAreMovingFrom {
            case .browser:
                removeBrowser() // No Longer a peer? Remove browser
            case .advertiser:
                removeAdvertiser()
                _activeSession?.disconnect() // No Longer a host? No longer advertise
            case .both:
                // No Longer both? If we're not swapping to a peer, kill the browser, likewise for host
                if newValue != .browser {
                    removeBrowser()
                }
                
                if newValue != .advertiser {
                    removeAdvertiser()
                }
            case .none:
                // Moving from nil? no action.
                break
            }
        }
        
        didSet {
            switch sessionType {
            case .browser:
//                if oldValue != .both {
                    createBrowser()
//                }
            case .advertiser:
//                if oldValue != .both {
                    createAdvertiser()
//                }
            case .both:
                createBrowser()
                createAdvertiser()
            case .none:
                removeAdvertiser()
                removeBrowser()
                _activeSession = nil
            }
            
            objectWillChange.send()
        }
    }
    
    /// MCSession
    private var _activeSession: MCSession? {
        didSet {
            if _activeSession == nil {
                delegate?.managerEndingSession(self)
            }
            
            _activeSession?.delegate = self
        }
    }
    
    internal var activeSession: MCSession {
        get {
            if let currentlyActive = _activeSession {
                return currentlyActive
            }
            
            let newService = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
            _activeSession = newService
            return newService
        }
        
        set {
            _activeSession = newValue
        }
    }
    
    func removeActiveSession() {
        _activeSession = nil
    }
    
    var hasActiveSession: Bool {
        _activeSession != nil
    }
    
    private var advertiserListener: AnyCancellable?
    private var browserListener: AnyCancellable?
    private var backgroundListener: AnyCancellable?
    
    /// SubManagers
    @Published public private(set) var advertisingManager: MultipeerAdvertisingManager?
    @Published public private(set) var browsingManager: BrowsingManager?
    
    /// MultipeerConnectivity browser
    public private(set) var serviceBrowser: MCNearbyServiceBrowser?
    
    public private(set) var myPeerID: MCPeerID
    
    init(serviceName: String, peerID: String? = nil) {
        self.serviceName = serviceName
        self.myPeerID = peerID.flatMap { MCPeerID(displayName: $0) } ?? MCPeerID(displayName: UIDevice.current.name)
    
        super.init()
        
        backgroundListener = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification, object: nil)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
    }
    
    public func handleDidEnterBackground() {
        sessionType = .none
    }
    
    #if canImport(RealityKit)
    public func makeMultipeerConnectivityService() throws -> MultipeerConnectivityService {
        try MultipeerConnectivityService(session: activeSession)
    }
    #endif
    
    public func createAdvertiser() {
        let discoveryInfo = makeDiscoveryInfo()
        
        advertisingManager = MultipeerAdvertisingManager(peerID: myPeerID, discoveryInfo: discoveryInfo, serviceType: self.serviceName)
        
        advertisingManager?.delegate = self
        
        advertiserListener = advertisingManager?.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }
    
    public func removeAdvertiser() {
        advertiserListener?.cancel()
        advertisingManager?.stopAdvertising()
        
        DispatchQueue.main.async {
            self.advertisingManager = nil
        }
    }
    
    public func removeBrowser() {
        browserListener?.cancel()
        browsingManager?.stopBrowsing()
        
        DispatchQueue.main.async {
            self.browsingManager = nil
        }
    }
    
    public func createBrowser() {
        browsingManager = BrowsingManager(peerID: myPeerID, serviceType: self.serviceName)
        
        browserListener = browsingManager?.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }
    
    public func closeSession() {
        activeSession.disconnect()
        _activeSession = nil
    }
    
    public func requestJoinSession(_ peer: MCPeerID, context: Data?, timeout: TimeInterval = 60) throws {
        try browsingManager?.invitePeer(peer, session: activeSession, context: context, timeout: timeout)
    }

    private func makeDiscoveryInfo() -> [String: String] {
        var discoveryInfo = self.delegate?.setDiscoveryInfo()
          ?? [String: String]()

        #if canImport(RealityKit)
        if #available(iOS 13.4, macOS 10.15.4, *) {
          let networkLoc = NetworkCompatibilityToken.local
          let jsonData = try? JSONEncoder().encode(networkLoc)
          if let encodedToken = String(data: jsonData!, encoding: .utf8) {
              discoveryInfo[MultipeerSessionManager.compTokenKey] = encodedToken
          }
        }
        #endif
        
        #if os(iOS) || os(tvOS)
        discoveryInfo[MultipeerSessionManager.osVersionKey] = UIDevice.current.systemVersion
          #if os(iOS)
          discoveryInfo[MultipeerSessionManager.platformKey] = "iOS"
          #else
          discoveryInfo[MultipeerHelper.platformKey] = "tvOS"
          #endif
        #elseif os(macOS)
        discoveryInfo[MultipeerHelper.osVersionKey] = ProcessInfo.processInfo.operatingSystemVersionString
        discoveryInfo[MultipeerHelper.platformKey] = "macOS"
        #endif
        
        return discoveryInfo
    }
}

extension MultipeerSessionManager: AdvertisingManagerDelegate {
    func manager(_ manager: MultipeerAdvertisingManager, didReceiveJoinRequestFrom peer: MCPeerID, with inviteHandler: @escaping ((Bool, MCSession?) -> Void)) {
        let inviteCourier = SessionInvitationCourier(peer: peer, session: activeSession, invitationHandler: inviteHandler)
        activeInvitationCourier = inviteCourier
    }
}

extension MultipeerSessionManager: MCSessionDelegate {
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.manager(self, received: data, from: peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        delegate?.manager(self, receivedStream: stream, named: streamName, from: peerID)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("PEER:\(peerID))")
        print("DID CHANGE STATE:\(state.rawValue))")
        switch state {
        case .notConnected:
            DispatchQueue.main.async {
                self.connectedPeers.removeAll(where: { $0 == peerID })
                self.peersToConnectionState.removeValue(forKey: peerID)
                self.delegate?.manager(self, lostPeer: peerID)
            }
        case .connecting:
            DispatchQueue.main.async {
                self.connectedPeers.append(peerID)
                self.peersToConnectionState[peerID] = state
            }
        case .connected:
            DispatchQueue.main.async {
                self.peersToConnectionState[peerID] = state
                self.delegate?.manager(self, peerDidJoin: peerID)
            }
            
        @unknown default:
            assertionFailure("Unhandled MCSessionState")
        }
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        delegate?.manager(self, startingReceiveOf: resourceName, from: peerID, progress: progress)
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        delegate?.manager(self, didReceiveResource: resourceName, from: peerID, localURL: localURL, error: error)
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(delegate?.manager(self, receivedCertificate: certificate, from: peerID) ?? true)
    }
    
}
