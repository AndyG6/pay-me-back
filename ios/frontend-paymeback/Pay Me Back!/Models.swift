//
//  Models.swift
//  Pay Me Back!
//
//  Created by Andy Guo on 2025-09-28.
//

import Foundation

// MARK: - Core Data Models

struct User: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
}

struct Group: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let status: String? 
}

struct Expense: Codable, Identifiable, Equatable {
    let id: Int
    let groupId: Int
    let paidBy: Int
    let amount: Double
    let description: String
    let createdAt: String
}

struct SettlementStatus: Codable {
    let approvedCount: Int
    let totalMembers: Int
    let approvedUsers: [User]
    
    enum CodingKeys: String, CodingKey {
        case approvedCount = "approved_count"
        case totalMembers = "total_members"
        case approvedUsers = "approved_users"
    }
}

// MARK: - API Request/Response Models

struct ExpenseRequest: Codable {
    let groupId: Int
    let paidBy: Int
    let amount: Double
    let description: String
    let participantIds: [Int]
}

struct GroupRequest: Codable {
    let name: String
    let memberIds: [Int]
}

struct BalanceDetail: Codable {
    let counterparty: String
    let amount: Double
}

struct GroupBalance: Codable {
    let net: Double
    let detail: [BalanceDetail]
}

struct BalanceLine: Codable, Identifiable {
    var id: Int { groupId }  // Use groupId as the unique identifier
    let groupId: Int
    let groupName: String
    let counterparty: String
    let amount: Double
}

// MARK: - API Client

final class APIClient {
    private let baseURL = URL(string: "http://127.0.0.1:8000")!
    
    // MARK: - Groups
    
    func getGroups(userId: Int, status: String = "active") async throws -> [Group] {
        let url = URL(string: "\(baseURL)/groups?userId=\(userId)&status=\(status)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Group].self, from: data)
    }
    
    func createGroup(name: String, memberIds: [Int]) async throws -> Group {
        let request = GroupRequest(name: name, memberIds: memberIds)
        return try await post("/groups", body: request)
    }
    
    func getGroupMembers(groupId: Int) async throws -> [User] {
        return try await get("/groups/\(groupId)/members")
    }
    
    func settleGroup(groupId: Int) async throws {
        _ = try await patch("/groups/\(groupId)/settle")
    }

    func requestSettleGroup(groupId: Int, userId: Int) async throws {
        let url = URL(string: "\(baseURL)/groups/\(groupId)/request-settle?userId=\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    func getSettlementStatus(groupId: Int) async throws -> SettlementStatus {
        let url = URL(string: "\(baseURL)/groups/\(groupId)/settlement-status")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SettlementStatus.self, from: data)
    }
    
    // MARK: - Expenses
    
    func getExpenses(groupId: Int) async throws -> [Expense] {
        return try await get("/expenses?groupId=\(groupId)")
    }
    
    func addExpense(groupId: Int, paidBy: Int, amount: Double, description: String, participantIds: [Int]) async throws -> Expense {
        let request = ExpenseRequest(
            groupId: groupId,
            paidBy: paidBy,
            amount: amount,
            description: description,
            participantIds: participantIds
        )
        return try await post("/expenses", body: request)
    }
    
    func deleteExpense(id: Int) async throws {
        _ = try await delete("/expenses/\(id)")
    }
    
    // MARK: - Balances
    
    func getGroupBalance(groupId: Int, userId: Int) async throws -> GroupBalance {
        return try await get("/balances/group/\(groupId)?userId=\(userId)")
    }
    
    func getUserBalance(userId: Int, status: String = "active") async throws -> [BalanceLine] {
        let url = URL(string: "\(baseURL)/balances/user/\(userId)?status=\(status)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([BalanceLine].self, from: data)
    }
    
    // MARK: - Users
    
    func getUsers() async throws -> [User] {
        return try await get("/users")
    }
    
    // MARK: - HTTP Methods
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        // Build URL properly - don't use appendingPathComponent for query strings
        let urlString: String
        if path.hasPrefix("http") {
            urlString = path
        } else if path.contains("?") {
            // Path has query parameters - build directly
            urlString = baseURL.absoluteString + path
        } else {
            // Simple path - use appendingPathComponent
            urlString = baseURL.appendingPathComponent(path).absoluteString
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.networkError
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError
        }
    }
    
    private func post<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T {
        let url = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError
        }
    }
    
    private func patch(_ path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    private func delete(_ path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return data
    }
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case httpError(Int)
    case decodingError
    case encodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .networkError:
            return "Network error occurred"
        }
    }
}
