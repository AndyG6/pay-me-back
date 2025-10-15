//
//  RootView.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-27.
//

import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel() 
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            GroupsView()
                .tabItem {
                    Label("Groups", systemImage: "person.3")
                }
                .tag(1)
            
            AddExpenseView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }
                .tag(2)
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(3)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .environmentObject(model)
    }
}

#Preview {
    RootView()
}
