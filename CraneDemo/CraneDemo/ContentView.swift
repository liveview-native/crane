//
//  ContentView.swift
//  CraneDemo
//
//  Created by Carson.Katri on 3/11/25.
//

import SwiftUI
import LiveViewNative
import Crane

struct ContentView: View {
    @State private var crane = Crane()
    
    @State private var urlText = ""
    @State private var chromeVisible = true
    
    @State private var selectedTab: String?
    
    @AppStorage("favorites") private var favorites = Favorites(value: [])
    
    struct Favorites: RawRepresentable, Codable {
        let value: Set<URL>
        
        init(value: Set<URL>) {
            self.value = value
        }
        
        init?(rawValue: String) {
            guard let result = try? JSONDecoder().decode(Set<URL>.self, from: Data(rawValue.utf8))
            else { return nil }
            self.value = result
        }
        
        var rawValue: String {
            guard let data = try? JSONEncoder().encode(self.value),
                  let value = String(data: data, encoding: .utf8)
            else { return "[]" }
            return value
        }
    }
    
    struct StylesheetLoader<Content: View>: View {
        let url: URL
        @ViewBuilder let content: (Stylesheet<EmptyRegistry>?) -> Content
        
        @State private var stylesheet: Stylesheet<EmptyRegistry>?
        
