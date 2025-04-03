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
    @State private var server: ElixirKitCrane
    
    init() {
        setenv("GRPC_PORT", String(port), 0)
        self._server = .init(wrappedValue: ElixirKitCrane())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(server)
        }
    }
}
