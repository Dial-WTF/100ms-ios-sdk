//
//  CallKitTestViewController.swift
//  HMSSDKExample
//
//  Test view controller demonstrating CallKit integration with lazy HMS SDK
//

import UIKit
import CallKit
import SwiftUI

class CallKitTestViewController: UIViewController {
    
    // UI Elements
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var simulateCallButton: UIButton!
    @IBOutlet weak var endCallButton: UIButton!
    @IBOutlet weak var forceSDKButton: UIButton!
    @IBOutlet weak var clearLogsButton: UIButton!
    
    // CallKit Integration
    private let callKitProvider = TestCallKitProvider()
    private var currentCallUUID: UUID?
    private var logs: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLogging()
        updateStatus()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = "CallKit + HMS Test"
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupUI() {
        // Configure buttons
        simulateCallButton.setTitle("Simulate Incoming Call", for: .normal)
        endCallButton.setTitle("End Call", for: .normal)
        forceSDKButton.setTitle("Force SDK Instantiation", for: .normal)
        clearLogsButton.setTitle("Clear Logs", for: .normal)
        
        // Style buttons
        [simulateCallButton, endCallButton, forceSDKButton, clearLogsButton].forEach { button in
            button?.layer.cornerRadius = 8
            button?.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        }
        
        simulateCallButton.backgroundColor = .systemGreen
        endCallButton.backgroundColor = .systemRed
        forceSDKButton.backgroundColor = .systemOrange
        clearLogsButton.backgroundColor = .systemBlue
        
        // Configure log view
        logTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = UIColor.systemGray6
        logTextView.isEditable = false
        
        // Configure status label
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.numberOfLines = 0
    }
    
    private func setupLogging() {
        // Listen for CallKit manager notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(callKitAudioActivated),
            name: HMSCallKitManager.audioSessionDidActivateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(readyForSDK),
            name: HMSCallKitManager.readyForSDKNotification,
            object: nil
        )
    }
    
    @objc private func callKitAudioActivated() {
        addLog("[HMS] CallKit audio session activated")
        updateStatus()
    }
    
    @objc private func readyForSDK() {
        addLog("[HMS] Ready for SDK instantiation")
        updateStatus()
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logs.append(logEntry)
            self.logTextView.text = self.logs.joined(separator: "\n")
            
            // Auto-scroll to bottom
            let bottom = NSMakeRange(self.logTextView.text.count - 1, 1)
            self.logTextView.scrollRangeToVisible(bottom)
        }
    }
    
    private func updateStatus() {
        DispatchQueue.main.async {
            let callKitReady = HMSCallKitManager.shared.isReadyForSDK
            let hasActiveCall = self.currentCallUUID != nil
            
            var status = "CallKit Ready: \(callKitReady ? "✅" : "❌")\n"
            status += "Active Call: \(hasActiveCall ? "📞" : "❌")\n"
            status += "App State: \(UIApplication.shared.applicationState.description)"
            
            self.statusLabel.text = status
            
            // Update button states
            self.simulateCallButton.isEnabled = !hasActiveCall
            self.endCallButton.isEnabled = hasActiveCall
            self.forceSDKButton.isEnabled = !callKitReady
        }
    }
    
    // MARK: - Actions
    
    @IBAction private func simulateIncomingCall(_ sender: UIButton) {
        let uuid = UUID()
        currentCallUUID = uuid
        
        addLog("[CallKit] Simulating incoming call")
        
        callKitProvider.reportIncomingCall(uuid: uuid, handle: "HMS Test Call") { [weak self] error in
            if let error = error {
                self?.addLog("[CallKit] Error reporting call: \(error.localizedDescription)")
                self?.currentCallUUID = nil
            } else {
                self?.addLog("[CallKit] Incoming call reported successfully")
            }
            self?.updateStatus()
        }
    }
    
    @IBAction private func endCall(_ sender: UIButton) {
        guard let uuid = currentCallUUID else { return }
        
        addLog("[CallKit] Ending call")
        callKitProvider.endCall(uuid: uuid)
        currentCallUUID = nil
        updateStatus()
    }
    
    @IBAction private func forceSDKInstantiation(_ sender: UIButton) {
        addLog("[HMS] Force SDK instantiation requested")
        
        // This simulates forcing SDK instantiation outside of the normal flow
        // In a real app, this would be done through your lazy SDK instance
        NotificationCenter.default.post(name: HMSCallKitManager.readyForSDKNotification, object: nil)
    }
    
    @IBAction private func clearLogs(_ sender: UIButton) {
        logs.removeAll()
        logTextView.text = ""
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Test CallKit Provider

private class TestCallKitProvider: NSObject {
    
    private let callController = CXCallController()
    private let provider: CXProvider
    
    override init() {
        let configuration = CXProviderConfiguration(localizedName: "HMS Test")
        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        
        // Configure audio settings
        configuration.audioSessionMode = AVAudioSession.Mode.videoChat.rawValue
        
        provider = CXProvider(configuration: configuration)
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, completion: @escaping (Error?) -> Void) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.hasVideo = true
        callUpdate.localizedCallerName = handle
        
        provider.reportNewIncomingCall(with: uuid, update: callUpdate, completion: completion)
    }
    
    func endCall(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("[CallKit] Error ending call: \(error)")
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension TestCallKitProvider: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        print("[CallKit] Provider did reset")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallKit] User answered call: \(action.callUUID)")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallKit] Call ended: \(action.callUUID)")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("[CallKit] Starting call: \(action.callUUID)")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session activated")
        
        // THIS IS THE CRITICAL INTEGRATION POINT
        HMSCallKitManager.shared.callKitAudioDidActivate()
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session deactivated")
        
        HMSCallKitManager.shared.callKitAudioDidDeactivate()
    }
}

// MARK: - Extensions

extension UIApplication.State {
    var description: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .background: return "Background"
        @unknown default: return "Unknown"
        }
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}