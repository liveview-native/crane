//
//  CraneDemoApp.swift
//  CraneDemo
//
//  Created by Carson.Katri on 3/11/25.
//

import SwiftUI
import ElixirKitCrane

@main
struct CraneDemoApp: App {
    init() {
        ElixirKitCrane.start()
    }
    
    struct WaitForServer: View {
        @State private var isStarted = false
        
        var body: some View {
            VStack {
                if isStarted {
                    ContentView()
                } else {
                    ProgressView("waiting 3 seconds for server to start")
                }
            }
            .task {
                try! await Task.sleep(for: .seconds(3))
                isStarted = true
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            WaitForServer()
        }
    }
}
