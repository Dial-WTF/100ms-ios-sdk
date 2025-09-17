//
//  CallKitIntegrationExample.swift
//  HMSSDK Examples
//
//  Example showing how to integrate HMS SDK with CallKit to prevent
//  AVAudioSession race conditions.
//

import Foundation
import CallKit
import UIKit

/// Example CallKit integration for HMS SDK
class CallKitIntegrationExample: NSObject {
    
    private let callController = CXCallController()
    private let provider: CXProvider
    
    override init() {
        // Configure CallKit provider
        let configuration = CXProviderConfiguration(localizedName: "HMS Video Call")
        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        
        provider = CXProvider(configuration: configuration)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, completion: @escaping (Error?) -> Void) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.hasVideo = true
        
        provider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            completion(error)
        }
    }
    
    func endCall(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("Error ending call: \(error)")
            }
        }
    }
}

// MARK: - CXProviderDelegate
extension CallKitIntegrationExample: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        print("[CallKit] Provider did reset")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallKit] User answered call")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallKit] Call ended")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session activated - notifying HMS CallKit manager")
        
        // THIS IS THE CRITICAL CALL - notify HMS that CallKit audio is ready
        HMSCallKitManager.shared.callKitAudioDidActivate()
        
        // Now it's safe for HMS SDK to be instantiated and configure audio session
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session deactivated")
        
        // Notify HMS that CallKit audio is no longer active
        HMSCallKitManager.shared.callKitAudioDidDeactivate()
    }
}

/// Example app delegate showing proper setup order
class ExampleAppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // STEP 1: Install AVAudioSession interceptor FIRST (before any HMS code)
        AVAudioSessionInterceptor.install()
        
        // STEP 2: Set up CallKit integration
        // (CallKitIntegrationExample would be initialized here)
        
        // STEP 3: Any other app setup...
        
        return true
    }
}

/// Example SwiftUI scene showing usage
import SwiftUI

struct CallKitExampleView: View {
    @State private var callUUID = UUID()
    @State private var showingMeeting = false
    @State private var callKitExample = CallKitIntegrationExample()
    
    var body: some View {
        VStack(spacing: 20) {
            
            Button("Simulate Incoming Call") {
                callKitExample.reportIncomingCall(
                    uuid: callUUID,
                    handle: "HMS Meeting"
                ) { error in
                    if let error = error {
                        print("Error reporting call: \(error)")
                    } else {
                        showingMeeting = true
                    }
                }
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if showingMeeting {
                Text("Call active - HMS SDK will instantiate when CallKit audio activates")
                    .padding()
                
                // Use the lazy view that waits for CallKit
                HMSPrebuiltViewLazy(
                    token: "your-auth-token-here",
                    onDismiss: {
                        showingMeeting = false
                        callKitExample.endCall(uuid: callUUID)
                        callUUID = UUID() // Generate new UUID for next call
                    }
                )
            }
        }
        .padding()
    }
}