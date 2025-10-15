//
//  GroupsView.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-28.
//

import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var model: AppModel
    @State private var searchText = ""
    
    var filteredGroups: [Group] {
        let activeGroups = model.activeGroups
        if searchText.isEmpty {
            return activeGroups
        } else {
            return activeGroups.filter { group in
                group.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search groups...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if model.isLoading {
                    ProgressView("Loading groups...")
                        .frame(maxHeight: .infinity)
                } else if filteredGroups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "No groups yet" : "No groups found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Tap + to create your first group")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredGroups) { group in
                                GroupRow(group: group)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Your Groups")
            .refreshable {
                await model.loadActiveGroups()
            }
        }
    }
}

struct GroupRow: View {
    @EnvironmentObject var model: AppModel
    let group: Group
    
    var groupBalance: Double? {
        model.balanceLines.first(where: { $0.groupId == group.id })?.amount
    }
    
    var memberCount: Int {
        model.usersByGroup[group.id]?.count ?? 0
    }
    
    var emoji: String {
        let name = group.name.lowercased()
        if name.contains("ski") || name.contains("whistler") {
            return "⛷️"
        } else if name.contains("beach") || name.contains("ocean") {
            return "🏖️"
        } else if name.contains("camp") {
            return "🏕️"
        } else if name.contains("vegas") || name.contains("party") {
            return "🎰"
        } else if name.contains("food") || name.contains("tokyo") || name.contains("dinner") {
            return "🍜"
        } else if name.contains("road") {
            return "🚗"
        } else {
            return "✈️"
        }
    }
    
    var body: some View {
        Button {
            Task {
                await model.selectGroup(group)
            }
        } label: {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("Group ID: \(group.id)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        // Member avatars (real data from backend)
                        if let members = model.usersByGroup[group.id], !members.isEmpty {
                            HStack(spacing: -8) {
                                ForEach(members.prefix(3)) { member in
                                    Circle()
                                        .fill(colorForName(member.name))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(member.name.prefix(1).uppercased())
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                if members.count > 3 {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text("+\(members.count - 3)")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                        } else {
                            Text("\(memberCount) members")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let balance = groupBalance {
                        if balance < 0 {
                            Text("Owe \(model.formattedAmount(abs(balance)))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.red)
                        } else if balance > 0 {
                            Text("+\(model.formattedAmount(balance))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text("Settled")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        HStack(spacing: 12) {
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                    
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if model.usersByGroup[group.id] == nil {
                Task {
                    await model.loadGroupMembers(for: group.id)
                }
            }
        }
    }
    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        let hash = name.hash
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    GroupsView()
        .environmentObject(AppModel())
}
