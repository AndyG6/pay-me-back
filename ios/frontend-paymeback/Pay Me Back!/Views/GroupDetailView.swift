import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var model: AppModel
    let group: Group
    
    var expenses: [Expense] {
        model.expensesByGroup[group.id] ?? []
    }
        
    var settlementStatus: SettlementStatus? {
        model.settlementStatus[group.id]
    }
        
    var currentUserHasApproved: Bool {
        settlementStatus?.approvedUsers.contains(where: { $0.id == model.currentUser.id }) ?? false
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(model.currentGroupMembers.count) Members")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(model.currentGroupMembers) { member in
                            HStack {
                                Circle()
                                    .fill(colorForName(member.name))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(member.name.prefix(1).uppercased())
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                    )
                                
                                Text(member.name)
                                
                                if member.id == model.currentUser.id {
                                    Text("(You)")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let balance = model.memberBalances[member.id] {
                                    if balance > 0 {
                                        Text("Owed \(model.formattedAmount(balance))")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                            .padding(6)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                    } else if balance < 0 {
                                        Text("Owes \(model.formattedAmount(abs(balance)))")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                            .padding(6)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Expenses")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if expenses.isEmpty {
                            Text("No expenses yet")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(expenses) { expense in
                                VStack(alignment: .leading, spacing: 4) {
                                    let payer = model.currentGroupMembers.first { $0.id == expense.paidBy }
                                    HStack(alignment: .top) {
                                        Circle()
                                            .fill(colorForName(payer?.name ?? "Unknown"))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Text(payer?.name.prefix(1).uppercased() ?? "?")
                                                    .foregroundColor(.white)
                                                    .fontWeight(.semibold)
                                            )
                                        VStack(alignment: .leading) {
                                            Text(expense.description)
                                                .font(.body)
                                            
                                            Text("Paid by \(payer?.name ?? "Unknown")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(model.formattedAmount(expense.amount))
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text("End this trip?")
                                    .font(.headline)
                                
                                if let status = settlementStatus {
                                    Text("\(status.approvedCount) of \(status.totalMembers) members have approved")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if !status.approvedUsers.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Approved by:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            HStack(spacing: 8) {
                                                ForEach(status.approvedUsers) { user in
                                                    HStack(spacing: 4) {
                                                        Circle()
                                                            .fill(colorForName(user.name))
                                                            .frame(width: 24, height: 24)
                                                            .overlay(
                                                                Text(user.name.prefix(1).uppercased())
                                                                    .font(.caption2)
                                                                    .foregroundColor(.white)
                                                                    .fontWeight(.semibold)
                                                            )
                                                        Text(user.name)
                                                            .font(.caption)
                                                    }
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.green.opacity(0.1))
                                                    .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                } else {
                                    Text("Mark all members as settled and move this trip to your history.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            Button {
                                Task {
                                    await model.requestSettleGroup(groupId: group.id)
                                }
                            } label: {
                                HStack {
                                    if currentUserHasApproved {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("You've Approved")
                                    } else {
                                        Text("Approve Settlement")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(currentUserHasApproved ? Color.green : Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(currentUserHasApproved)
                            .padding(.horizontal, 32)
                        }
                        .padding(.vertical)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    currentUserHasApproved ? Color.green : Color.blue,
                                    style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                                )
                        )
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Group Details")
        .task(id: group.id) {
            await model.loadExpenses(for: group.id)
            await model.loadGroupMembers(for: group.id)
            await model.loadMemberBalances(for: group.id)
            await model.loadSettlementStatus(for: group.id)
        }
        .refreshable {
            await model.loadExpenses(for: group.id)
            await model.loadGroupMembers(for: group.id)
            await model.loadMemberBalances(for: group.id)
            await model.loadSettlementStatus(for: group.id)
        }
    }
    
    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        let hash = name.hash
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: Group(id: 1, name: "Whistler Ski Trip", status: "active"))
            .environmentObject(AppModel())
    }
}
