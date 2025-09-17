import XCTest
import HMSSDK

class Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    // MARK: - CallKit Integration Tests
    
    func testCallKitManagerInitialization() {
        // Test that CallKit manager can be initialized
        let manager = HMSCallKitManager.shared
        XCTAssertNotNil(manager, "CallKit manager should be initialized")
        XCTAssertFalse(manager.isReadyForSDK, "Initially should not be ready for SDK")
    }
    
    func testAVAudioSessionInterceptorInstallation() {
        // Test interceptor installation/uninstallation
        AVAudioSessionInterceptor.install()
        
        // Installing again should be safe (no-op)
        AVAudioSessionInterceptor.install()
        
        // Uninstall should work
        AVAudioSessionInterceptor.uninstall()
        XCTAssert(true, "Interceptor install/uninstall should not crash")
    }
    
    func testLazySDKConfiguration() {
        let config = HMSLazySDKConfig(
            gateNotification: .init("TestNotification"),
            instantiationTimeout: 5.0,
            allowFallbackInstantiation: true
        )
        
        XCTAssertEqual(config.instantiationTimeout, 5.0)
        XCTAssertTrue(config.allowFallbackInstantiation)
        XCTAssertEqual(config.gateNotification.rawValue, "TestNotification")
    }
    
    func testCallKitManagerStateTransitions() {
        let manager = HMSCallKitManager.shared
        let expectation = self.expectation(description: "CallKit state change")
        
        // Listen for ready notification
        let observer = NotificationCenter.default.addObserver(
            forName: HMSCallKitManager.readyForSDKNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Simulate CallKit activation
        manager.callKitAudioDidActivate()
        
        // Wait for notification (should happen when app becomes active)
        waitForExpectations(timeout: 1.0) { error in
            if let error = error {
                XCTFail("Expected notification not received: \(error)")
            }
        }
        
        NotificationCenter.default.removeObserver(observer)
    }

}
