//
//  BrowsingManagerTests.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import MultipeerConnectivity
@testable import MultipeerKit
import XCTest

class MockBrowser: ServiceBrowserProtocol {
    
    var startCalled: Bool = false
    var stopCalled: Bool = false
    
    var invitePeerCalled: Bool = false

    weak var delegate: MCNearbyServiceBrowserDelegate?
    
    func startBrowsingForPeers() {
        startCalled = true
    }
    
    func stopBrowsingForPeers() {
        stopCalled = true
    }
    
    func invitePeer(_ peerID: MCPeerID, to session: MCSession, withContext context: Data?, timeout: TimeInterval) {
        invitePeerCalled = true
    }
}

enum MockError: Error {
    case mock
}

class MockBrowsingManagerDelegate: BrowsingManagerDelegate {
    var validationError: Error?
    
    func manager(_ manager: BrowsingManager, validatePeer: MCPeerID, withDiscoveryInfo info: [String : String]?) throws {
        if let error = validationError {
            throw error
        }
    }
}

class BrowsingManagerTests: XCTestCase {
    
    var managerUnderTest: BrowsingManager!
    var mockBrowser: MockBrowser!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        mockBrowser = MockBrowser()
        managerUnderTest = BrowsingManager(serviceBrowser: mockBrowser)
    }

    func testBrowsingManager_start() {
        // Act
        managerUnderTest.startBrowsing()
        
        // Assert
        XCTAssertEqual(managerUnderTest.browsingState, .browsing)
        XCTAssertTrue(mockBrowser.startCalled)
        XCTAssertFalse(mockBrowser.stopCalled)
    }
    
    func testBrowsingManager_stop() {
        // Act + Assert
        managerUnderTest.startBrowsing()
        XCTAssertTrue(mockBrowser.startCalled)
        XCTAssertFalse(mockBrowser.stopCalled)
        
        managerUnderTest.stopBrowsing()
        // Assert
        XCTAssertEqual(managerUnderTest.browsingState, .notBrowsing)
        XCTAssertTrue(mockBrowser.stopCalled)
    }
    
    func testBrowsingManager_errorBrowsing() {
        // Act
        managerUnderTest.startBrowsing()
        
        let mockError = MockError.mock
        managerUnderTest.handleBrowsingError(mockError)
        
        // Assert
        XCTAssertEqual(managerUnderTest.browsingState, .errorBrowsing(mockError))
    }
    
    func testBrowsingManager_inviteChaining() throws {
        // Arrange
        let fakePeer = MCPeerID(displayName: "Mock")
        let fakeSession = MCSession(peer: MCPeerID(displayName: UIDevice.current.name))
        let fakeTime = TimeInterval(1)
        
        managerUnderTest.possiblePeers.append(fakePeer)
        
        // Act
        try managerUnderTest.invitePeer(fakePeer, session: fakeSession, context: nil, timeout: fakeTime)
        
        // Assert
        XCTAssertTrue(mockBrowser.invitePeerCalled)
    }
    
    func testBrowsingManager_handleFoundPeer_invalid() {
        // Arrange
        let fakePeer = MCPeerID(displayName: "Mock")
        let mockDelegate = MockBrowsingManagerDelegate()
        mockDelegate.validationError = MockError.mock
        
        managerUnderTest.delegate = mockDelegate
        
        // Act
        managerUnderTest.handleFoundPeer(fakePeer, withDiscoveryInfo: nil)
        
        // Assert
        XCTAssertTrue(managerUnderTest.possiblePeers.isEmpty)
    }
    
    func testBrowsingManager_handleFoundPeer_valid() {
        // Arrange
        let fakePeer = MCPeerID(displayName: "Mock")
        let mockDelegate = MockBrowsingManagerDelegate()
        
        managerUnderTest.delegate = mockDelegate
        
        // Act
        managerUnderTest.handleFoundPeer(fakePeer, withDiscoveryInfo: nil)
        
        // Assert
        XCTAssertEqual(managerUnderTest.possiblePeers, [fakePeer])
    }
}
