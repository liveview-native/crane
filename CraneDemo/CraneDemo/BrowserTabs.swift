//
//  BrowserTabs.swift
//  CraneDemo
//
//  Created by Carson Katri on 3/13/25.
//

import SwiftUI

struct BrowserTabsView<ID: Hashable, Content: View, NewTabForm: View, NewTabView: View, TabActions: View, Controls: View>: View {
    @Binding var selectedTab: ID?
    let chromeVisible: Bool
    
    @ViewBuilder let content: () -> Content
    @ViewBuilder let newTabForm: () -> NewTabForm
    @ViewBuilder let newTabView: () -> NewTabView
    @ViewBuilder let tabActions: () -> TabActions
    @ViewBuilder let controls: () -> Controls
    
    @State private var scrollPosition: ScrollPosition = .init(x: 0)
    
    enum NewTabFormID {
        case id
    }
    
    var body: some View {
        let content = content()
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(subviews: content) { subview in
                    VStack {
                        subview
                            .scrollDisabled(false)
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(subview.containerValues.browserTabValue)
                }
                newTabView()
            }
            .scrollTargetLayout()
        }
        .scrollDisabled(true)
        .scrollPosition($scrollPosition)
        .frame(maxHeight: .infinity)
//        .safeAreaInset(edge: .bottom) {
        .overlay(alignment: .bottom) {
            ScrollViewReader { proxy in
                VStack {
                    VStack(spacing: 0) {
                        Divider()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(subviews: content) { subview in
                                    (subview.containerValues.browserTabLabel ?? AnyView(Text("")))
                                        .padding(chromeVisible ? 12 : 0)
                                        .frame(maxWidth: .infinity)
                                        .background {
                                            if chromeVisible {
                                                RoundedRectangle.rect(cornerRadius: 16, style: .continuous)
                                                    .fill(.ultraThinMaterial)
                                            }
                                        }
                                        .contextMenu {
                                            tabActions()
                                        }
                                        .compositingGroup()
                                        .shadow(color: .black.opacity(chromeVisible ? 0.2 : 0), radius: 3, y: 2)
                                        .padding(chromeVisible ? 16 : 0)
                                        .containerRelativeFrame(.horizontal)
                                        .id(subview.containerValues.browserTabValue)
                                }
                                newTabForm()
                                    .padding(chromeVisible ? 12 : 0)
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
                                    .compositingGroup()
                                    .shadow(color: .black.opacity(chromeVisible ? 0.2 : 0), radius: 3, y: 2)
                                    .padding(chromeVisible ? 16 : 0)
                                    .containerRelativeFrame(.horizontal)
                                    .id(NewTabFormID.id)
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                        .onScrollGeometryChange(for: CGPoint.self, of: { geometry in
                            geometry.contentOffset
                        }, action: { oldValue, newValue in
                            guard scrollPosition.point?.x != newValue.x else { return }
                            scrollPosition = .init(x: newValue.x)
                        })
                        .scrollPosition(id: $selectedTab)
                    }
                    if chromeVisible {
                        HStack {
                            ForEach(subviews: controls()) { subview in
                                subview
                                    .frame(maxWidth: .infinity)
                            }
                            Button {
                                withAnimation {
                                    proxy.scrollTo(NewTabFormID.id)
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .imageScale(.large)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(.bar)
                .frame(maxHeight: chromeVisible ? nil : 0)
            }
        }
    }
}

struct BrowserTab<ID: Hashable, Content: View, Label: View>: View {
    let value: ID
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label
    
    var body: some View {
        content()
            .containerValue(\.browserTabLabel, AnyView(label()))
            .containerValue(\.browserTabValue, value)
    }
}

extension ContainerValues {
    @Entry var browserTabLabel: AnyView? = nil
    @Entry var browserTabValue: AnyHashable? = nil
}

#Preview {
    @Previewable @State var selectedTab: Int? = 0
    BrowserTabsView(selectedTab: $selectedTab, chromeVisible: true) {
        ForEach(0..<10) { id in
            BrowserTab(value: id) {
                Text("Tab Content \(id)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.red)
            } label: {
                HStack {
                    TextField(text: .constant("Tab \(id)")) {
                        EmptyView()
                    }
                    Button {
                        
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    } newTabForm: {
        TextField(text: .constant(""), prompt: Text("New Tab")) {
            EmptyView()
        }
    } newTabView: {
        ContentUnavailableView("New Tab", systemImage: "plus.square.fill.on.square.fill")
            .containerRelativeFrame(.horizontal)
    } tabActions: {
        Button {
            
        } label: {
            Text("Close")
        }
    } controls: {
        Button {
            
        } label: {
            Image(systemName: "chevron.left")
        }
        Button {
            
        } label: {
            Image(systemName: "chevron.right")
        }
        Button {
            
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        Button {
            
        } label: {
            Image(systemName: "book")
        }
        Button {
            
        } label: {
            Image(systemName: "plus")
        }
    }
}
