#!/usr/bin/env python3
"""
API Testing Script for Trip Expense Tracker
Run this after starting your FastAPI server to test all endpoints
"""

import requests
import json
from typing import Dict, Any

BASE_URL = "http://127.0.0.1:8000"

def print_test(name: str, success: bool, data: Any = None):
    """Print test results"""
    status = "✅ PASS" if success else "❌ FAIL"
    print(f"{status} {name}")
    if data and isinstance(data, (dict, list)):
        print(f"    Response: {json.dumps(data, indent=2)[:200]}...")
    elif data:
        print(f"    Response: {data}")
    print()

def test_root():
    """Test root endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/")
        success = response.status_code == 200
        print_test("Root endpoint", success, response.json())
        return success
    except Exception as e:
        print_test("Root endpoint", False, str(e))
        return False

def test_get_users():
    """Test getting all users"""
    try:
        response = requests.get(f"{BASE_URL}/users")
        success = response.status_code == 200 and len(response.json()) >= 3
        print_test("Get users", success, response.json())
        return response.json() if success else []
    except Exception as e:
        print_test("Get users", False, str(e))
        return []

def test_get_groups():
    """Test getting all groups"""
    try:
        response = requests.get(f"{BASE_URL}/groups")
        success = response.status_code == 200 and len(response.json()) >= 2
        print_test("Get groups", success, response.json())
        return response.json() if success else []
    except Exception as e:
        print_test("Get groups", False, str(e))
        return []

def test_get_group_members(group_id: int):
    """Test getting group members"""
    try:
        response = requests.get(f"{BASE_URL}/groups/{group_id}/members")
        success = response.status_code == 200
        print_test(f"Get group {group_id} members", success, response.json())
        return response.json() if success else []
    except Exception as e:
        print_test(f"Get group {group_id} members", False, str(e))
        return []

def test_get_expenses(group_id: int):
    """Test getting expenses for a group"""
    try:
        response = requests.get(f"{BASE_URL}/expenses?groupId={group_id}")
        success = response.status_code == 200
        print_test(f"Get expenses for group {group_id}", success, response.json())
        return response.json() if success else []
    except Exception as e:
        print_test(f"Get expenses for group {group_id}", False, str(e))
        return []

def test_add_expense(group_id: int, paid_by: int, participant_ids: list):
    """Test adding a new expense"""
    try:
        expense_data = {
            "groupId": group_id,
            "paidBy": paid_by,
            "amount": 42.50,
            "description": "Test expense from API script",
            "participantIds": participant_ids
        }
        
        response = requests.post(
            f"{BASE_URL}/expenses",
            json=expense_data,
            headers={"Content-Type": "application/json"}
        )
        
        success = response.status_code == 200
        print_test("Add expense", success, response.json())
        
        if success:
            return response.json()["id"]
        return None
    except Exception as e:
        print_test("Add expense", False, str(e))
        return None

def test_delete_expense(expense_id: int):
    """Test deleting an expense"""
    try:
        response = requests.delete(f"{BASE_URL}/expenses/{expense_id}")
        success = response.status_code == 200
        print_test(f"Delete expense {expense_id}", success, response.json())
        return success
    except Exception as e:
        print_test(f"Delete expense {expense_id}", False, str(e))
        return False

def test_group_balance(group_id: int, user_id: int):
    """Test getting group balance for a user"""
    try:
        response = requests.get(f"{BASE_URL}/balances/group/{group_id}?userId={user_id}")
        success = response.status_code == 200
        print_test(f"Group {group_id} balance for user {user_id}", success, response.json())
        return success
    except Exception as e:
        print_test(f"Group {group_id} balance for user {user_id}", False, str(e))
        return False

def test_user_balance(user_id: int):
    """Test getting overall user balance"""
    try:
        response = requests.get(f"{BASE_URL}/balances/user/{user_id}")
        success = response.status_code == 200
        print_test(f"Overall balance for user {user_id}", success, response.json())
        return success
    except Exception as e:
        print_test(f"Overall balance for user {user_id}", False, str(e))
        return False

def test_create_group():
    """Test creating a new group"""
    try:
        group_data = {
            "name": "Test Group from API",
            "memberIds": [1, 2]  # Andy and Mai
        }
        
        response = requests.post(
            f"{BASE_URL}/groups",
            json=group_data,
            headers={"Content-Type": "application/json"}
        )
        
        success = response.status_code == 200
        print_test("Create group", success, response.json())
        
        if success:
            return response.json()["id"]
        return None
    except Exception as e:
        print_test("Create group", False, str(e))
        return None

def main():
    """Run all API tests"""
    print("🚀 Starting API Tests for Trip Expense Tracker")
    print("=" * 50)
    print()
    
    # Test basic endpoints
    if not test_root():
        print("❌ Server not responding. Make sure to run: python main.py")
        return
    
    users = test_get_users()
    if not users:
        print("❌ No users found. Check database initialization.")
        return
    
    groups = test_get_groups()
    if not groups:
        print("❌ No groups found. Check database initialization.")
        return
    
    # Test with first group
    group_id = groups[0]["id"]
    members = test_get_group_members(group_id)
    
    # Test expenses
    expenses = test_get_expenses(group_id)
    
    # Test adding an expense
    if members and len(members) >= 2:
        participant_ids = [m["id"] for m in members]
        expense_id = test_add_expense(group_id, members[0]["id"], participant_ids)
        
        # Test deleting the expense we just created
        if expense_id:
            test_delete_expense(expense_id)
    
    # Test balances
    user_id = users[0]["id"]  # Andy
    test_group_balance(group_id, user_id)
    test_user_balance(user_id)
    
    # Test creating a new group
    new_group_id = test_create_group()
    if new_group_id:
        test_get_group_members(new_group_id)
    
    print("=" * 50)
    print("🏁 API Tests Complete!")
    print("\nIf you see mostly ✅ PASS results, your backend is working correctly!")
    print("Next step: Build the iOS app to connect to these endpoints.")

if __name__ == "__main__":
    main()