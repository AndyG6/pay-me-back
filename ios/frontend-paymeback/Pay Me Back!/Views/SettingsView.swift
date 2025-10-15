//
//  SettingsView.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-28.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var availableUsers: [User] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(colorForName(model.currentUser.name))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(model.currentUser.name.prefix(1).uppercased())
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.currentUser.name)
                                .font(.headline)
                            Text("User ID: \(model.currentUser.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Logged In As")
                }
                
                // Switch User Section
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(availableUsers.filter { $0.id != model.currentUser.id }) { user in
                            Button {
                                Task {
                                    await switchUser(to: user)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(colorForName(user.name))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(user.name.prefix(1).uppercased())
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("User ID: \(user.id)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    Text("Switch User")
                } footer: {
                    Text("For testing purposes. Switch between users to see their groups and balances.")
                }
                
                // App Info Section
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Backend Status")
                        Spacer()
                        Circle()
                            .fill(model.groups.isEmpty ? Color.red : Color.green)
                            .frame(width: 10, height: 10)
                        Text(model.groups.isEmpty ? "Offline" : "Connected")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .refreshable {
                await loadUsers()
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        do {
            let apiClient = APIClient()
            availableUsers = try await apiClient.getUsers()
        } catch {
            print("Failed to load users: \(error)")
        }
        isLoading = false
    }
    
    private func switchUser(to user: User) async {
        model.currentUser = user
        
        await model.loadInitialData()
    }
    
    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        let hash = name.hash
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppModel())
}
