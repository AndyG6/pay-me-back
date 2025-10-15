//
//  AppModel.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-28.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentUser = User(id: 1, name: "Andy")
    @Published var groups: [Group] = []
    @Published var currentGroup: Group? = nil
    @Published var expensesByGroup: [Int: [Expense]] = [:]
    @Published var usersByGroup: [Int: [User]] = [:]
    @Published var activeGroups: [Group] = []
    @Published var settledGroups: [Group] = []
    @Published var balanceLines: [BalanceLine] = []
    @Published var currentGroupBalance: GroupBalance? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var memberBalances: [Int: Double] = [:]
    @Published var settlementStatus: [Int: SettlementStatus] = [:]


    
    private let apiClient = APIClient()
    
    
    init() {
        Task {
            await loadInitialData()
        }
    }
    
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        await loadActiveGroups()
        await loadUserBalance(status: "active")
        
        if let firstGroup = activeGroups.first {
            await selectGroup(firstGroup)
        }
        
        isLoading = false
    }
    
    func loadGroups(status: String = "active") async {
            do {
                let fetchedGroups = try await apiClient.getGroups(userId: currentUser.id, status: status)
                
                if status == "active" {
                    activeGroups = fetchedGroups
                } else if status == "settled" {
                    settledGroups = fetchedGroups
                }
            } catch {
                handleError(error)
            }
    }
        
    func loadActiveGroups() async {
        await loadGroups(status: "active")
    }
        
    func loadSettledGroups() async {
        await loadGroups(status: "settled")
    }
    
    func loadUserBalance(status: String = "active") async {
            do {
                let fetchedBalances = try await apiClient.getUserBalance(userId: currentUser.id, status: status)
                balanceLines = fetchedBalances
            } catch {
                handleError(error)
            }
        }
        
    
    func loadMemberBalances(for groupId: Int) async {
        guard let members = usersByGroup[groupId] else { return }
        for member in members {
            do {
                let balance = try await apiClient.getGroupBalance(
                    groupId: groupId,
                    userId: member.id
                    
                )
                memberBalances[member.id] = balance.net
            } catch {
                handleError(error)
            }
        }
    }
    
    func loadSettlementStatus(for groupId: Int) async {
            do {
                let status = try await apiClient.getSettlementStatus(groupId: groupId)
                settlementStatus[groupId] = status
            } catch {
                handleError(error)
            }
    }
        
    func requestSettleGroup(groupId: Int) async {
            do {
                try await apiClient.requestSettleGroup(groupId: groupId, userId: currentUser.id)
                
                // Reload settlement status and groups
                await loadSettlementStatus(for: groupId)
                await loadGroups()
            } catch {
                handleError(error)
            }
    }
    
    func selectGroup(_ group: Group) async {
        print("🟡 selectGroup called for: \(group.name), id: \(group.id)")
        currentGroup = group
        
        await loadExpenses(for: group.id)
        await loadGroupMembers(for: group.id)
        await loadGroupBalance(for: group.id)
        await loadMemberBalances(for: group.id)
    }
    
    func loadExpenses(for groupId: Int) async {
        print("🔵 loadExpenses called for groupId: \(groupId)")
        do {
            let fetchedExpenses = try await apiClient.getExpenses(groupId: groupId)
            expensesByGroup[groupId] = fetchedExpenses
        } catch {
            handleError(error)
        }
    }
    
    func loadGroupMembers(for groupId: Int) async {
        do {
            let fetchedUsers = try await apiClient.getGroupMembers(groupId: groupId)
            usersByGroup[groupId] = fetchedUsers
        } catch {
            handleError(error)
        }
    }
    
    func loadGroupBalance(for groupId: Int) async {
        do {
            let balance = try await apiClient.getGroupBalance(groupId: groupId, userId: currentUser.id)
            currentGroupBalance = balance
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Actions
    
    func addExpense(groupId: Int, amount: Double, description: String, paidBy: User) async {
            if usersByGroup[groupId] == nil {
                await loadGroupMembers(for: groupId)
            }
            
            guard let members = usersByGroup[groupId] else {
                handleError(NSError(domain: "AppModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load group members"]))
                return
            }
            
            let participantIds = members.map { $0.id }
            
            do {
                let newExpense = try await apiClient.addExpense(
                    groupId: groupId,
                    paidBy: paidBy.id,
                    amount: amount,
                    description: description,
                    participantIds: participantIds
                )
                
                // Update local data
                var currentExpenses = expensesByGroup[groupId] ?? []
                currentExpenses.insert(newExpense, at: 0)
                expensesByGroup[groupId] = currentExpenses
                
                // Refresh balances
                await loadGroupBalance(for: groupId)
                await loadUserBalance()
                
            } catch {
                handleError(error)
            }
        }
    
    func deleteExpense(_ expense: Expense) async {
        do {
            try await apiClient.deleteExpense(id: expense.id)
            
            // Update local data
            if var expenses = expensesByGroup[expense.groupId] {
                expenses.removeAll { $0.id == expense.id }
                expensesByGroup[expense.groupId] = expenses
            }
            
            // Refresh balances
            await loadGroupBalance(for: expense.groupId)
            await loadUserBalance()
            
        } catch {
            handleError(error)
        }
    }
    
    func createGroup(name: String, memberIds: [Int]) async {
        do {
            let newGroup = try await apiClient.createGroup(name: name, memberIds: memberIds)
            groups.append(newGroup)
            
            await selectGroup(newGroup)
            
        } catch {
            handleError(error)
        }
    }
    
    
    
    // MARK: - Computed Properties
    
    var currentGroupExpenses: [Expense] {
        guard let currentGroup = currentGroup else { return [] }
        return expensesByGroup[currentGroup.id] ?? []
    }
    
    var currentGroupMembers: [User] {
        guard let currentGroup = currentGroup else { return [] }
        return usersByGroup[currentGroup.id] ?? []
    }
    
    // MARK: - Utility
    
    private func handleError(_ error: Error) {
        print("Error: \(error)")
        errorMessage = error.localizedDescription
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Formatting Helpers
    
    func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    func formattedBalance(_ amount: Double) -> (text: String, color: Color) {
        if amount > 0.01 {
            return ("You're owed \(formattedAmount(amount))", .green)
        } else if amount < -0.01 {
            return ("You owe \(formattedAmount(abs(amount)))", .red)
        } else {
            return ("All settled up", .gray)
        }
    }
}
