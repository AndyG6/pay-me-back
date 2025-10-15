from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Dict, Optional
import sqlite3
import datetime
import os

app = FastAPI(title="Trip Expense Tracker API")

# Enable CORS for iOS simulator
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database setup
DB_FILE = "expenses.db"

def get_db():
    conn = sqlite3.connect(DB_FILE, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize database with schema"""
    if not os.path.exists(DB_FILE):
        conn = get_db()
        with open("schema.sql", "r") as f:
            conn.executescript(f.read())
        conn.commit()
        conn.close()
        print("Database initialized with sample data!")

# Initialize database on startup
init_db()

# Pydantic models
class User(BaseModel):
    id: int
    name: str

class Group(BaseModel):
    id: int
    name: str
    status: str = "active"

class Expense(BaseModel):
    id: int
    groupId: int = Field(alias="group_id")
    paidBy: int = Field(alias="paid_by")
    amount: float
    description: str
    createdAt: str = Field(alias="created_at")

    class Config:
        validate_by_name = True

class ExpenseRequest(BaseModel):
    groupId: int
    paidBy: int
    amount: float
    description: str
    participantIds: List[int]

class GroupRequest(BaseModel):
    name: str
    memberIds: List[int]

class BalanceDetail(BaseModel):
    counterparty: str
    amount: float

class GroupBalance(BaseModel):
    net: float
    detail: List[BalanceDetail] = []

class BalanceLine(BaseModel):
    groupId: int
    groupName: str
    counterparty: str
    amount: float

# API Endpoints

@app.get("/")
def read_root():
    return {"message": "Trip Expense Tracker API is running!"}

# MARK: - Groups

@app.get("/groups", response_model=List[Group])
def get_groups(userId: int = None, status: str = 'active'):
    """Get groups, filtered by user and status"""
    conn = get_db()
    try:
        if userId:
            rows = conn.execute(
                """SELECT g.id, g.name, g.status FROM groups g
                   JOIN group_members gm ON g.id = gm.group_id 
                   WHERE gm.user_id = ? AND g.status = ?
                   ORDER BY g.name""",
                (userId, status)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT id, name, status FROM groups WHERE status = ? ORDER BY name",  # ← Add status
                (status,)
            ).fetchall()
        
        return [{"id": row["id"], "name": row["name"], "status": row["status"]} for row in rows]  # ← Add status
    finally:
        conn.close()

@app.post("/groups", response_model=Group)
def create_group(body: GroupRequest):
    """Create a new group with members"""
    conn = get_db()
    try:
        cursor = conn.cursor()
        
        # Insert group
        cursor.execute("INSERT INTO groups (name) VALUES (?)", (body.name,))
        group_id = cursor.lastrowid
        
        # Add members
        for member_id in body.memberIds:
            cursor.execute(
                "INSERT INTO group_members (group_id, user_id) VALUES (?, ?)",
                (group_id, member_id)
            )
        
        conn.commit()
        return {"id": group_id, "name": body.name}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@app.get("/groups/{group_id}/members", response_model=List[User])
def get_group_members(group_id: int):
    """Get all members of a group"""
    conn = get_db()
    try:
        rows = conn.execute(
            "SELECT u.id, u.name FROM users u JOIN group_members gm ON u.id = gm.user_id WHERE gm.group_id = ? ORDER BY u.name",
            (group_id,)
        ).fetchall()
        return [{"id": row["id"], "name": row["name"]} for row in rows]
    finally:
        conn.close()

@app.post("/groups/{group_id}/request-settle")
def request_settle(group_id: int, userId: int):
    """Record that a user wants to settle this group"""
    conn = get_db()
    try:
        cursor = conn.cursor()
        
        # Record this user's approval
        cursor.execute(
            "INSERT OR REPLACE INTO settlement_requests (group_id, user_id, requested_at) VALUES (?, ?, ?)",
            (group_id, userId, datetime.datetime.utcnow().isoformat())
        )
        
        # Check if ALL members have approved
        total_members = conn.execute(
            "SELECT COUNT(*) as count FROM group_members WHERE group_id = ?",
            (group_id,)
        ).fetchone()["count"]
        
        approved_members = conn.execute(
            "SELECT COUNT(*) as count FROM settlement_requests WHERE group_id = ?",
            (group_id,)
        ).fetchone()["count"]
        
        # If everyone approved, mark group as settled
        if approved_members == total_members:
            cursor.execute(
                "UPDATE groups SET status = 'settled' WHERE id = ?",
                (group_id,)
            )
            conn.commit()
            return {"message": "Group settled!", "settled": True}
        else:
            conn.commit()
            return {
                "message": f"Approval recorded ({approved_members}/{total_members})",
                "settled": False,
                "approved": approved_members,
                "total": total_members
            }
    finally:
        conn.close()

@app.get("/groups/{group_id}/settlement-status")
def get_settlement_status(group_id: int):
    """Check settlement approval status"""
    conn = get_db()
    try:
        # Get who has approved
        approved = conn.execute(
            "SELECT u.id, u.name FROM users u JOIN settlement_requests sr ON u.id = sr.user_id WHERE sr.group_id = ?",
            (group_id,)
        ).fetchall()
        
        # Get all members
        total_members = conn.execute(
            "SELECT COUNT(*) as count FROM group_members WHERE group_id = ?",
            (group_id,)
        ).fetchone()["count"]
        
        return {
            "approved_count": len(approved),
            "total_members": total_members,
            "approved_users": [{"id": u["id"], "name": u["name"]} for u in approved]
        }
    finally:
        conn.close()

# MARK: - Expenses

@app.get("/expenses", response_model=List[Expense])
def get_expenses(groupId: int):
    """Get all expenses for a group"""
    conn = get_db()
    try:
        rows = conn.execute(
            "SELECT * FROM expenses WHERE group_id = ? ORDER BY created_at DESC",
            (groupId,)
        ).fetchall()
        
        expenses = []
        for row in rows:
            expenses.append({
                "id": row["id"],
                "group_id": row["group_id"],      # ← Changed to snake_case
                "paid_by": row["paid_by"],        # ← Changed to snake_case
                "amount": row["amount"],
                "description": row["description"],
                "created_at": row["created_at"]   # ← Changed to snake_case
            })
        return expenses
    finally:
        conn.close()

@app.post("/expenses", response_model=Expense)
def add_expense(body: ExpenseRequest):
    """Add a new expense"""
    if body.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be greater than 0")
    
    if not body.participantIds:
        raise HTTPException(status_code=400, detail="Must have at least one participant")
    
    conn = get_db()
    try:
        cursor = conn.cursor()
        created_at = datetime.datetime.utcnow().isoformat() + "Z"
        
        # Verify paidBy is in participantIds
        if body.paidBy not in body.participantIds:
            raise HTTPException(status_code=400, detail="Payer must be a participant")
        
        # Insert expense
        cursor.execute(
            "INSERT INTO expenses (group_id, paid_by, amount, description, created_at) VALUES (?, ?, ?, ?, ?)",
            (body.groupId, body.paidBy, body.amount, body.description, created_at)
        )
        expense_id = cursor.lastrowid
        
        # Add participants
        for participant_id in body.participantIds:
            cursor.execute(
                "INSERT INTO expense_participants (expense_id, user_id) VALUES (?, ?)",
                (expense_id, participant_id)
            )
        
        conn.commit()
        return {
            "id": expense_id,
            "group_id": body.groupId,      # ← Changed to snake_case
            "paid_by": body.paidBy,        # ← Changed to snake_case
            "amount": body.amount,
            "description": body.description,
            "created_at": created_at       # ← Changed to snake_case
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@app.delete("/expenses/{expense_id}")
def delete_expense(expense_id: int):
    """Delete an expense"""
    conn = get_db()
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM expenses WHERE id = ?", (expense_id,))
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Expense not found")
        
        conn.commit()
        return {"message": "Expense deleted successfully"}
    finally:
        conn.close()

# MARK: - Balances

@app.get("/balances/group/{group_id}", response_model=GroupBalance)
def get_group_balance(group_id: int, userId: int):
    """Get balance for a user within a specific group"""
    conn = get_db()
    try:
        # Calculate net balances for all users in the group
        net_balances = {}
        user_names = {}
        
        # Get user names in this group
        users = conn.execute(
            "SELECT u.id, u.name FROM users u JOIN group_members gm ON u.id = gm.user_id WHERE gm.group_id = ?",
            (group_id,)
        ).fetchall()
        
        for user in users:
            user_names[user["id"]] = user["name"]
            net_balances[user["id"]] = 0.0
        
        # Get all expenses in the group
        expenses = conn.execute(
            "SELECT id, paid_by, amount FROM expenses WHERE group_id = ?",
            (group_id,)
        ).fetchall()
        
        for expense in expenses:
            # Get participants for this expense
            participants = conn.execute(
                "SELECT user_id FROM expense_participants WHERE expense_id = ?",
                (expense["id"],)
            ).fetchall()
            
            participant_ids = [p["user_id"] for p in participants]
            
            if len(participant_ids) == 0:
                continue
                
            share = expense["amount"] / len(participant_ids)
            
            # Payer gets credit for what they paid minus their share
            net_balances[expense["paid_by"]] += (expense["amount"] - share)
            
            # Each participant owes their share (except the payer)
            for participant_id in participant_ids:
                if participant_id != expense["paid_by"]:
                    net_balances[participant_id] -= share
        
        # Get the requested user's net balance
        user_net = net_balances.get(userId, 0.0)
        
        # Build detail showing what this user owes/is owed by others
        detail = []
        for other_id, other_name in user_names.items():
            if other_id != userId:
                other_net = net_balances.get(other_id, 0.0)
                
                # Calculate pairwise debt between user and other
                if user_net < 0 and other_net > 0:
                    # User owes money, other is owed money
                    amount_owed = min(abs(user_net), other_net)
                    if amount_owed > 0.01:
                        detail.append(BalanceDetail(counterparty=other_name, amount=-amount_owed))
                elif user_net > 0 and other_net < 0:
                    # User is owed money, other owes money
                    amount_owed = min(user_net, abs(other_net))
                    if amount_owed > 0.01:
                        detail.append(BalanceDetail(counterparty=other_name, amount=amount_owed))
        
        return GroupBalance(net=round(user_net, 2), detail=detail)
        
    finally:
        conn.close()

@app.get("/balances/user/{user_id}", response_model=List[BalanceLine])
def get_user_balance(user_id: int, status: str = 'active'):  # ← Add status parameter
    """Get overall balance for a user across all groups"""
    conn = get_db()
    try:
        # Get groups filtered by status
        groups = conn.execute(
            """SELECT g.id, g.name FROM groups g 
               JOIN group_members gm ON g.id = gm.group_id 
               WHERE gm.user_id = ? AND g.status = ?""",  # ← Add status filter
            (user_id, status)
        ).fetchall()
        
        balance_lines = []
        
        for group in groups:
            group_id = group["id"]
            group_name = group["name"]
            
            # Get group balance for this user
            group_balance = get_group_balance(group_id, user_id)
            
            # Create summary line for this group
            if abs(group_balance.net) > 0.01:
                balance_lines.append(BalanceLine(
                    groupId=group_id,
                    groupName=group_name,
                    counterparty="Group Total",
                    amount=group_balance.net
                ))
        
        return balance_lines
        
    finally:
        conn.close()

# MARK: - Users (for testing/development)

@app.get("/users", response_model=List[User])
def get_users():
    """Get all users"""
    conn = get_db()
    try:
        rows = conn.execute("SELECT * FROM users ORDER BY name").fetchall()
        return [{"id": row["id"], "name": row["name"]} for row in rows]
    finally:
        conn.close()

@app.post("/users", response_model=User)
def create_user(name: str):
    """Create a new user (for testing)"""
    conn = get_db()
    try:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO users (name) VALUES (?)", (name,))
        user_id = cursor.lastrowid
        conn.commit()
        return {"id": user_id, "name": name}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)