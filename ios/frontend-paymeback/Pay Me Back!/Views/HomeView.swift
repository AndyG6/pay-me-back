//
//  HomeView.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-27.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Binding var selectedTab: Int
    
    enum Tab: String, CaseIterable {
        case owe = "Owe"
        case owed = "Owed"
        case all = "All"
    }
    
    @State private var selectedFilter: Tab = .all
    
    var filteredBalances: [BalanceLine] {
        switch selectedFilter {
        case .owe:
            return model.balanceLines.filter { $0.amount < 0 }
        case .owed:
            return model.balanceLines.filter { $0.amount > 0 }
        case .all:
            return model.balanceLines
        }
    }
    var totalAmount: Double {
        switch selectedFilter {
        case .owe:
            return model.balanceLines
                .filter { $0.amount < 0 }
                .map { abs($0.amount) }
                .reduce(0, +)
        case .owed:
            return model.balanceLines
                .filter { $0.amount > 0 }
                .map { $0.amount }
                .reduce(0, +)
        case .all:
            return model.balanceLines
                .map { $0.amount }
                .reduce(0, +)
        }
    }
    
    var summaryText: String {
        let tripCount = filteredBalances.count
        switch selectedFilter {
        case .owe:
            return "You owe across \(tripCount) trip\(tripCount == 1 ? "" : "s")"
        case .owed:
            return "You're owed across \(tripCount) trip\(tripCount == 1 ? "" : "s")"
        case .all:
            if totalAmount > 0 {
                return "You're owed across \(tripCount) trip\(tripCount == 1 ? "" : "s")"
            } else if totalAmount < 0 {
                return "You owe across \(tripCount) trip\(tripCount == 1 ? "" : "s")"
            } else {
                return "All settled up!"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                
                Picker("", selection: $selectedFilter) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if model.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredBalances.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: selectedFilter == .owe ? "checkmark.circle" :
                                         selectedFilter == .owed ? "dollarsign.circle" :
                                         "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(selectedFilter == .owe ? .green : .blue)
                        
                        Text(selectedFilter == .owe ? "You don't owe anything!" :
                             selectedFilter == .owed ? "Nobody owes you" :
                             "All settled up!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 4) {
                        Text(model.formattedAmount(abs(totalAmount)))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(totalAmount < 0 ? .red :
                                           totalAmount > 0 ? .green : .primary)
                        
                        Text(summaryText)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    HStack {
                        Text("Your Trips")
                            .font(.headline)
                        Spacer()
                        Button("See all groups") {
                            selectedTab = 1
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    List(filteredBalances) { balance in
                        HStack {
                            Text(emojiForGroup(balance.groupName))
                                .font(.largeTitle)
                            
                            VStack(alignment: .leading) {
                                Text(balance.groupName)
                                    .font(.headline)
                                
                                Text("Group ID: \(balance.groupId)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if balance.amount < 0 {
                                Text("You owe \(model.formattedAmount(abs(balance.amount)))")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                Text("You're owed \(model.formattedAmount(balance.amount))")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .padding(6)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Home")
            .refreshable {
                await model.loadUserBalance()
            }
        }
    }
    
    // Helper function to assign emojis based on group name
    private func emojiForGroup(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        if lowercased.contains("ski") || lowercased.contains("whistler") {
            return "🎿"
        } else if lowercased.contains("beach") || lowercased.contains("ocean") {
            return "🏖️"
        } else if lowercased.contains("camp") {
            return "🏕️"
        } else if lowercased.contains("vegas") || lowercased.contains("party") {
            return "🎰"
        } else if lowercased.contains("road") || lowercased.contains("trip") {
            return "🚗"
        } else if lowercased.contains("dinner") || lowercased.contains("food") {
            return "🍽️"
        } else {
            return "✈️"
        }
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .environmentObject(AppModel())
}
