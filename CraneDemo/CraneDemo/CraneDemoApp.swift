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
    @State private var server = ElixirKitCrane()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(server)
        }
    }
}
