//
//  HistoryView.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-10-03.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @State private var searchText = ""
    
    var filteredGroups: [Group] {
        let settledGroups = model.settledGroups
        if searchText.isEmpty {
            return settledGroups
        } else {
            return settledGroups.filter { group in
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
                    
                    TextField("Search settled trips...", text: $searchText)
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
                
                if model.settledGroups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No settled trips yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("When you complete and settle trips with your friends, they'll appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
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
            .navigationTitle("Trip History")
            .task {
                await model.loadSettledGroups()
            }
            .refreshable {
                await model.loadSettledGroups()
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppModel())
}
