//
//  HMSLazySDK.swift
//  HMSSDK
//
//  A wrapper around HMSSDK that delays instantiation until CallKit is ready,
//  preventing AVAudioSession race conditions.
//

import Foundation
import HMSSDK

/// Configuration for lazy SDK instantiation
public struct HMSLazySDKConfig {
    /// The gating notification to wait for before SDK instantiation
    public let gateNotification: Notification.Name
    
    /// Optional timeout for SDK instantiation (default: 30 seconds)
    public let instantiationTimeout: TimeInterval
    
    /// Whether to allow fallback instantiation if gate notification never arrives
    public let allowFallbackInstantiation: Bool
    
    public init(
        gateNotification: Notification.Name = HMSCallKitManager.readyForSDKNotification,
        instantiationTimeout: TimeInterval = 30.0,
        allowFallbackInstantiation: Bool = true
    ) {
        self.gateNotification = gateNotification
        self.instantiationTimeout = instantiationTimeout
        self.allowFallbackInstantiation = allowFallbackInstantiation
    }
}

/// A lazy wrapper around HMSSDK that delays instantiation until safe to do so
public final class HMSLazySDK: ObservableObject {
    
    private let config: HMSLazySDKConfig
    private let buildBlock: ((HMSSDK) -> Void)?
    
    @Published public private(set) var sdk: HMSSDK?
    @Published public private(set) var isInstantiated = false
    @Published public private(set) var instantiationError: Error?
    
    private var gateObserver: NSObjectProtocol?
    private var timeoutTimer: Timer?
    
    public init(
        config: HMSLazySDKConfig = HMSLazySDKConfig(),
        buildBlock: ((HMSSDK) -> Void)? = nil
    ) {
        self.config = config
        self.buildBlock = buildBlock
        setupGateObserver()
    }
    
    private func setupGateObserver() {
        gateObserver = NotificationCenter.default.addObserver(
            forName: config.gateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.instantiateSDK()
        }
        
        // Set up timeout timer
        if config.allowFallbackInstantiation {
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: config.instantiationTimeout, repeats: false) { [weak self] _ in
                self?.handleTimeout()
            }
        }
    }
    
    private func instantiateSDK() {
        guard !isInstantiated else { return }
        
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        do {
            let newSDK = HMSSDK.build { sdk in
                self.buildBlock?(sdk)
            }
            
            DispatchQueue.main.async {
                self.sdk = newSDK
                self.isInstantiated = true
                print("[HMSLazySDK] SDK instantiated successfully")
            }
        } catch {
            DispatchQueue.main.async {
                self.instantiationError = error
                print("[HMSLazySDK] SDK instantiation failed: \(error)")
            }
        }
    }
    
    private func handleTimeout() {
        guard !isInstantiated else { return }
        
        print("[HMSLazySDK] Gate notification timeout reached, instantiating SDK as fallback")
        instantiateSDK()
    }
    
    /// Force immediate SDK instantiation (use only if you're sure it's safe)
    public func forceInstantiation() {
        guard !isInstantiated else { return }
        
        print("[HMSLazySDK] Force instantiation requested")
        instantiateSDK()
    }
    
    /// Check if SDK is ready for operations that require it to be instantiated
    public var isReady: Bool {
        return isInstantiated && sdk != nil
    }
    
    deinit {
        if let observer = gateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timeoutTimer?.invalidate()
    }
}