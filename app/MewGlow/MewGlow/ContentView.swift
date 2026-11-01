//
//  ContentView.swift
//  MewGlow
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LampViewModel()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.softBackground)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            ConnectView()
                .tabItem {
                    Label("Device", systemImage: "antenna.radiowaves.left.and.right")
                }

            ControlView()
                .tabItem {
                    Label("Control", systemImage: "house")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .tint(AppTheme.darkText)
        .environmentObject(viewModel)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
