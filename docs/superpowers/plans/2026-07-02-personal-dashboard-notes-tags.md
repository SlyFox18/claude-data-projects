# Personal Dashboard — Notes, Due Date, Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real Notes field, an optional Due Date, a growable multi-select Tags system, and visible relative timestamps to every item in the personal-dashboard app.

**Architecture:** Additive changes to the existing Flask + SQLite app at `C:/Users/bfox/Documents/Git-Projects/personal-dashboard`. `items` gains a `due_date` column (via an idempotent migration in `init_db()`, since `dashboard.db` already has real data); two new tables (`tags`, `item_tags`) back a many-to-many tag system. All changes are additive — no existing column, function signature, or route is removed, only extended.

**Tech Stack:** Flask 3.0.3, SQLite (stdlib `sqlite3`), pytest 8.2.0, vanilla JS, Jinja2 templates. Same as the existing v2 build — see `docs/superpowers/plans/2026-07-02-personal-dashboard.md` for original conventions this plan follows exactly (`db_path` as required first positional arg with no defaults, `create_app(db_path=None)` factory, `tmp_path` pytest fixture).

---

### Task 1: Database migration — due_date column, tags/item_tags tables, starter tag seed

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/db.py:14-33` (the `init_db` function)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_db.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_db.py`:

```python
def test_init_db_adds_due_date_column_to_existing_table(tmp_path):
    db_path = tmp_path / "test.db"
    conn = sqlite3.connect(db_path)
    conn.execute(
        """
        CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            who TEXT,
            notes TEXT,
            type TEXT NOT NULL DEFAULT 'inbox',
            priority TEXT,
            status TEXT NOT NULL DEFAULT 'open',
            captured_at TEXT NOT NULL,
            triaged_at TEXT,
            completed_at TEXT
        )
        """
    )
    conn.commit()
    conn.close()
    db.init_db(db_path)
    conn = sqlite3.connect(db_path)
    columns = [row[1] for row in conn.execute("PRAGMA table_info(items)")]
    conn.close()
    assert "due_date" in columns


def test_init_db_is_safe_to_call_twice_on_existing_due_date_column(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    db.init_db(db_path)
    conn = sqlite3.connect(db_path)
    columns = [row[1] for row in conn.execute("PRAGMA table_info(items)")]
    conn.close()
    assert columns.count("due_date") == 1


def test_init_db_seeds_starter_tags_once(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    conn = sqlite3.connect(db_path)
    rows = conn.execute("SELECT name, color FROM tags ORDER BY id").fetchall()
    conn.close()
    names = [r[0] for r in rows]
    assert names == [
        "Not Started",
        "In Progress",
        "Blocked",
        "Waiting on Info",
        "On Hold",
        "Needs Follow-up",
    ]
    blocked_color = [r[1] for r in rows if r[0] == "Blocked"][0]
    assert blocked_color == "red"
    db.init_db(db_path)
    conn = sqlite3.connect(db_path)
    count = conn.execute("SELECT COUNT(*) FROM tags").fetchone()[0]
    conn.close()
    assert count == 6


def test_init_db_creates_item_tags_table(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    conn = sqlite3.connect(db_path)
    tables = [row[0] for row in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    )]
    conn.close()
    assert "item_tags" in tables
    assert "tags" in tables
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_db.py -v -k "due_date or starter_tags or item_tags_table"`
Expected: FAIL — `due_date` column doesn't exist, `tags`/`item_tags` tables don't exist.

- [ ] **Step 3: Rewrite `init_db` in `db.py`**

Replace the existing `init_db` function (lines 14-33) with:

```python
def init_db(db_path):
    conn = get_connection(db_path)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            who TEXT,
            notes TEXT,
            type TEXT NOT NULL DEFAULT 'inbox',
            priority TEXT,
            status TEXT NOT NULL DEFAULT 'open',
            captured_at TEXT NOT NULL,
            triaged_at TEXT,
            completed_at TEXT
        )
        """
    )
    existing_columns = [row["name"] for row in conn.execute("PRAGMA table_info(items)")]
    if "due_date" not in existing_columns:
        conn.execute("ALTER TABLE items ADD COLUMN due_date TEXT")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            color TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS item_tags (
            item_id INTEGER NOT NULL REFERENCES items(id),
            tag_id INTEGER NOT NULL REFERENCES tags(id),
            PRIMARY KEY (item_id, tag_id)
        )
        """
    )
    tag_count = conn.execute("SELECT COUNT(*) AS n FROM tags").fetchone()["n"]
    if tag_count == 0:
        starter_tags = [
            ("Not Started", "gray"),
            ("In Progress", "blue"),
            ("Blocked", "red"),
            ("Waiting on Info", "amber"),
            ("On Hold", "purple"),
            ("Needs Follow-up", "cyan"),
        ]
        conn.executemany("INSERT INTO tags (name, color) VALUES (?, ?)", starter_tags)
    conn.commit()
    conn.close()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_db.py -v`
