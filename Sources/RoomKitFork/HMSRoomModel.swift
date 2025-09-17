//
//  HMSRoomModel.swift
//  HMS RoomKit Fork
//
//  Room model wrapper for HMS SDK
//

import Foundation
import HMSSDK

/// Observable room model that wraps HMS SDK functionality
public class HMSRoomModel: ObservableObject {
    
    private let sdk: HMSSDK
    private let token: String?
    private let roomCode: String?
    private let options: HMSRoomOptions?
    
    @Published public var isJoined = false
    @Published public var room: HMSRoom?
    @Published public var error: Error?
    
    public init(
        token: String,
        options: HMSRoomOptions? = nil,
        configBlock: ((HMSSDK, HMSAudioTrackSettingsBuilder, HMSVideoTrackSettingsBuilder) -> Void)? = nil
    ) {
        self.token = token
        self.roomCode = nil
        self.options = options
        
        self.sdk = HMSSDK.build { sdk in
            sdk.trackSettings = HMSTrackSettings.build { videoBuilder, audioBuilder in
                // Set default mute states
                audioBuilder.initialMuteState = options?.initialAudioMuted == true ? .mute : .unmute
                videoBuilder.initialMuteState = options?.initialVideoMuted == true ? .mute : .unmute
                
                // Call custom configuration block
                configBlock?(sdk, audioBuilder, videoBuilder)
            }
        }
    }
    
    public init(
        roomCode: String,
        options: HMSRoomOptions? = nil,
        configBlock: ((HMSSDK, HMSAudioTrackSettingsBuilder, HMSVideoTrackSettingsBuilder) -> Void)? = nil
    ) {
        self.token = nil
        self.roomCode = roomCode
        self.options = options
        
        self.sdk = HMSSDK.build { sdk in
            sdk.trackSettings = HMSTrackSettings.build { videoBuilder, audioBuilder in
                // Set default mute states
                audioBuilder.initialMuteState = options?.initialAudioMuted == true ? .mute : .unmute
                videoBuilder.initialMuteState = options?.initialVideoMuted == true ? .mute : .unmute
                
                // Call custom configuration block
                configBlock?(sdk, audioBuilder, videoBuilder)
            }
        }
    }
    
    /// Join the room session
    public func joinSession() {
        guard !isJoined else { return }
        
        if let token = token {
            let config = HMSConfig(userName: options?.userName ?? "User", authToken: token)
            sdk.join(config: config, delegate: self)
        } else if let roomCode = roomCode {
            // Note: In a real implementation, you'd need to get auth token from room code
            // This is a placeholder for the actual room code to token conversion
            print("[HMSRoomModel] Room code join not implemented in this example")
        }
    }
    
    /// Leave the room session
    public func leaveSession() {
        sdk.leave { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isJoined = false
                self?.room = nil
                if let error = error {
                    self?.error = error
                }
            }
        }
    }
    
    /// Get room layout (placeholder for actual implementation)
    public func getRoomLayout() async throws -> Any? {
        // This would normally fetch the room layout from HMS backend
        return nil
    }
}

// MARK: - HMSUpdateListener
extension HMSRoomModel: HMSUpdateListener {
    
    public func on(join room: HMSRoom) {
        DispatchQueue.main.async {
            self.isJoined = true
            self.room = room
        }
    }
    
    public func on(room: HMSRoom, update: HMSRoomUpdate) {
        DispatchQueue.main.async {
            self.room = room
        }
    }
    
    public func on(peer: HMSPeer, update: HMSPeerUpdate) {
        // Handle peer updates
    }
    
    public func on(track: HMSTrack, update: HMSTrackUpdate, for peer: HMSPeer) {
        // Handle track updates
    }
    
    public func on(error: Error) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
    public func on(message: HMSMessage) {
        // Handle messages
    }
    
    public func on(updated speakers: [HMSSpeaker]) {
        // Handle speaker updates
    }
    
    public func onReconnecting() {
        // Handle reconnecting
    }
    
    public func onReconnected() {
        // Handle reconnected
    }
}