        var body: some View {
            VStack {
                if let stylesheet {
                    content(stylesheet)
                } else {
                    ProgressView("Stylesheet")
                }
            }
            .task(id: url) {
                do {
                    let (stylesheetData, _) = try await URLSession.shared.data(from: url)
                    self.stylesheet = try? Stylesheet<EmptyRegistry>.init(from: String(data: stylesheetData, encoding: .utf8)!)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    struct WindowView: View {
        var window: Crane.Window
        let navigate: (URL) -> ()
        
        var body: some View {
            let _ = print("\(window.url)")
            NavigationStack(path: .constant([LiveNavigationEntry<EmptyRegistry>]())) {
                Group {
                    if let stylesheetURL = window.stylesheets.first.flatMap({ URL(string: $0, relativeTo: window.url) }) {
                        StylesheetLoader(url: stylesheetURL) { stylesheet in
                            DocumentView<EmptyRegistry>(
                                url: window.url,
                                document: window.document,
                                stylesheet: stylesheet
                            )
                        }
                    } else {
                        DocumentView<EmptyRegistry>(
                            url: window.url,
                            document: window.document,
                            stylesheet: nil
                        )
                    }
                }
                .navigationDestination(for: LiveNavigationEntry<EmptyRegistry>.self) { entry in
                    EmptyView()
                }
            }
            .environment(\.navigationHandler, { url in
                navigate(url)
            })
            .id(window.url)
            .transition(.opacity)
            .animation(.default, value: window.url)
        }
    }
    
    struct WindowLabel: View {
        let window: Crane.Window
        @State private var urlText: String
        
        @Environment(Crane.self) private var crane
        
        init(window: Crane.Window) {
            self.window = window
            self._urlText = .init(wrappedValue: window.url.absoluteString)
        }
        
        var body: some View {
            HStack {
                TextField("Enter URL", text: $urlText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .multilineTextAlignment(.center)
                    .onSubmit {
                        if let url = URL(string: urlText) {
                            Task {
                                try await crane.navigate(window: window, to: url)
                            }
                        }
                    }
                Button {
                    Task {
                        try await crane.refresh(window: window)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
    
    struct WindowControls: View {
        let window: Crane.Window
        
        @Environment(Crane.self) private var crane
        
        var body: some View {
            // Back button
            Menu {
                ForEach(Array(window.history.stack.enumerated()), id: \.offset) { entry in
                    Button {
                        // navigate to index
                        Task {
                            try! await crane.back(window: window)
                        }
                    } label: {
                        Text(entry.element.url)
                    }
                    .disabled(Int32(entry.offset) == window.history.index)
                }
            } label: {
                Image(systemName: "chevron.left")
            } primaryAction: {
                Task {
                    try! await crane.back(window: window)
                }
            }
            .disabled(!window.canGoBack)
            // Forward button
            Button {
                Task {
                    try! await crane.forward(window: window)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!window.canGoForward)
        }
    }
    
    var body: some View {
        return BrowserTabsView(selectedTab: $selectedTab, chromeVisible: chromeVisible) {
            ForEach(crane.windows, id: \.window.name) { window in
                BrowserTab(value: window.window.name) {
                    VStack {
//                        ForEach(Array(window.history.stack.enumerated()), id: \.offset) { entry in
//                            if entry.offset == window.history.index {
//                                Text("\(entry.element.url) (Active)")
//                            } else {
//                                Text(entry.element.url)
//                            }
//                        }
                        WindowView(window: window, navigate: { url in
                            Task {
                                try! await crane.navigate(window: window, to: url)
                            }
                        })
                    }
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let deltaY = value.translation.height
                                let scrollingDown = deltaY < 0
                                
                                if abs(deltaY) > 20 {
                                    withAnimation {
                                        chromeVisible = !scrollingDown
                                    }
                                }
                            }
                    )
                } label: {
                    if chromeVisible {
                        WindowLabel(window: window)
                    } else {
                        Button {
                            withAnimation {
                                chromeVisible = true
                            }
                        } label: {
                            Text(window.url.absoluteString)
                                .font(.caption)
                                .padding(4)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(Color.primary)
                        .padding(8)
                    }
                }
            }
        } newTabForm: {
            TextField("Enter URL", text: $urlText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .multilineTextAlignment(.center)
                .onSubmit {
                    if let url = URL(string: urlText) {
                        Task {
                            let window = try! await crane.newWindow(url: url)
                            selectedTab = window.window.name
                            urlText = ""
                        }
                    }
                }
        } newTabView: {
            NavigationStack {
                if favorites.value.isEmpty {
                    ContentUnavailableView("New Tab", systemImage: "plus.square.fill.on.square.fill")
                        .containerRelativeFrame(.horizontal)
                } else {
                    List {
                        Section("Favorites") {
                            ForEach(favorites.value.sorted(by: { $0.absoluteString < $1.absoluteString }), id: \.absoluteString) { favorite in
                                Button(favorite.absoluteString) {
                                    Task {
                                        let window = try! await crane.newWindow(url: favorite)
                                        selectedTab = window.window.name
                                        urlText = ""
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("New Tab")
                }
            }
            .containerRelativeFrame(.horizontal)
        } tabActions: {
            Button(role: .destructive) {
                Task {
                    guard let window = crane.windows.first(where: { $0.window.name == selectedTab })
                    else { return }
                    try await crane.close(window: window)
                }
            } label: {
                Label("Close", systemImage: "xmark")
            }
        } controls: {
            let window = crane.windows.first(where: { $0.window.name == selectedTab })
            if let window {
                WindowControls(window: window)
                ShareLink(item: window.url) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button {
                    var value = favorites.value
                    if favorites.value.contains(window.url) {
                        value.remove(window.url)
                    } else {
                        value.insert(window.url)
                    }
                    favorites = .init(value: value)
                } label: {
                    if favorites.value.contains(window.url) {
                        Image(systemName: "star.fill")
                    } else {
                        Image(systemName: "star")
                    }
                }
            } else {
                Button {} label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(true)
                Button {} label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(true)
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(true)
                Button {} label: {
                    Image(systemName: "star")
                }
                .disabled(true)
            }
        }
        .environment(crane)
        .task {
//            let window = try! await crane.newWindow(url: URL(string: "http://localhost:4000")!)
//            self.selectedTab = window.window.name
        }
        ZStack(alignment: .top) {
            // Content Area
            if let window = crane.windows.first {
                WindowView(window: window, navigate: { url in
                    Task {
                        try! await crane.navigate(window: window, to: url)
                    }
                })
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let deltaY = value.translation.height
                                let scrollingDown = deltaY < 0
                                
                                if abs(deltaY) > 20 {
                                    withAnimation {
                                        chromeVisible = !scrollingDown
                                    }
                                }
                            }
                    )
            }
            
            // Fixed Chrome UI
            VStack {
                // Top Chrome Area
                VStack {
                    HStack(spacing: 12) {
                        let window = crane.windows.first
                        

                        Button {
                            Task {
                                if let window {
                                    try! await crane.back(window: window)
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(window?.canGoBack ?? true)
                        
                        // Forward button
                        Button {
                            Task {
                                if let window = crane.windows.first {
                                    try! await crane.forward(window: window)
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(window?.canGoForward ?? true)
                        
                        // URL TextField
                        TextField("Enter URL", text: $urlText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .tint(.blue)
                            .onSubmit {
                                if let url = URL(string: urlText) {
                                    Task {
                                        if let window = crane.windows.first {
                                            try await crane.navigate(window: window, to: url)
                                        } else {
                                            try await crane.newWindow(url: url)
                                        }
                                    }
                                }
                            }
                        
                        // Reload button
                        Button {
                            Task {
                                if let window = crane.windows.first {
                                    try! await crane.refresh(window: window)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
                .offset(y: chromeVisible ? 0 : -150)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chromeVisible)
                
                Spacer()
                
                // Bottom toolbar area with settings button
//                HStack {
//                    Spacer()
//                    Button {
//                        isFavorite.toggle()
//                    } label: {
//                        Image(systemName: isFavorite ? "star.fill" : "star")
//                            .font(.system(size: 20))
//                            .foregroundColor(.blue)
//                            .padding(.trailing, 8)
//                    }
//                    Link(destination: URL(string: "https://dockyard.com")!) {
//                        Image(systemName: "seal.fill")
//                            .font(.system(size: 20))
//                            .foregroundColor(.blue)
//                            .padding(.trailing, 8)
//                    }
//                    Button {
//                        showSettings = true
//                    } label: {
//                        Image(systemName: "gear")
//                            .font(.system(size: 20))
//                            .foregroundColor(.blue)
//                            .padding(.trailing, 16)
//                    }
//                }
//                .frame(height: 44)
//                .background(.ultraThinMaterial)
//                .offset(y: chromeVisible ? 0 : 100)
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chromeVisible)
            }
        }
    }
}

#Preview {
    ContentView()
}
