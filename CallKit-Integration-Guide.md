# HMS SDK CallKit Integration Guide

## Problem Statement

When integrating HMS SDK with CallKit, there's a potential race condition with AVAudioSession management. The HMS SDK (delivered as a precompiled XCFramework) configures AVAudioSession internally during instantiation, which can conflict with CallKit's audio session management if the SDK is instantiated before CallKit has properly activated.

This can result in:
- Audio session category conflicts
- CallKit audio activation failures
- Inconsistent audio routing behavior
- App crashes or audio glitches during VoIP calls

## Solution Overview

This fork provides three key components to solve the AVAudioSession race condition:

1. **AVAudioSession Interceptor** - Diagnostic tool to log and track audio session changes
2. **CallKit Manager** - Coordinates CallKit audio activation with HMS SDK instantiation
3. **Lazy HMS Prebuilt View** - Delays SDK instantiation until CallKit is ready

## Quick Start

### 1. Install the Interceptor (Required for Diagnostics)

In your `AppDelegate.swift`, install the interceptor as the **first thing** in `didFinishLaunchingWithOptions`:

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // CRITICAL: Install interceptor FIRST, before any HMS code
        AVAudioSessionInterceptor.install()
        
        // Your other setup code...
        
        return true
    }
}
```

### 2. Set Up CallKit Integration

Create a CallKit provider and integrate with HMS CallKit manager:

```swift
import CallKit

class YourCallKitProvider: NSObject, CXProviderDelegate {
    
    private let provider: CXProvider
    
    override init() {
        let config = CXProviderConfiguration(localizedName: "Your App")
        config.supportsVideo = true
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    // CRITICAL: Notify HMS when CallKit audio activates
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session activated")
        HMSCallKitManager.shared.callKitAudioDidActivate()
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session deactivated") 
        HMSCallKitManager.shared.callKitAudioDidDeactivate()
    }
    
    // Other delegate methods...
}
```

### 3. Use Lazy HMS View

Replace your regular HMS view with the lazy variant:

```swift
import SwiftUI

struct CallView: View {
    var body: some View {
        // This view will wait for CallKit audio activation before instantiating HMS SDK
        HMSPrebuiltViewLazy(
            token: "your-auth-token",
            onDismiss: {
                // Handle call end
            }
        )
    }
}
```

## Advanced Configuration

### Custom Gate Notifications

You can specify a custom notification to gate SDK instantiation:

```swift
HMSPrebuiltViewLazy(
    token: "your-auth-token",
    gateNotification: .init("MyCustomReadyNotification")
)
```

### Lazy SDK with Custom Configuration

For more control, use the `HMSLazySDK` directly:

```swift
class MyCallViewModel: ObservableObject {
    
    @Published var lazySDK = HMSLazySDK(
        config: HMSLazySDKConfig(
            gateNotification: HMSCallKitManager.readyForSDKNotification,
            instantiationTimeout: 30.0,
            allowFallbackInstantiation: true
        )
    ) { sdk in
        // Custom SDK configuration
        sdk.trackSettings = HMSTrackSettings.build { videoBuilder, audioBuilder in
            audioBuilder.initialMuteState = .mute
            videoBuilder.initialMuteState = .mute
        }
    }
    
    func joinRoom() {
        // This will only succeed after SDK is instantiated
        guard let sdk = lazySDK.sdk else {
            print("SDK not ready yet")
            return
        }
        
        let config = HMSConfig(userName: "User", authToken: "token")
        sdk.join(config: config, delegate: self)
    }
}
```

## Verification and Debugging

### 1. Check Call Order with Logs

After installing the interceptor, you should see logs like:

```
[AVAS-TRACE] setCategory(playAndRecord, mode=videoChat, opts=[]) t=1234567890.123456
[AVAS-STACK]
0   YourApp    0x0000000100123456 specialized AVAudioSession.swz_setCategory(_:mode:options:) + 123
1   HMSSDK     0x0000000101234567 some_internal_hms_function + 456
...
```

**Before the fix**: You might see HMS SDK calls happening before CallKit activation.
**After the fix**: HMS SDK calls should only appear after `[CallKit] Audio session activated`.

### 2. Verify Timeline

The correct order should be:

1. `VoIP push received`
2. `CXProvider.reportNewIncomingCall`
3. `User answers → provider:performAnswer`
4. `provider:didActivate` (your CallKit delegate)
5. `HMSCallKitManager.shared.callKitAudioDidActivate()` (your code)
6. `[AVAS-TRACE] setCategory(...)` (HMS SDK instantiation)
7. HMS room join

### 3. Monitor Ready State

You can check if the system is ready for SDK instantiation:

```swift
if HMSCallKitManager.shared.isReadyForSDK {
    print("Safe to instantiate HMS SDK")
} else {
    print("Wait for CallKit activation")
}
```

## Migration Guide

### From Regular HMS SDK Usage

**Before:**
```swift
class ViewController {
    let hmsSDK = HMSSDK.build() // Instantiated immediately
    
    func joinCall() {
        let config = HMSConfig(userName: "User", authToken: token)
        hmsSDK.join(config: config, delegate: self)
    }
}
```

**After:**
```swift
class ViewController {
    @StateObject var lazySDK = HMSLazySDK() // Waits for gate
    
    func joinCall() {
        // SDK will be instantiated when CallKit is ready
        guard let sdk = lazySDK.sdk else { return }
        let config = HMSConfig(userName: "User", authToken: token)
        sdk.join(config: config, delegate: self)
    }
}
```

### From Regular HMS Prebuilt

**Before:**
```swift
HMSPrebuiltView(token: "auth-token") // Instantiates SDK immediately
```

**After:**
```swift
HMSPrebuiltViewLazy(token: "auth-token") // Waits for CallKit
```

## Troubleshooting

### SDK Never Instantiates

1. Check that `HMSCallKitManager.shared.callKitAudioDidActivate()` is called in your CallKit delegate
2. Verify app is active (not in background)
3. Check for timeout (default 30 seconds) - you can force instantiation with `lazySDK.forceInstantiation()`

### Still Getting Audio Session Conflicts

1. Verify interceptor is installed before any HMS code
2. Check interceptor logs to see if HMS calls are still happening early
3. Ensure you're using lazy variants everywhere, not mixing with regular HMS views

### CallKit Integration Issues

1. Verify CallKit entitlements are properly configured
2. Check that your app has microphone permissions
3. Test on device (CallKit doesn't work in simulator)

## Performance Notes

- The lazy instantiation adds minimal overhead (just notification observation)
- Timeout fallback ensures SDK will eventually instantiate even if gate notification fails
- Once instantiated, performance is identical to regular HMS SDK usage

## API Reference

See the source files for detailed API documentation:

- `AVAudioSessionInterceptor.swift` - Audio session logging
- `HMSCallKitManager.swift` - CallKit coordination  
- `HMSLazySDK.swift` - Lazy SDK wrapper
- `HMSPrebuiltViewLazy.swift` - Lazy prebuilt view
- `CallKitIntegrationExample.swift` - Complete integration example