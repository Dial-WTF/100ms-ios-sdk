//
//  HMSPrebuiltViewLazy.swift
//  HMS RoomKit Fork
//
//  A lazy variant of HMSPrebuiltView that delays SDK instantiation until CallKit is ready,
//  preventing AVAudioSession race conditions.
//

import SwiftUI
import HMSSDK

/// A SwiftUI view that provides HMS room functionality with lazy SDK instantiation
/// to prevent AVAudioSession race conditions with CallKit
public struct HMSPrebuiltViewLazy: View {
    
    // Store init params
    private let roomCode: String?
    private let token: String?
    private let onDismiss: (() -> Void)?
    private let options: HMSPrebuiltOptions
    private let gateNotification: Notification.Name
    
    @State private var roomModel: HMSRoomModel?
    @StateObject private var roomInfoModel = HMSRoomInfoModel()
    @State private var isLayoutLoaded = false
    @State private var initializationError: Error?
    
    /// Initialize with auth token
    public init(
        token: String,
        options: HMSPrebuiltOptions? = nil,
        gateNotification: Notification.Name = HMSCallKitManager.readyForSDKNotification,
        onDismiss: (() -> Void)? = nil
    ) {
        self.token = token
        self.roomCode = nil
        self.options = options ?? HMSPrebuiltOptions()
        self.gateNotification = gateNotification
        self.onDismiss = onDismiss
    }
    
    /// Initialize with room code
    public init(
        roomCode: String,
        options: HMSPrebuiltOptions? = nil,
        gateNotification: Notification.Name = HMSCallKitManager.readyForSDKNotification,
        onDismiss: (() -> Void)? = nil
    ) {
        self.token = nil
        self.roomCode = roomCode
        self.options = options ?? HMSPrebuiltOptions()
        self.gateNotification = gateNotification
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        Group {
            if let roomModel = roomModel {
                if isLayoutLoaded {
                    HMSPrebuiltMeetingView(onDismiss: onDismiss)
                        .environmentObject(roomModel)
                        .environmentObject(roomInfoModel)
                        .environmentObject(options)
                        .environmentObject(options.roomOptions ?? HMSRoomOptions())
                } else {
                    HMSLoadingScreen(message: "Loading room layout...")
                }
            } else if let error = initializationError {
                HMSErrorScreen(error: error, onRetry: {
                    initializationError = nil
                    buildSDK()
                })
            } else {
                HMSLoadingScreen(message: "Waiting for audio session...")
            }
        }
        .environmentObject(options.theme ?? HMSTheme())
        .onReceive(NotificationCenter.default.publisher(for: gateNotification)) { _ in
            if roomModel == nil && initializationError == nil {
                buildSDK()
            }
        }
        .task {
            // Check if gate is already satisfied (e.g., warm start)
            if HMSCallKitManager.shared.isReadyForSDK && roomModel == nil {
                buildSDK()
            }
        }
    }
    
    private func buildSDK() {
        do {
            let newRoomModel: HMSRoomModel
            
            if let token = token {
                newRoomModel = HMSRoomModel(token: token, options: options.roomOptions) { sdk, audioBuilder, videoBuilder in
                    // Configure HMS SDK for CallKit compatibility
                    print("[HMSPrebuiltViewLazy] Configuring SDK for CallKit (token-based)")
                    
                    // Ensure tracks start muted to prevent early audio conflicts
                    audioBuilder.initialMuteState = .mute
                    videoBuilder.initialMuteState = .mute
                }
            } else if let roomCode = roomCode {
                newRoomModel = HMSRoomModel(roomCode: roomCode, options: options.roomOptions) { sdk, audioBuilder, videoBuilder in
                    // Configure HMS SDK for CallKit compatibility
                    print("[HMSPrebuiltViewLazy] Configuring SDK for CallKit (room code-based)")
                    
                    // Ensure tracks start muted to prevent early audio conflicts
                    audioBuilder.initialMuteState = .mute
                    videoBuilder.initialMuteState = .mute
                }
            } else {
                throw HMSPrebuiltError.missingCredentials
            }
            
            roomModel = newRoomModel
            
            Task {
                await loadLayout()
            }
            
        } catch {
            initializationError = error
        }
    }
    
    private func loadLayout() async {
        do {
            // In a real implementation, this would fetch the room layout
            _ = try await roomModel?.getRoomLayout()
            
            await MainActor.run {
                isLayoutLoaded = true
            }
        } catch {
            await MainActor.run {
                initializationError = error
            }
        }
    }
}

/// Room info model for managing room state
public class HMSRoomInfoModel: ObservableObject {
    @Published public var theme = HMSTheme()
}

/// Loading screen view
public struct HMSLoadingScreen: View {
    let message: String
    
    public init(message: String = "Loading...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundColor(.white)
    }
}

/// Error screen view
public struct HMSErrorScreen: View {
    let error: Error
    let onRetry: () -> Void
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: onRetry)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundColor(.white)
    }
}

/// Placeholder meeting view
public struct HMSPrebuiltMeetingView: View {
    let onDismiss: (() -> Void)?
    
    public var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("End Call") {
                    onDismiss?()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            
            Spacer()
            
            Text("HMS Meeting View")
                .font(.title)
                .foregroundColor(.white)
            
            Text("SDK initialized safely after CallKit activation")
                .font(.body)
                .foregroundColor(.gray)
                .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}


/// Prebuilt-specific errors
public enum HMSPrebuiltError: LocalizedError {
    case missingCredentials
    case sdkInstantiationFailed(Error)
    case layoutLoadFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Both token and room code are missing. Please provide one."
        case .sdkInstantiationFailed(let error):
            return "Failed to initialize HMS SDK: \(error.localizedDescription)"
        case .layoutLoadFailed(let error):
            return "Failed to load room layout: \(error.localizedDescription)"
        }
    }
}