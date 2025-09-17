//
//  AVAudioSessionInterceptor.swift
//  HMSSDK
//
//  Created for debugging AVAudioSession race conditions with CallKit.
//  This interceptor logs all AVAudioSession calls to help identify timing issues.
//

import Foundation
import AVFAudio
import ObjectiveC

/// A diagnostic tool that intercepts AVAudioSession calls to help debug timing issues
/// with CallKit integration. Install this as early as possible in your app lifecycle.
public final class AVAudioSessionInterceptor {
    
    /// Install the interceptor to begin logging AVAudioSession calls
    /// Call this in application(_:didFinishLaunchingWithOptions:) before any HMS code
    public static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        
        swizzle(#selector(AVAudioSession.setCategory(_:mode:options:)),
                #selector(AVAudioSession.swz_setCategory(_:mode:options:)))
        swizzle(#selector(AVAudioSession.setActive(_:options:)),
                #selector(AVAudioSession.swz_setActive(_:options:)))
    }
    
    /// Remove the interceptor (optional, mainly for testing)
    public static func uninstall() {
        guard isInstalled else { return }
        
        // Swizzle back to restore original implementations
        swizzle(#selector(AVAudioSession.swz_setCategory(_:mode:options:)),
                #selector(AVAudioSession.setCategory(_:mode:options:)))
        swizzle(#selector(AVAudioSession.swz_setActive(_:options:)),
                #selector(AVAudioSession.setActive(_:options:)))
        
        isInstalled = false
    }
    
    private static var isInstalled = false
    
    private static func swizzle(_ original: Selector, _ replacement: Selector) {
        let cls: AnyClass = AVAudioSession.self
        guard
            let origMethod = class_getInstanceMethod(cls, original),
            let newMethod  = class_getInstanceMethod(cls, replacement)
        else { 
            print("[AVAudioSessionInterceptor] Failed to swizzle \(original)")
            return 
        }
        method_exchangeImplementations(origMethod, newMethod)
    }
}

extension AVAudioSession {
    
    @objc func swz_setCategory(_ category: AVAudioSession.Category,
                               mode: AVAudioSession.Mode,
                               options: AVAudioSession.CategoryOptions = []) throws {
        let timestamp = AVAudioSessionInterceptor.timestamp()
        let stack = AVAudioSessionInterceptor.callStackSnippet()
        
        print("[AVAS-TRACE] setCategory(\(category.rawValue), mode=\(mode.rawValue), opts=\(options)) \(timestamp)")
        print("[AVAS-STACK]\n\(stack)")
        
        try swz_setCategory(category, mode: mode, options: options)
    }
    
    @objc func swz_setActive(_ active: Bool,
                             options: AVAudioSession.SetActiveOptions = []) throws {
        let timestamp = AVAudioSessionInterceptor.timestamp()
        let stack = AVAudioSessionInterceptor.callStackSnippet()
        
        print("[AVAS-TRACE] setActive(\(active), opts=\(options)) \(timestamp)")
        print("[AVAS-STACK]\n\(stack)")
        
        try swz_setActive(active, options: options)
    }
}

extension AVAudioSessionInterceptor {
    
    static func timestamp() -> String {
        let interval = Date().timeIntervalSince1970
        return String(format: "t=%.6f", interval)
    }
    
    static func callStackSnippet(limit: Int = 12) -> String {
        return Thread.callStackSymbols.prefix(limit).joined(separator: "\n")
    }
}