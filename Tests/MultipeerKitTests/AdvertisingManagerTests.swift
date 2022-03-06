//
//  AdvertisingManagerTests.swift
//  
//
//  Created by John Davis on 3/6/22.
//

import XCTest
@testable import MultipeerKit
import MultipeerConnectivity

class MockAdvertiser: ServiceAdvertiserProtocol {
    
    var startCalled: Bool = false
    var stopCalled: Bool = false

    var delegate: MCNearbyServiceAdvertiserDelegate?
    
    func startAdvertisingPeer() {
        startCalled = true
    }
    
    func stopAdvertisingPeer() {
        stopCalled = true
    }
}

class MockAdvertiserManagerDelegate: AdvertisingManagerDelegate {
    var didReceiveJoinRequestCalled: Bool = false
    
    func manager(_ manager: AdvertisingManager, didReceiveJoinRequestFrom peer: MCPeerID, with inviteHandler: @escaping ((Bool, MCSession?) -> Void)) {
        didReceiveJoinRequestCalled = true
    }
}

class AdvertisingManagerTests: XCTestCase {

    var managerUnderTest: AdvertisingManager!
    var mockAdvertiser: MockAdvertiser!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        mockAdvertiser = MockAdvertiser()
        managerUnderTest = AdvertisingManager(advertiser: mockAdvertiser)
    }

    func testAdvertisingManager_start() {
        // Act
        managerUnderTest.startAdvertising()
        
        // Assert
        XCTAssertEqual(managerUnderTest.advertisingState, .advertising)
        XCTAssertTrue(mockAdvertiser.startCalled)
        XCTAssertFalse(mockAdvertiser.stopCalled)
    }
    
    func testAdvertisingManager_stop() {
        // Act + Assert
        managerUnderTest.startAdvertising()
        XCTAssertTrue(mockAdvertiser.startCalled)
        XCTAssertFalse(mockAdvertiser.stopCalled)
        
        managerUnderTest.stopAdvertising()
        // Assert
        XCTAssertEqual(managerUnderTest.advertisingState, .notAdvertising)
        XCTAssertTrue(mockAdvertiser.stopCalled)
    }
    
    func testAdvertisingManager_errorBrowsing() {
        // Act
        managerUnderTest.startAdvertising()
        
        let mockError = MockError.mock
        managerUnderTest.handleAdvertisingError(mockError)
        
        // Assert
        XCTAssertEqual(managerUnderTest.advertisingState, .errorAdvertising(mockError))
    }
    
    func testAdvertisingManager_joinChaining() {
        let fakePeer = MCPeerID(displayName: "Mock")
        let mockDelegate = MockAdvertiserManagerDelegate()
        
        // Act
        managerUnderTest.delegate = mockDelegate
        managerUnderTest.handleInvitationReceivedFromPeer(fakePeer, withContext: nil, invitationHandler: {_, _ in })
        
        // Assert
        XCTAssertTrue(mockDelegate.didReceiveJoinRequestCalled)
    }
}
