import Combine
import Foundation
import MultipeerConnectivity
import RealityKit

// MARK: - MultipeerSessionManager
/// Aggregates an AdvertisingManager and a BrowsingManager, and provides a higher level interface so consumers can specify a session type
public class MultipeerSessionManager: NSObject, ObservableObject {
    
    // MARK: - Static keys
    /// Key added to discovery info to check RealityKit compatibility token
    public static let compTokenKey = "com.johndavis.multipeerkit.RealityKitCompatibilityToken"
    /// Key added to discovery info to show OS version
    public static let osVersionKey = "com.johndavis.multipeerkit.OSVersion"
    /// Key added to discovery info to show device platform
    public static let platformKey = "com.johndavis.multipeerkit.Platform"
    
    // MARK: - Session Type
    /// Possible runtimes of this manager
    public enum SessionType {
        case advertiser
        case browser
        case both
        
        var isAdvertising: Bool {
            switch self {
            case .advertiser, .both:
                return true
            case .browser:
                return false
            }
        }
        
        var isBrowsing: Bool {
            switch self {
            case .browser, .both:
                return true
            case .advertiser:
                return false
            }
        }
    }
    
    /// This manager's peerID, populated at initialisation
    public let myPeerID: MCPeerID

    /// Name of the service, populated at initialisation
    public let serviceName: String
    
    /// SessionManager Delegate
    public weak var delegate: MultipeerSessionManagerDelegate?
    
    /// Answers if there is a living MCSession
    public var hasActiveSession: Bool {
        _activeSession != nil
    }
    
    // MARK: - Published Properties
    /// Peers currently tracked as being part of the session
    @Published var connectedPeers: [MCPeerID] = []
    
    /// Connectivity State of known peers
    @Published var peersToConnectionState: [MCPeerID: MCSessionState] = [:]
    
    /// Currently Pending Invitation Handler
    @Published var activeInvitationCourier: SessionInvitationCourier?
    
    /// SubManagers
    @Published public private(set) var advertisingManager: AdvertisingManager?
    @Published public private(set) var browsingManager: BrowsingManager?
    
    /// The session type of the `SessionManager`. Changing this value will result in advertising and browsing managers being created or destroyed to satisfy the new state.
    @Published public var sessionType: SessionType? {
        willSet {
            // only handle a will set if the value is changing
            guard newValue != sessionType else { return }
            
            // Handle the movement AWAY from a particular state
            let stateWeAreMovingFrom = sessionType
            switch stateWeAreMovingFrom {
            case .browser:
                removeBrowser() // No Longer a browser? Remove browser
            case .advertiser:
                removeAdvertiser()
                _activeSession?.disconnect() // No Longer a advertiser? No longer advertise
            case .both:
                // No Longer both? Destory the manager we're not moving to
                if let newValue = newValue {
                    if !newValue.isBrowsing { removeBrowser() }
                    if !newValue.isAdvertising { removeAdvertiser() }
                } else {
                    removeBrowser()
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
                if oldValue != .both || oldValue != .browser {
                    createBrowser()
                }
            case .advertiser:
                if oldValue != .both || oldValue != .advertiser {
                    createAdvertiser()
                }
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
    
    // MARK: - Internal Properties
    private var advertiserListener: AnyCancellable?
    private var browserListener: AnyCancellable?
    private var backgroundListener: AnyCancellable?
    
    /// The currently Active MC Session
    private var _activeSession: MCSession? {
        didSet {
            if _activeSession == nil {
                delegate?.managerEndingSession(self)
            }
            
            _activeSession?.delegate = self
        }
    }
    
    var activeSession: MCSession {
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
    
    // MARK: - Initialization
    public init(serviceName: String, peerID: String? = nil) {
        self.serviceName = serviceName
        self.myPeerID = peerID.flatMap { MCPeerID(displayName: $0) } ?? MCPeerID(displayName: UIDevice.current.name)
    
        super.init()
        
        backgroundListener = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification, object: nil)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
    }
    
    // MARK: - Internal Methods For Override
    func handleDidEnterBackground() {
        sessionType = .none
    }
    
    // MARK: - Exposed Functions
    #if canImport(RealityKit)
    public func makeMultipeerConnectivityService() throws -> MultipeerConnectivityService {
        try MultipeerConnectivityService(session: activeSession)
    }
    #endif
    
    public func closeSession() {
        activeSession.disconnect()
        _activeSession = nil
    }
    
    public func requestJoinSession(_ peer: MCPeerID, context: Data?, timeout: TimeInterval = 60) throws {
        try browsingManager?.invitePeer(peer, session: activeSession, context: context, timeout: timeout)
    }
}

// MARK: - Internal Helpers
extension MultipeerSessionManager {
    func createAdvertiser() {
        let discoveryInfo = makeDiscoveryInfo()
        
        advertisingManager = AdvertisingManager(peerID: myPeerID, discoveryInfo: discoveryInfo, serviceType: self.serviceName)
        
        advertisingManager?.delegate = self
        
        advertiserListener = advertisingManager?.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }
    
    func removeAdvertiser() {
        advertiserListener?.cancel()
        advertisingManager?.stopAdvertising()
        
        DispatchQueue.main.async {
            self.advertisingManager = nil
        }
    }
    
    func createBrowser() {
        browsingManager = BrowsingManager(peerID: myPeerID, serviceType: self.serviceName)
        
        browserListener = browsingManager?.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
    }
    
    func removeBrowser() {
        browserListener?.cancel()
        browsingManager?.stopBrowsing()
        
        DispatchQueue.main.async {
            self.browsingManager = nil
        }
    }
    
    private func makeDiscoveryInfo() -> [String: String] {
        var discoveryInfo = self.delegate?.additionalDiscoveryInfo()
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

// MARK: - AdvertisingManagerDelegate
extension MultipeerSessionManager: AdvertisingManagerDelegate {
    public func manager(_ manager: AdvertisingManager, didReceiveJoinRequestFrom peer: MCPeerID, with inviteHandler: @escaping ((Bool, MCSession?) -> Void)) {
        let inviteCourier = SessionInvitationCourier(peer: peer, session: activeSession, invitationHandler: inviteHandler)
        activeInvitationCourier = inviteCourier
    }
}

// MARK: - MCSessionDelegate
extension MultipeerSessionManager: MCSessionDelegate {
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.manager(self, received: data, from: peerID)
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        delegate?.manager(self, receivedStream: stream, named: streamName, from: peerID)
    }
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
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
            print("Unhandled MCSessionState")
        }
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        delegate?.manager(self, startingReceiveOf: resourceName, from: peerID, progress: progress)
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        delegate?.manager(self, didReceiveResource: resourceName, from: peerID, localURL: localURL, error: error)
    }
    
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(delegate?.manager(self, receivedCertificate: certificate, from: peerID) ?? true)
    }
}