Expected: all tests PASS (existing 6 + new 4 = 10)

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add db.py tests/test_db.py
git commit -m "Add due_date column and tags/item_tags tables via idempotent migration"
```

---

### Task 2: Tag CRUD functions, get_items tag integration, due_date/notes support

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/db.py`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_db.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_db.py`:

```python
def test_create_tag_inserts_new_tag(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    tag_id = db.create_tag(db_path, "Urgent")
    tags = db.get_tags(db_path)
    assert any(t["id"] == tag_id and t["name"] == "Urgent" for t in tags)


def test_create_tag_dedupes_case_insensitively(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    first_id = db.create_tag(db_path, "Custom")
    second_id = db.create_tag(db_path, "custom")
    assert first_id == second_id
    tags = db.get_tags(db_path)
    matches = [t for t in tags if t["name"].lower() == "custom"]
    assert len(matches) == 1


def test_create_tag_assigns_color_round_robin(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    tag_id = db.create_tag(db_path, "Seventh Tag")
    tags = db.get_tags(db_path)
    seventh = [t for t in tags if t["id"] == tag_id][0]
    assert seventh["color"] == "gray"


def test_get_items_includes_tags(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer")
    tag_id = db.create_tag(db_path, "Blocked")
    db.add_tag_to_item(db_path, item_id, tag_id)
    items = db.get_items(db_path, status="open")
    assert len(items[0]["tags"]) == 1
    assert items[0]["tags"][0]["name"] == "Blocked"
    assert items[0]["tags"][0]["color"] == "red"


def test_get_items_returns_empty_tags_list_when_none_applied(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    db.insert_item(db_path, "No tags here")
    items = db.get_items(db_path, status="open")
    assert items[0]["tags"] == []


def test_remove_tag_from_item(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer")
    tag_id = db.create_tag(db_path, "Blocked")
    db.add_tag_to_item(db_path, item_id, tag_id)
    db.remove_tag_from_item(db_path, item_id, tag_id)
    items = db.get_items(db_path, status="open")
    assert items[0]["tags"] == []


def test_add_tag_to_item_is_idempotent(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer")
    tag_id = db.create_tag(db_path, "Blocked")
    db.add_tag_to_item(db_path, item_id, tag_id)
    db.add_tag_to_item(db_path, item_id, tag_id)
    items = db.get_items(db_path, status="open")
    assert len(items[0]["tags"]) == 1


def test_insert_item_accepts_due_date(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    db.insert_item(db_path, "Renew license", due_date="2026-07-10")
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] == "2026-07-10"


def test_update_item_sets_notes(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer")
    updated = db.update_item(db_path, item_id, notes="John needs this by Friday")
    assert updated is True
    items = db.get_items(db_path, status="open")
    assert items[0]["notes"] == "John needs this by Friday"


def test_update_item_sets_due_date(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer")
    db.update_item(db_path, item_id, due_date="2026-07-15")
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] == "2026-07-15"


def test_update_item_clears_due_date_with_none(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer", due_date="2026-07-15")
    db.update_item(db_path, item_id, due_date=None)
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] is None


def test_update_item_with_no_fields_returns_false(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Fix slicer")
    updated = db.update_item(db_path, item_id)
    assert updated is False


def test_update_item_nonexistent_returns_false(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    updated = db.update_item(db_path, 99999, notes="ghost")
    assert updated is False
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_db.py -v`
Expected: the 12 new tests FAIL with `AttributeError: module 'db' has no attribute 'create_tag'` (and similar for the others).

- [ ] **Step 3: Add the tag-color constant and tag functions to `db.py`**

Add near the top of `db.py`, after `DEFAULT_DB_PATH`:

```python
TAG_COLORS = ["gray", "blue", "red", "amber", "purple", "cyan"]
```

Add these functions to `db.py` (after `get_stale_high_tasks`, at the end of the file):

```python
def create_tag(db_path, name):
    conn = get_connection(db_path)
    existing = conn.execute(
        "SELECT id FROM tags WHERE name = ? COLLATE NOCASE", (name,)
    ).fetchone()
    if existing:
        conn.close()
        return existing["id"]
    tag_count = conn.execute("SELECT COUNT(*) AS n FROM tags").fetchone()["n"]
    color = TAG_COLORS[tag_count % len(TAG_COLORS)]
    cursor = conn.execute(
        "INSERT INTO tags (name, color) VALUES (?, ?)", (name, color)
    )
    conn.commit()
    tag_id = cursor.lastrowid
    conn.close()
    return tag_id


def get_tags(db_path):
    conn = get_connection(db_path)
    rows = conn.execute("SELECT * FROM tags ORDER BY name").fetchall()
    conn.close()
    return [dict(row) for row in rows]


def add_tag_to_item(db_path, item_id, tag_id):
    conn = get_connection(db_path)
    conn.execute(
        "INSERT OR IGNORE INTO item_tags (item_id, tag_id) VALUES (?, ?)",
        (item_id, tag_id),
    )
    conn.commit()
    conn.close()


def remove_tag_from_item(db_path, item_id, tag_id):
    conn = get_connection(db_path)
    conn.execute(
        "DELETE FROM item_tags WHERE item_id = ? AND tag_id = ?", (item_id, tag_id)
    )
    conn.commit()
    conn.close()
```

- [ ] **Step 4: Update `get_items` to attach tags to each item**

Replace the existing `get_items` function with:

```python
def get_items(db_path, status="open"):
    conn = get_connection(db_path)
    rows = conn.execute(
        "SELECT * FROM items WHERE status = ? ORDER BY captured_at DESC", (status,)
    ).fetchall()
    items = [dict(row) for row in rows]
    for item in items:
        tag_rows = conn.execute(
            """
            SELECT tags.id, tags.name, tags.color FROM tags
            JOIN item_tags ON item_tags.tag_id = tags.id
            WHERE item_tags.item_id = ?
            ORDER BY tags.name
            """,
            (item["id"],),
        ).fetchall()
        item["tags"] = [dict(row) for row in tag_rows]
    conn.close()
    return items
```

- [ ] **Step 5: Update `insert_item` to accept `due_date`**

Replace the existing `insert_item` function with:

```python
def insert_item(db_path, text, who=None, notes=None, due_date=None):
    conn = get_connection(db_path)
    now = datetime.now().isoformat()
    cursor = conn.execute(
        "INSERT INTO items (text, who, notes, due_date, type, status, captured_at) "
        "VALUES (?, ?, ?, ?, 'inbox', 'open', ?)",
        (text, who, notes, due_date, now),
    )
    conn.commit()
    item_id = cursor.lastrowid
    conn.close()
    return item_id
```

- [ ] **Step 6: Add `update_item` for editing notes/due_date after capture**

Add near the top of `db.py`, after `TAG_COLORS`:

```python
_UNSET = object()
```

Add this function to `db.py` (after `insert_item`):

```python
def update_item(db_path, item_id, notes=_UNSET, due_date=_UNSET):
    conn = get_connection(db_path)
    fields = []
    values = []
    if notes is not _UNSET:
        fields.append("notes = ?")
        values.append(notes)
    if due_date is not _UNSET:
        fields.append("due_date = ?")
        values.append(due_date)
    if not fields:
        conn.close()
        return False
    values.append(item_id)
    cursor = conn.execute(f"UPDATE items SET {', '.join(fields)} WHERE id = ?", values)
    conn.commit()
    updated = cursor.rowcount > 0
    conn.close()
    return updated
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_db.py -v`
Expected: all tests PASS (10 from Task 1 + 12 new = 22)

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add db.py tests/test_db.py
git commit -m "Add tag CRUD, get_items tag integration, and notes/due_date editing"
```

---

### Task 3: Relative timestamp helper

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/timeutil.py`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py:1-15`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_timeutil.py`

- [ ] **Step 1: Write the failing test**

Create `tests/test_timeutil.py`:

```python
# tests/test_timeutil.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from datetime import datetime, timedelta
import timeutil


def test_relative_time_just_now():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(seconds=30)).isoformat()
    assert timeutil.relative_time(then, now=now) == "just now"


def test_relative_time_singular_minute():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(minutes=1)).isoformat()
    assert timeutil.relative_time(then, now=now) == "1 minute ago"


def test_relative_time_minutes_ago():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(minutes=5)).isoformat()
    assert timeutil.relative_time(then, now=now) == "5 minutes ago"


def test_relative_time_singular_hour():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(hours=1)).isoformat()
    assert timeutil.relative_time(then, now=now) == "1 hour ago"


def test_relative_time_hours_ago():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(hours=3)).isoformat()
    assert timeutil.relative_time(then, now=now) == "3 hours ago"


def test_relative_time_singular_day():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(days=1)).isoformat()
    assert timeutil.relative_time(then, now=now) == "1 day ago"


def test_relative_time_days_ago():
    now = datetime(2026, 7, 2, 12, 0, 0)
    then = (now - timedelta(days=2)).isoformat()
    assert timeutil.relative_time(then, now=now) == "2 days ago"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_timeutil.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'timeutil'`

- [ ] **Step 3: Create `timeutil.py`**

```python
# timeutil.py
from datetime import datetime


def relative_time(iso_string, now=None):
    if now is None:
        now = datetime.now()
    then = datetime.fromisoformat(iso_string)
    seconds = (now - then).total_seconds()
    if seconds < 60:
        return "just now"
    minutes = int(seconds // 60)
    if minutes < 60:
        return f"{minutes} minute{'s' if minutes != 1 else ''} ago"
    hours = int(seconds // 3600)
    if hours < 24:
        return f"{hours} hour{'s' if hours != 1 else ''} ago"
    days = int(seconds // 86400)
    return f"{days} day{'s' if days != 1 else ''} ago"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_timeutil.py -v`
Expected: all 7 tests PASS

- [ ] **Step 5: Register `relative_time` as a Jinja filter**

In `app.py`, add `import timeutil` after `import notify` (line 6), and inside `create_app`, immediately after `app.config["DB_PATH"] = db_path` (line 14), add:

```python
    app.jinja_env.filters["relative_time"] = timeutil.relative_time
```

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add timeutil.py tests/test_timeutil.py app.py
git commit -m "Add relative_time helper and register as Jinja filter"
```

---

### Task 4: Extend POST /capture to accept due_date

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py:17-32` (the `capture` route)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_capture.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_capture.py`:

```python
def test_capture_accepts_due_date(client, monkeypatch):
    monkeypatch.setattr(notify, "send_toast", lambda *a, **kw: None)
    test_client, db_path = client
    response = test_client.post(
        "/capture", json={"text": "Renew license", "due_date": "2026-07-10"}
    )
    assert response.status_code == 201
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] == "2026-07-10"


def test_capture_drops_empty_due_date(client, monkeypatch):
    monkeypatch.setattr(notify, "send_toast", lambda *a, **kw: None)
    test_client, db_path = client
    response = test_client.post("/capture", json={"text": "Some item", "due_date": ""})
    assert response.status_code == 201
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] is None


def test_capture_accepts_notes(client, monkeypatch):
    monkeypatch.setattr(notify, "send_toast", lambda *a, **kw: None)
    test_client, db_path = client
    response = test_client.post(
        "/capture", json={"text": "Fix slicer", "notes": "Parts Summary tab"}
    )
    assert response.status_code == 201
    items = db.get_items(db_path, status="open")
    assert items[0]["notes"] == "Parts Summary tab"
```

`test_capture_accepts_notes` should already pass — `notes` was already wired into the endpoint, just never sent by any client. It's here to lock in that behavior now that it's user-facing.

- [ ] **Step 2: Run tests to verify due_date tests fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_capture.py -v`
Expected: `test_capture_accepts_due_date` and `test_capture_drops_empty_due_date` FAIL (due_date always `None` since it's not read from the request yet); `test_capture_accepts_notes` PASSES already.

- [ ] **Step 3: Update the `capture` route in `app.py`**

Replace lines 26-30 (the `who`/`notes` handling through `insert_item` call) with:

```python
        who = data.get("who")
        notes = data.get("notes")
        due_date = data.get("due_date")
        who = who if isinstance(who, str) else None
        notes = notes if isinstance(notes, str) else None
        due_date = due_date if isinstance(due_date, str) and due_date.strip() else None
        item_id = db.insert_item(
            app.config["DB_PATH"], text, who=who, notes=notes, due_date=due_date
        )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_capture.py -v`
Expected: all tests PASS (6 existing + 3 new = 9)

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add app.py tests/test_capture.py
git commit -m "Accept due_date on POST /capture"
```

---

### Task 5: Extend PATCH /items/<id> to accept notes/due_date updates

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py:34-51` (the `update_item` route)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_triage.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_triage.py`:

```python
def test_patch_sets_notes(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    response = test_client.patch(f"/items/{item_id}", json={"notes": "Parts Summary tab"})
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["notes"] == "Parts Summary tab"


def test_patch_sets_due_date(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    response = test_client.patch(f"/items/{item_id}", json={"due_date": "2026-07-10"})
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] == "2026-07-10"


def test_patch_clears_due_date(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer", due_date="2026-07-10")
    response = test_client.patch(f"/items/{item_id}", json={"due_date": None})
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["due_date"] is None


def test_patch_notes_and_due_date_together(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    response = test_client.patch(
        f"/items/{item_id}", json={"notes": "Ask John", "due_date": "2026-07-10"}
    )
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["notes"] == "Ask John"
    assert items[0]["due_date"] == "2026-07-10"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_triage.py -v`
Expected: the 4 new tests FAIL with 400 status (route currently returns `{"error": "no valid update fields"}` for bodies without `status` or `type`).

- [ ] **Step 3: Update the `update_item` route in `app.py`**

Replace the route's body (lines 36-51) with:

```python
        data = request.get_json(force=True, silent=True) or {}
        if not isinstance(data, dict):
            return jsonify({"error": "invalid JSON body"}), 400
        db_path = app.config["DB_PATH"]
        try:
            if data.get("status") == "completed":
                updated = db.complete_item(db_path, item_id)
            elif "type" in data:
                updated = db.triage_item(db_path, item_id, data["type"], priority=data.get("priority"))
            elif "notes" in data or "due_date" in data:
                kwargs = {}
                if "notes" in data:
                    kwargs["notes"] = data["notes"]
                if "due_date" in data:
                    kwargs["due_date"] = data["due_date"]
                updated = db.update_item(db_path, item_id, **kwargs)
            else:
                return jsonify({"error": "no valid update fields"}), 400
        except ValueError as e:
            return jsonify({"error": str(e)}), 400
        if not updated:
            return jsonify({"error": "item not found"}), 404
        return jsonify({"ok": True})
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_triage.py -v`
Expected: all tests PASS (7 existing + 4 new = 11)

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add app.py tests/test_triage.py
git commit -m "Accept notes/due_date updates on PATCH /items/<id>"
```

---

### Task 6: Tag API routes

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py` (add routes inside `create_app`, after the `update_item` route)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_tags.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_tags.py`:

```python
# tests/test_tags.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from app import create_app
import db


@pytest.fixture
def client(tmp_path):
    db_path = tmp_path / "test.db"
    app = create_app(db_path=db_path)
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client, db_path


def test_list_tags_returns_starter_set(client):
    test_client, db_path = client
    response = test_client.get("/tags")
    assert response.status_code == 200
    names = [t["name"] for t in response.get_json()]
    assert "Blocked" in names
    assert len(names) == 6


def test_create_tag_adds_new_tag(client):
    test_client, db_path = client
    response = test_client.post("/tags", json={"name": "Urgent"})
    assert response.status_code == 201
    tag_id = response.get_json()["id"]
    tags = db.get_tags(db_path)
    assert any(t["id"] == tag_id and t["name"] == "Urgent" for t in tags)


def test_create_tag_requires_name(client):
    test_client, db_path = client
    response = test_client.post("/tags", json={})
    assert response.status_code == 400


def test_create_tag_dedupes_existing(client):
    test_client, db_path = client
    first = test_client.post("/tags", json={"name": "Blocked"})
    second = test_client.post("/tags", json={"name": "blocked"})
    assert first.get_json()["id"] == second.get_json()["id"]


def test_attach_tag_to_item(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    tag_id = db.create_tag(db_path, "Blocked")
    response = test_client.post(f"/items/{item_id}/tags", json={"tag_id": tag_id})
    assert response.status_code == 201
    items = db.get_items(db_path, status="open")
    assert items[0]["tags"][0]["name"] == "Blocked"


def test_attach_tag_requires_tag_id(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    response = test_client.post(f"/items/{item_id}/tags", json={})
    assert response.status_code == 400


def test_detach_tag_from_item(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    tag_id = db.create_tag(db_path, "Blocked")
    db.add_tag_to_item(db_path, item_id, tag_id)
    response = test_client.delete(f"/items/{item_id}/tags/{tag_id}")
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["tags"] == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_tags.py -v`
Expected: all tests FAIL with 404 (routes don't exist yet).

- [ ] **Step 3: Add tag routes to `app.py`**

Inside `create_app`, immediately after the `update_item` route function (after the line `return jsonify({"ok": True})` that closes it, before the `quick_add_form` route), add:

```python
    @app.route("/tags", methods=["GET"])
    def tags_list():
        return jsonify(db.get_tags(app.config["DB_PATH"]))

    @app.route("/tags", methods=["POST"])
    def tags_create():
        data = request.get_json(force=True, silent=True) or {}
        name = data.get("name")
        if not isinstance(name, str) or not name.strip():
            return jsonify({"error": "name is required"}), 400
        tag_id = db.create_tag(app.config["DB_PATH"], name.strip())
        return jsonify({"id": tag_id}), 201

    @app.route("/items/<int:item_id>/tags", methods=["POST"])
    def item_tags_attach(item_id):
        data = request.get_json(force=True, silent=True) or {}
        tag_id = data.get("tag_id")
        if not isinstance(tag_id, int):
            return jsonify({"error": "tag_id is required"}), 400
        db.add_tag_to_item(app.config["DB_PATH"], item_id, tag_id)
        return jsonify({"ok": True}), 201

    @app.route("/items/<int:item_id>/tags/<int:tag_id>", methods=["DELETE"])
    def item_tags_detach(item_id, tag_id):
        db.remove_tag_from_item(app.config["DB_PATH"], item_id, tag_id)
        return jsonify({"ok": True})
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_tags.py -v`
Expected: all 7 tests PASS

- [ ] **Step 5: Run the full suite to check for regressions**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest -v`
Expected: all tests PASS

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add app.py tests/test_tags.py
git commit -m "Add tag list/create/attach/detach API routes"
```

---

### Task 7: Quick-add form — Notes and Due Date fields, new placeholder text

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/quick-add.html`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/quick-add.js`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/style.css`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_quick_add.py`

- [ ] **Step 1: Write the failing test**

Create `tests/test_quick_add.py`:

```python
# tests/test_quick_add.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from app import create_app


@pytest.fixture
def client(tmp_path):
    db_path = tmp_path / "test.db"
    app = create_app(db_path=db_path)
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client


def test_quick_add_form_has_notes_and_due_date_fields(client):
    response = client.get("/quick-add")
    assert response.status_code == 200
    body = response.data.decode("utf-8")
    assert 'id="capture-notes"' in body
    assert 'id="capture-due-date"' in body
    assert "New Item" in body
    assert "Who's it for (optional)" in body
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_quick_add.py -v`
Expected: FAIL — `capture-notes`/`capture-due-date` not present, old placeholder text still in the template.

- [ ] **Step 3: Update `templates/quick-add.html`**

Replace the full file content with:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Quick Add</title>
<link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
<div class="dashboard quick-add-form">
  <div class="header">
    <span class="header-title">&#10133; Quick Add</span>
    <a href="/" class="header-link">&larr; Dashboard</a>
  </div>
  <div class="section">
    <input type="text" id="capture-text" placeholder="New Item" autofocus>
    <input type="text" id="capture-who" placeholder="Who's it for (optional)">
    <textarea id="capture-notes" placeholder="Notes (optional)"></textarea>
    <input type="date" id="capture-due-date">
    <button id="capture-submit">Add to Inbox</button>
    <div id="capture-status"></div>
  </div>
</div>
<script src="{{ url_for('static', filename='quick-add.js') }}"></script>
</body>
</html>
```

- [ ] **Step 4: Update `static/quick-add.js`**

Replace the full file content with:

```javascript
document.getElementById("capture-submit").addEventListener("click", function () {
  var text = document.getElementById("capture-text").value.trim();
  var who = document.getElementById("capture-who").value.trim();
  var notes = document.getElementById("capture-notes").value.trim();
  var dueDate = document.getElementById("capture-due-date").value;
  var status = document.getElementById("capture-status");
  var submitBtn = document.getElementById("capture-submit");
  if (!text) {
    status.textContent = "Type something first.";
    return;
  }
  submitBtn.disabled = true;
  fetch("/capture", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      text: text,
      who: who || null,
      notes: notes || null,
      due_date: dueDate || null
    })
  }).then(function (response) {
    if (response.ok) {
      status.textContent = "Captured ✓";
      document.getElementById("capture-text").value = "";
      document.getElementById("capture-who").value = "";
      document.getElementById("capture-notes").value = "";
      document.getElementById("capture-due-date").value = "";
      document.getElementById("capture-text").focus();
    } else {
      status.textContent = "Something went wrong.";
    }
  }).catch(function () {
    status.textContent = "Couldn't reach the server.";
  }).finally(function () {
    submitBtn.disabled = false;
  });
});

document.getElementById("capture-text").addEventListener("keydown", function (e) {
  if (e.key === "Enter") {
    document.getElementById("capture-submit").click();
  }
});
```

- [ ] **Step 5: Update `static/style.css` for the textarea and date input**

Replace this line:

```css
.quick-add-form .section input { display: block; width: 100%; background: #182543; border: 1px solid #3a4870; border-radius: 6px; padding: 11px 14px; font-size: .92rem; color: #f1f5f9; margin-bottom: 10px; }
```

with:

```css
.quick-add-form .section input, .quick-add-form .section textarea { display: block; width: 100%; background: #182543; border: 1px solid #3a4870; border-radius: 6px; padding: 11px 14px; font-size: .92rem; color: #f1f5f9; margin-bottom: 10px; font-family: inherit; }
.quick-add-form .section textarea { min-height: 70px; resize: vertical; }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_quick_add.py -v`
Expected: PASS

- [ ] **Step 7: Manual verification**

1. Start the server: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python app.py`
2. Open `http://localhost:5151/quick-add`
3. Fill in all four fields (item text, who, notes, due date) and click "Add to Inbox"
4. Confirm the status line shows "Captured ✓" and all fields clear
5. Verify the captured row via: `python -c "import sqlite3; c = sqlite3.connect('dashboard.db'); print(c.execute('SELECT text, who, notes, due_date FROM items ORDER BY id DESC LIMIT 1').fetchone())"`
   Expected: the row shows the text, who, notes, and due date you entered

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add templates/quick-add.html static/quick-add.js static/style.css tests/test_quick_add.py
git commit -m "Add Notes and Due Date fields to quick-add form, reword placeholders"
```

---

### Task 8: Dashboard template — two-line item rows with timestamps, tags, due date

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/dashboard.html`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/dashboard.js:26` (one selector change)
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/style.css`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py` (dashboard route)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_dashboard.py`

This task covers read-only display of tags/due-date/timestamp. Editing them inline is Tasks 9-11.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_dashboard.py`:

```python
def test_dashboard_shows_relative_timestamp(client):
    test_client, db_path = client
    db.insert_item(db_path, "Something new")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "just now" in body


def test_dashboard_shows_tag_badges(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    db.triage_item(db_path, item_id, "task", priority="high")
    tag_id = db.create_tag(db_path, "Blocked")
    db.add_tag_to_item(db_path, item_id, tag_id)
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "BLOCKED" in body
    assert "tag-red" in body


def test_dashboard_shows_due_date_badge(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Renew license")
    db.triage_item(db_path, item_id, "task", priority="low")
    db.update_item(db_path, item_id, due_date="2026-07-10")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "Due 2026-07-10" in body


def test_dashboard_inbox_item_shows_tags_and_due_date(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Untriaged with tag")
    tag_id = db.create_tag(db_path, "Waiting on Info")
    db.add_tag_to_item(db_path, item_id, tag_id)
    db.update_item(db_path, item_id, due_date="2026-08-01")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "WAITING ON INFO" in body
    assert "Due 2026-08-01" in body
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v`
Expected: the 4 new tests FAIL — current template doesn't render timestamps, tags, or due dates.

- [ ] **Step 3: Pass `all_tags` into the dashboard template context**

In `app.py`, in the `dashboard()` route, after the line `completed = db.get_items(db_path, status="completed")`, add:

```python
        all_tags = db.get_tags(db_path)
```

And add `all_tags=all_tags,` to the `render_template(...)` call's keyword arguments (after `completed=completed,`).

- [ ] **Step 4: Rewrite `templates/dashboard.html`**

Replace the full file content with:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Brian's Dashboard</title>
<link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
{% macro item_meta(item, all_tags) %}
<div class="row-line2">
  {% for tag in item.tags %}
  <span class="tag-badge tag-{{ tag.color }}">{{ tag.name|upper }}</span>
  {% endfor %}
  <span class="due-date-badge {{ 'has-date' if item.due_date else 'no-date' }}" data-id="{{ item.id }}">
    {% if item.due_date %}&#128197; Due {{ item.due_date }}{% else %}+ Due date{% endif %}
  </span>
  <span class="item-context" data-id="{{ item.id }}">{{ item.notes or item.who or "+ Add notes" }}</span>
</div>
{% endmacro %}

<div class="dashboard">
  <div class="header">
    <span class="header-title">&#128203; Brian's Dashboard</span>
    <a href="/quick-add" class="header-link">+ Quick Add</a>
  </div>

  <div class="section">
    <span class="priority-label inbox">INBOX &mdash; needs triage</span>
    {% if inbox %}
      {% for item in inbox %}
      <div class="item-row" data-id="{{ item.id }}">
        <div class="row-line1">
          <span class="item-text">{{ item.text }}</span>
          <span class="item-timestamp">{{ item.captured_at|relative_time }}</span>
        </div>
        {{ item_meta(item, all_tags) }}
        <div class="triage-cell">
          <select class="triage-type" data-id="{{ item.id }}">
            <option value="" disabled selected>Sort as...</option>
            <option value="task">Task</option>
            <option value="question">Question</option>
            <option value="idea">Idea</option>
          </select>
          <select class="triage-priority" data-id="{{ item.id }}" style="display:none;">
            <option value="" disabled selected>Priority...</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>
        </div>
      </div>
      {% endfor %}
    {% else %}
      <div class="empty">Inbox is empty &#127881;</div>
    {% endif %}
  </div>

  {% for label, css_class, group in [("HIGH", "high", tasks_high), ("MEDIUM", "medium", tasks_medium), ("LOW", "low", tasks_low)] %}
  <div class="section">
    <span class="priority-label {{ css_class }}">{{ label }}</span>
    {% if group %}
      {% for item in group %}
      <div class="item-row" data-id="{{ item.id }}">
        <div class="row-line1">
          <input type="checkbox" class="complete-checkbox" data-id="{{ item.id }}">
          <span class="item-text">{{ item.text }}</span>
          <span class="item-timestamp">{{ item.captured_at|relative_time }}</span>
        </div>
        {{ item_meta(item, all_tags) }}
      </div>
      {% endfor %}
    {% else %}
      <div class="empty">Nothing here &#127881;</div>
    {% endif %}
  </div>
  {% endfor %}

  <div class="section">
    <span class="priority-label question">QUESTIONS</span>
    {% if questions %}
      {% for item in questions %}
      <div class="item-row" data-id="{{ item.id }}">
        <div class="row-line1">
          <input type="checkbox" class="complete-checkbox" data-id="{{ item.id }}">
          <span class="item-text">{{ item.text }}</span>
          <span class="item-timestamp">{{ item.captured_at|relative_time }}</span>
        </div>
        {{ item_meta(item, all_tags) }}
      </div>
      {% endfor %}
    {% else %}
      <div class="empty">No open questions</div>
    {% endif %}
  </div>

  <div class="section">
    <span class="priority-label idea">IDEAS</span>
    {% if ideas %}
      {% for item in ideas %}
      <div class="item-row" data-id="{{ item.id }}">
        <div class="row-line1">
          <input type="checkbox" class="complete-checkbox" data-id="{{ item.id }}">
          <span class="item-text">{{ item.text }}</span>
          <span class="item-timestamp">{{ item.captured_at|relative_time }}</span>
        </div>
        {{ item_meta(item, all_tags) }}
      </div>
      {% endfor %}
    {% else %}
      <div class="empty">No parked ideas</div>
    {% endif %}
  </div>

  <div class="completed-section">
    <span class="completed-label">COMPLETED</span>
    {% for item in completed %}
    <div class="task-row">
      <div class="task-cell"><span class="task-done">{{ item.text }}</span></div>
      <div class="notes-cell">{{ item.notes or item.who or "No notes" }}</div>
    </div>
    {% endfor %}
  </div>
</div>
<script src="{{ url_for('static', filename='dashboard.js') }}"></script>
</body>
</html>
```

Note: the Completed section keeps the old `.task-row`/`.task-cell`/`.notes-cell` markup and CSS, unchanged, per the spec.

- [ ] **Step 5: Fix the `.task-row` selector in `dashboard.js` for the renamed Inbox row class**

In `static/dashboard.js`, line 26, replace:

```javascript
    var row = this.closest(".task-row");
```

with:

```javascript
    var row = this.closest(".item-row");
```

This is needed because the Inbox row's wrapper class changed from `task-row` to `item-row` in Step 4 above (the `.task-row` class is now reserved for the Completed section's old grid layout only, so `.triage-priority`'s sibling lookup must target the new class).

- [ ] **Step 6: Add CSS for the new row structure**

Append to `static/style.css`:

```css
.item-row { background: #182543; border-radius: 6px; padding: 10px 14px; margin-bottom: 6px; }
.row-line1 { display: flex; align-items: center; gap: 10px; }
.item-text { flex: 1; font-size: .92rem; color: #f1f5f9; }
.item-timestamp { font-size: .76rem; color: #94a3b8; white-space: nowrap; }
.row-line2 { display: flex; align-items: center; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
.item-context { font-size: .8rem; color: #94a3b8; margin-left: auto; }
.tag-badge { font-size: .68rem; padding: 2px 9px; border-radius: 10px; font-weight: 700; letter-spacing: .04em; }
.tag-gray   { background: #64748b33; color: #cbd5e1; }
.tag-blue   { background: #3b82f633; color: #60a5fa; }
.tag-red    { background: #ef444433; color: #f87171; }
.tag-amber  { background: #f59e0b33; color: #fbbf24; }
.tag-purple { background: #a855f733; color: #c084fc; }
.tag-cyan   { background: #06b6d433; color: #22d3ee; }
.due-date-badge { background: #3b5bfd33; color: #7c93ff; font-size: .72rem; padding: 2px 10px; border-radius: 10px; font-weight: 600; }
.due-date-badge.no-date { background: transparent; border: 1px dashed #3a4870; color: #64748b; }
.item-row .triage-cell { background: transparent; padding: 8px 0 0; margin-top: 4px; }
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v`
Expected: all tests PASS (3 existing + 4 new = 7)

- [ ] **Step 8: Run the full suite to check for regressions**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest -v`
Expected: all tests PASS

- [ ] **Step 9: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add templates/dashboard.html static/dashboard.js static/style.css app.py tests/test_dashboard.py
git commit -m "Render two-line item rows with timestamps, tag badges, and due-date badges"
```

---

### Task 9: Due-date inline edit

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/dashboard.html` (the `item_meta` macro)
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/dashboard.js`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/style.css`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_dashboard.py`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_dashboard.py`:

```python
def test_dashboard_includes_hidden_due_date_input(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "No due date yet")
    db.triage_item(db_path, item_id, "task", priority="low")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "+ Due date" in body
    assert 'class="due-date-input"' in body
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v -k due_date_input`
Expected: FAIL — no `due-date-input` element exists yet.

- [ ] **Step 3: Add the hidden date input to the `item_meta` macro**

In `templates/dashboard.html`, inside the `item_meta` macro, replace:

```html
  <span class="due-date-badge {{ 'has-date' if item.due_date else 'no-date' }}" data-id="{{ item.id }}">
    {% if item.due_date %}&#128197; Due {{ item.due_date }}{% else %}+ Due date{% endif %}
  </span>
```

with:

```html
  <span class="due-date-badge {{ 'has-date' if item.due_date else 'no-date' }}" data-id="{{ item.id }}">
    {% if item.due_date %}&#128197; Due {{ item.due_date }}{% else %}+ Due date{% endif %}
  </span>
  <input type="date" class="due-date-input" data-id="{{ item.id }}" value="{{ item.due_date or '' }}" style="display:none;">
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v -k due_date_input`
Expected: PASS

- [ ] **Step 5: Wire up click-to-edit in `static/dashboard.js`**

Append to `static/dashboard.js`:

```javascript
document.querySelectorAll(".due-date-badge").forEach(function (badge) {
  badge.addEventListener("click", function () {
    var id = this.dataset.id;
    var input = document.querySelector('.due-date-input[data-id="' + id + '"]');
    this.style.display = "none";
    input.style.display = "inline-block";
    input.focus();
  });
});

document.querySelectorAll(".due-date-input").forEach(function (input) {
  input.addEventListener("change", function () {
    var id = this.dataset.id;
    fetch("/items/" + id, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ due_date: this.value || null })
    }).then(function (response) {
      if (!response.ok) {
        alert("That didn't save — the item may have been changed elsewhere. Reloading.");
      }
      window.location.reload();
    }).catch(function () {
      alert("Couldn't reach the server. Try again.");
    });
  });
});
```

- [ ] **Step 6: Add CSS for the clickable badge and date input**

Append to `static/style.css`:

```css
.due-date-badge { cursor: pointer; }
.due-date-input { background: #182543; border: 1px solid #3a4870; border-radius: 10px; color: #f1f5f9; font-size: .72rem; padding: 2px 8px; }
```

- [ ] **Step 7: Manual verification**

1. Start the server: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python app.py`
2. Open `http://localhost:5151/` — find any item with no due date, showing "+ Due date"
3. Click it — a date picker should appear in its place
4. Pick a date — the page reloads and the item now shows "📅 Due <date>"
5. Click that badge again, clear the date field, confirm it reverts to "+ Due date" after the page reloads

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add templates/dashboard.html static/dashboard.js static/style.css tests/test_dashboard.py
git commit -m "Add click-to-edit due date on dashboard item rows"
```

---

### Task 10: Notes inline edit

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/dashboard.html` (the `item_meta` macro)
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/dashboard.js`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/style.css`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_dashboard.py`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_dashboard.py`:

```python
def test_dashboard_includes_hidden_notes_textarea(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "No notes yet")
    db.triage_item(db_path, item_id, "task", priority="low")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "+ Add notes" in body
    assert 'class="notes-input"' in body
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v -k notes_textarea`
Expected: FAIL — no `notes-input` element exists yet.

- [ ] **Step 3: Add the hidden notes textarea to the `item_meta` macro**

In `templates/dashboard.html`, inside the `item_meta` macro, replace:

```html
  <span class="item-context" data-id="{{ item.id }}">{{ item.notes or item.who or "+ Add notes" }}</span>
```

with:

```html
  <span class="item-context" data-id="{{ item.id }}">{{ item.notes or item.who or "+ Add notes" }}</span>
  <textarea class="notes-input" data-id="{{ item.id }}" style="display:none;">{{ item.notes or "" }}</textarea>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v -k notes_textarea`
Expected: PASS

- [ ] **Step 5: Wire up click-to-edit in `static/dashboard.js`**

Append to `static/dashboard.js`:

```javascript
document.querySelectorAll(".item-context").forEach(function (span) {
  span.addEventListener("click", function () {
    var id = this.dataset.id;
    var textarea = document.querySelector('.notes-input[data-id="' + id + '"]');
    this.style.display = "none";
    textarea.style.display = "block";
    textarea.focus();
  });
});

document.querySelectorAll(".notes-input").forEach(function (textarea) {
  textarea.addEventListener("blur", function () {
    var id = this.dataset.id;
    fetch("/items/" + id, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ notes: this.value.trim() || null })
    }).then(function (response) {
      if (!response.ok) {
        alert("That didn't save — the item may have been changed elsewhere. Reloading.");
      }
      window.location.reload();
    }).catch(function () {
      alert("Couldn't reach the server. Try again.");
    });
  });
});
```

- [ ] **Step 6: Add CSS for the clickable context span and textarea**

Append to `static/style.css`:

```css
.item-context { cursor: pointer; }
.notes-input { width: 100%; margin-top: 6px; background: #131d38; border: 1px solid #3a4870; border-radius: 6px; color: #f1f5f9; font-size: .8rem; padding: 6px 10px; font-family: inherit; min-height: 50px; }
```

- [ ] **Step 7: Manual verification**

1. Start the server: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python app.py`
2. Open `http://localhost:5151/` — find any item showing "+ Add notes"
3. Click it — a textarea should appear in its place
4. Type a note and click elsewhere on the page (blur) — the page reloads and the note now shows in place of "+ Add notes"

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add templates/dashboard.html static/dashboard.js static/style.css tests/test_dashboard.py
git commit -m "Add click-to-edit notes on dashboard item rows"
```

---

### Task 11: Tag picker panel

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/dashboard.html` (the `item_meta` macro)
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/dashboard.js`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/style.css`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_dashboard.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_dashboard.py`:

```python
def test_dashboard_shows_tags_panel_with_all_tags(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    db.triage_item(db_path, item_id, "task", priority="low")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert 'class="tags-panel"' in body
    assert "Not Started" in body
    assert "In Progress" in body


def test_dashboard_marks_applied_tag_chip(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Fix slicer")
    db.triage_item(db_path, item_id, "task", priority="low")
    tag_id = db.create_tag(db_path, "Blocked")
    db.add_tag_to_item(db_path, item_id, tag_id)
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "tag-chip tag-red applied" in body
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v -k tags_panel or applied_tag_chip`
Expected: both FAIL — no tags panel exists yet.

- [ ] **Step 3: Add the tags button and panel to the `item_meta` macro**

In `templates/dashboard.html`, replace the entire `item_meta` macro with:

```html
{% macro item_meta(item, all_tags) %}
<div class="row-line2">
  {% for tag in item.tags %}
  <span class="tag-badge tag-{{ tag.color }}">{{ tag.name|upper }}</span>
  {% endfor %}
  <span class="tags-button" data-id="{{ item.id }}">&#127991; Tags</span>
  <span class="due-date-badge {{ 'has-date' if item.due_date else 'no-date' }}" data-id="{{ item.id }}">
    {% if item.due_date %}&#128197; Due {{ item.due_date }}{% else %}+ Due date{% endif %}
  </span>
  <input type="date" class="due-date-input" data-id="{{ item.id }}" value="{{ item.due_date or '' }}" style="display:none;">
  <span class="item-context" data-id="{{ item.id }}">{{ item.notes or item.who or "+ Add notes" }}</span>
  <textarea class="notes-input" data-id="{{ item.id }}" style="display:none;">{{ item.notes or "" }}</textarea>
</div>
<div class="tags-panel" data-id="{{ item.id }}" style="display:none;">
  {% set applied_ids = item.tags | map(attribute="id") | list %}
  {% for tag in all_tags %}
  <span class="tag-chip tag-{{ tag.color }}{{ ' applied' if tag.id in applied_ids else '' }}" data-id="{{ item.id }}" data-tag-id="{{ tag.id }}">{{ tag.name }}</span>
  {% endfor %}
  <div class="tags-new">
    <input type="text" class="tags-new-input" data-id="{{ item.id }}" placeholder="+ New tag name...">
    <span class="tags-new-add" data-id="{{ item.id }}">Add</span>
  </div>
</div>
{% endmacro %}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest tests/test_dashboard.py -v`
Expected: all tests PASS

- [ ] **Step 5: Wire up the panel toggle, tag toggling, and new-tag creation in `static/dashboard.js`**

Append to `static/dashboard.js`:

```javascript
document.querySelectorAll(".tags-button").forEach(function (btn) {
  btn.addEventListener("click", function () {
    var id = this.dataset.id;
    var panel = document.querySelector('.tags-panel[data-id="' + id + '"]');
    panel.style.display = panel.style.display === "none" ? "flex" : "none";
  });
});

document.querySelectorAll(".tag-chip").forEach(function (chip) {
  chip.addEventListener("click", function () {
    var id = this.dataset.id;
    var tagId = this.dataset.tagId;
    var applied = this.classList.contains("applied");
    var request = applied
      ? fetch("/items/" + id + "/tags/" + tagId, { method: "DELETE" })
      : fetch("/items/" + id + "/tags", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ tag_id: parseInt(tagId, 10) })
        });
    request.then(function (response) {
      if (!response.ok) {
        alert("That didn't save — the item may have been changed elsewhere. Reloading.");
      }
      window.location.reload();
    }).catch(function () {
      alert("Couldn't reach the server. Try again.");
    });
  });
});

document.querySelectorAll(".tags-new-add").forEach(function (btn) {
  btn.addEventListener("click", function () {
    var id = this.dataset.id;
    var input = document.querySelector('.tags-new-input[data-id="' + id + '"]');
    var name = input.value.trim();
    if (!name) {
      return;
    }
    fetch("/tags", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name })
    }).then(function (response) {
      return response.json();
    }).then(function (data) {
      return fetch("/items/" + id + "/tags", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tag_id: data.id })
      });
    }).then(function (response) {
      if (!response.ok) {
        alert("That didn't save — the item may have been changed elsewhere. Reloading.");
      }
      window.location.reload();
    }).catch(function () {
      alert("Couldn't reach the server. Try again.");
    });
  });
});
```

- [ ] **Step 6: Add CSS for the tags button, panel, and chips**

Append to `static/style.css`:

```css
.tags-button { cursor: pointer; font-size: .72rem; color: #94a3b8; background: transparent; border: 1px dashed #3a4870; padding: 2px 10px; border-radius: 10px; }
.tags-panel { margin-top: 8px; padding: 10px; background: #131d38; border-radius: 6px; display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
.tag-chip { cursor: pointer; font-size: .72rem; padding: 3px 10px; border-radius: 10px; border: 1px solid #3a4870; background: #182543; color: #94a3b8; font-weight: 600; }
.tag-chip.applied.tag-gray   { background: #64748b; color: white; border-color: #64748b; }
.tag-chip.applied.tag-blue   { background: #3b82f6; color: white; border-color: #3b82f6; }
.tag-chip.applied.tag-red    { background: #ef4444; color: white; border-color: #ef4444; }
.tag-chip.applied.tag-amber  { background: #f59e0b; color: white; border-color: #f59e0b; }
.tag-chip.applied.tag-purple { background: #a855f7; color: white; border-color: #a855f7; }
.tag-chip.applied.tag-cyan   { background: #06b6d4; color: white; border-color: #06b6d4; }
.tags-new { display: flex; gap: 6px; align-items: center; }
.tags-new-input { background: #182543; border: 1px dashed #3a4870; border-radius: 6px; padding: 4px 10px; font-size: .72rem; color: #f1f5f9; }
.tags-new-add { cursor: pointer; background: #3b5bfd; color: white; font-size: .72rem; padding: 4px 12px; border-radius: 6px; }
```

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python -m pytest -v`
Expected: all tests PASS

- [ ] **Step 8: Manual verification**

1. Start the server: `cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard" && python app.py`
2. Open `http://localhost:5151/` — find any item, click "🏷️ Tags"
3. Confirm the panel opens showing all 6+ starter tags as outlined chips
4. Click "Blocked" — the page reloads, the item now shows a filled red "BLOCKED" badge on line 2
5. Click "🏷️ Tags" again, click "Blocked" again (now filled/applied) — confirm it detaches and the badge disappears after reload
6. Type "Test Tag" in the "+ New tag name..." box and click "Add" — confirm a new "Test Tag" badge appears on the item, and reopening the panel on any other item shows "Test Tag" as an available chip too

- [ ] **Step 9: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add templates/dashboard.html static/dashboard.js static/style.css tests/test_dashboard.py
git commit -m "Add tag picker panel with toggle and create-new-tag support"
```

---

## Self-Review Notes

- **Spec coverage:** Notes (Task 2 db layer, Task 4 capture, Task 5 PATCH, Task 7 quick-add form, Task 10 inline edit) ✓. Due date (Task 1 migration, Task 2 db layer, Task 4 capture, Task 5 PATCH, Task 7 quick-add form, Task 8 display, Task 9 inline edit) ✓. Tags (Task 1 migration + starter seed, Task 2 db layer, Task 6 API, Task 8 display, Task 11 picker panel) ✓. Timestamps (Task 3 helper, Task 8 display) ✓. Migration safety on existing `dashboard.db` (Task 1, explicitly tested against a pre-existing `items` table without `due_date`) ✓.
- **Placeholder scan:** no TBD/TODO markers; every step shows complete code.
- **Type consistency:** `db.get_items` returns items with a `tags` key (list of `{id, name, color}` dicts) from Task 2 onward, used consistently in Tasks 8, 9, 10, 11. `db.update_item(db_path, item_id, notes=_UNSET, due_date=_UNSET)` signature from Task 2 matches its usage in Task 5's route. `db.create_tag`, `db.get_tags`, `db.add_tag_to_item`, `db.remove_tag_from_item` signatures from Task 2 match their usage in Task 6's routes.
