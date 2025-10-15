//
//  AddExpenseView.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-28.
//

import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedGroup: Group?
    @State private var selectedPayer: User?
    @State private var amount: Double = 0
    @State private var description: String = ""
    @State private var date = Date()
    
    var groupMembers: [User] {
        guard let selectedGroup = selectedGroup else { return [] }
        return model.usersByGroup[selectedGroup.id] ?? []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Make a payment") {
                        Picker("Adding To", selection: $selectedGroup) {
                            Text("Select Group").tag(nil as Group?)
                            ForEach(model.groups) { group in
                                Text(group.name).tag(group as Group?)
                            }
                        }
                        .onChange(of: selectedGroup) { oldValue, newValue in
                            if let group = newValue {
                                Task {
                                    await model.loadGroupMembers(for: group.id)
                                    if groupMembers.contains(where: { $0.id == model.currentUser.id }) {
                                        selectedPayer = model.currentUser
                                    } else if let firstMember = groupMembers.first {
                                        selectedPayer = firstMember
                                    }
                                }
                            }
                        }
                    }
                    
                    if let selectedGroup {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Paid by")
                                    .font(.headline)
                                
                                Picker("Paid by", selection: $selectedPayer) {
                                    Text("Select person").tag(nil as User?)
                                    ForEach(groupMembers) { member in
                                        HStack {
                                            Text(member.name)
                                            if member.id == model.currentUser.id {
                                                Text("(You)")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .tag(member as User?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                                )
                            }
                        }
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Amount")
                                    .font(.headline)
                                
                                HStack {
                                    Text("$")
                                        .foregroundColor(.secondary)
                                    
                                    TextField("0.00", value: $amount, format: .number)
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(.primary)
                                    
                                    Image(systemName: "calculator")
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                                )
                            }
                        }
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                
                                TextField("e.g. groceries", text: $description)
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                                    )
                            }
                        }
                        
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.headline)
                                
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                                    )
                            }
                        }
                    }
                }
                
                VStack(spacing: 0) {
                    Divider()
                        
                    Button {
                        Task {
                            await addExpense()
                        }
                    } label: {
                        Text("Add Expense")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isValid ? Color.blue : Color.gray)
                            )
                    }
                    .disabled(!isValid)
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Add Expense")
        }
    }
    
    var isValid: Bool {
        selectedGroup != nil &&
        selectedPayer != nil &&
        amount > 0 &&
        !description.isEmpty
    }
    
    func addExpense() async {
            guard let group = selectedGroup,
                  let payer = selectedPayer else { return }
            
            // Call addExpense with explicit groupId
            await model.addExpense(
                groupId: group.id,  // ← Pass groupId explicitly
                amount: amount,
                description: description,
                paidBy: payer
            )
            
            await model.selectGroup(group)
            selectedGroup = nil
            selectedPayer = nil
            amount = 0
            description = ""
            date = Date()
        }
}

#Preview {
    AddExpenseView()
        .environmentObject(AppModel())
}
