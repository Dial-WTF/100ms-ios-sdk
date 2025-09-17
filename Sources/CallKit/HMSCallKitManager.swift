//
//  HMSCallKitManager.swift
//  HMSSDK
//
//  CallKit integration helper to manage audio session activation timing
//  with HMS SDK to prevent race conditions.
//

import Foundation
import CallKit

/// Manager for coordinating CallKit audio session activation with HMS SDK
public final class HMSCallKitManager: NSObject {
    
    public static let shared = HMSCallKitManager()
    
    /// Notification posted when CallKit audio session is activated and safe for SDK use
    public static let audioSessionDidActivateNotification = Notification.Name("HMSCallKitAudioSessionDidActivate")
    
    /// Notification posted when app becomes active AND CallKit is ready
    public static let readyForSDKNotification = Notification.Name("HMSCallKitReadyForSDK")
    
    private var isCallKitAudioActivated = false
    private var isAppActive = false
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        isAppActive = true
        checkReadyState()
    }
    
    @objc private func appDidEnterBackground() {
        isAppActive = false
    }
    
    /// Call this from your CXProviderDelegate's provider(_:didActivate:) method
    public func callKitAudioDidActivate() {
        isCallKitAudioActivated = true
        
        NotificationCenter.default.post(
            name: Self.audioSessionDidActivateNotification,
            object: nil
        )
        
        checkReadyState()
    }
    
    /// Call this from your CXProviderDelegate's provider(_:didDeactivate:) method
    public func callKitAudioDidDeactivate() {
        isCallKitAudioActivated = false
    }
    
    private func checkReadyState() {
        if isCallKitAudioActivated && isAppActive {
            NotificationCenter.default.post(
                name: Self.readyForSDKNotification,
                object: nil
            )
        }
    }
    
    /// Check if it's currently safe to instantiate HMS SDK
    public var isReadyForSDK: Bool {
        return isCallKitAudioActivated && isAppActive
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}