CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS groups (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS group_members (
    group_id INTEGER,
    user_id INTEGER,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS expenses (
    id INTEGER PRIMARY KEY,
    group_id INTEGER,
    paid_by INTEGER,
    amount REAL NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
    FOREIGN KEY (paid_by) REFERENCES users (id)
);

CREATE TABLE IF NOT EXISTS expense_participants (
    expense_id INTEGER,
    user_id INTEGER,
    PRIMARY KEY (expense_id, user_id),
    FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS settlement_requests (
    group_id INTEGER,
    user_id INTEGER,
    requested_at TEXT,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT OR IGNORE INTO users (id, name) VALUES 
(1, 'Andy'),
(2, 'Trinetti'),
(3, 'Sam');

INSERT OR IGNORE INTO groups (id, name) VALUES 
(1, 'Whistler Ski Trip'),
(2, 'Beach House Weekend');

INSERT OR IGNORE INTO group_members (group_id, user_id) VALUES 
(1, 1), (1, 2), (1, 3),
(2, 1), (2, 2);

INSERT OR IGNORE INTO expenses (id, group_id, paid_by, amount, description, created_at) VALUES 
(1, 1, 1, 120.0, 'Groceries for the trip', '2025-09-25T10:00:00Z'),
(2, 1, 2, 45.0, 'Gas for the drive', '2025-09-25T14:30:00Z'),
(3, 2, 1, 80.0, 'Dinner at the beach', '2025-09-26T19:00:00Z');

INSERT OR IGNORE INTO expense_participants (expense_id, user_id) VALUES 
(1, 1), (1, 2), (1, 3),
(2, 1), (2, 2), (2, 3), 
(3, 1), (3, 2);        