//
//  HMSPrebuiltOptions.swift
//  HMS RoomKit Fork
//
//  Configuration options for HMS Prebuilt rooms
//

import Foundation

/// Options for configuring HMS Prebuilt rooms
public struct HMSPrebuiltOptions {
    public var roomOptions: HMSRoomOptions?
    public var theme: HMSTheme?
    
    public init(roomOptions: HMSRoomOptions? = nil, theme: HMSTheme? = nil) {
        self.roomOptions = roomOptions
        self.theme = theme
    }
}

/// Room-specific options
public struct HMSRoomOptions {
    public var userName: String?
    public var autoJoin: Bool
    public var initialAudioMuted: Bool
    public var initialVideoMuted: Bool
    
    public init(
        userName: String? = nil,
        autoJoin: Bool = true,
        initialAudioMuted: Bool = true,
        initialVideoMuted: Bool = true
    ) {
        self.userName = userName
        self.autoJoin = autoJoin
        self.initialAudioMuted = initialAudioMuted
        self.initialVideoMuted = initialVideoMuted
    }
}

/// Theme configuration for HMS Prebuilt
public struct HMSTheme {
    public var primaryColor: String
    public var backgroundColor: String
    
    public init(primaryColor: String = "#007AFF", backgroundColor: String = "#000000") {
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor
    }
}