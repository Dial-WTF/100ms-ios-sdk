//
//  App.swift
//  SwiftUIExample
//
//  Created by Pawan Dixit on 16/12/2022.
//

import SwiftUI

@main
struct SwiftUIExampleApp: App {
    
    init() {
        // IMPORTANT: Install AVAudioSession interceptor early to debug any timing issues
        // Uncomment the line below when using CallKit integration
        // AVAudioSessionInterceptor.install()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
