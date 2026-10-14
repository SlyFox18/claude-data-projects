# Personal Capture & Todo Dashboard v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the markdown+static-HTML personal todo system with a local Flask + SQLite app supporting frictionless capture (browser form + global hotkey), deferred triage, one-click completion, and Windows toast reminders.

**Architecture:** A single Flask server (`app.py`) owns a SQLite database (`db.py`) as the sole source of truth. The dashboard and quick-add form are server-rendered Jinja2 templates with small vanilla-JS AJAX calls for interactivity (no build step, no frontend framework). An AutoHotkey script and two scheduled Python scripts (daily digest, stale-item check) all talk to the same server/database. Windows Task Scheduler handles auto-start and recurring jobs, reusing the pattern already proven in `data-projects/projects/fabric-monitoring/`.

**Tech Stack:** Python 3.13, Flask, SQLite (stdlib `sqlite3`), `win11toast` (Windows toast notifications), pytest, vanilla JS, AutoHotkey v2, Windows Task Scheduler (PowerShell).

**Repo:** New repo at `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/` (separate from `data-projects` — not Power BI/Fabric work).

**Spec:** `data-projects/docs/superpowers/specs/2026-07-02-todo-dashboard-v2-design.md`

---

### Task 1: Repo scaffold

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/.gitignore`
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/requirements.txt`
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/README.md`

- [ ] **Step 1: Create the repo and folder structure**

```bash
mkdir -p "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts"
mkdir -p "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/hotkey"
mkdir -p "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates"
mkdir -p "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static"
mkdir -p "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests"
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git init
```

- [ ] **Step 2: Write `.gitignore`**

```
__pycache__/
*.pyc
.pytest_cache/
dashboard.db
.venv/
venv/
*.egg-info/
```

- [ ] **Step 3: Write `requirements.txt`**

```
flask==3.0.3
win11toast==0.35
pytest==8.2.0
```

- [ ] **Step 4: Write `README.md`**

```markdown
# Personal Dashboard

Local capture/triage/todo system. Replaces the old `todo.md`/`todo.html` pair.

## Setup

    python -m venv .venv
    .venv\Scripts\activate
    pip install -r requirements.txt
    pytest

## Run the server

    python app.py

Dashboard: http://localhost:5151/
Quick add: http://localhost:5151/quick-add

## Register scheduled tasks (server auto-start, daily digest, stale check)

    powershell -File scripts\register-scheduled-tasks.ps1

## Hotkey capture

Requires AutoHotkey v2 (https://www.autohotkey.com/). Run `hotkey/quick-capture.ahk`
(or add it to your Startup folder to run automatically). Default hotkey: Ctrl+Alt+T.

See `data-projects/docs/superpowers/specs/2026-07-02-todo-dashboard-v2-design.md` for the full design.
```

- [ ] **Step 5: Create a Python virtual environment and install dependencies**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Expected: no errors, `flask`, `win11toast`, `pytest` installed.

- [ ] **Step 6: Commit**

```bash
git add .gitignore requirements.txt README.md
git commit -m "Scaffold personal-dashboard repo"
```

---

### Task 2: Database layer

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/db.py`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_db.py`

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_db.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import sqlite3
from datetime import datetime, timedelta
import db


def test_insert_item_creates_inbox_item(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    db.insert_item(db_path, "Fix slicer on branch 5", who="John")
    items = db.get_items(db_path, status="open")
    assert len(items) == 1
    assert items[0]["text"] == "Fix slicer on branch 5"
    assert items[0]["who"] == "John"
    assert items[0]["type"] == "inbox"
    assert items[0]["status"] == "open"


def test_triage_item_sets_type_and_priority(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Investigate GlTrans failure")
    db.triage_item(db_path, item_id, "task", priority="high")
    items = db.get_items(db_path, status="open")
    assert items[0]["type"] == "task"
    assert items[0]["priority"] == "high"
    assert items[0]["triaged_at"] is not None


def test_complete_item_moves_to_completed_status(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Send reminder")
    db.complete_item(db_path, item_id)
    open_items = db.get_items(db_path, status="open")
    completed_items = db.get_items(db_path, status="completed")
    assert len(open_items) == 0
    assert len(completed_items) == 1
    assert completed_items[0]["completed_at"] is not None


def test_get_stale_high_tasks_finds_old_untouched_high_priority(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Old high task")
    db.triage_item(db_path, item_id, "task", priority="high")
    old_date = (datetime.now() - timedelta(days=5)).isoformat()
    conn = sqlite3.connect(db_path)
    conn.execute("UPDATE items SET triaged_at = ? WHERE id = ?", (old_date, item_id))
    conn.commit()
    conn.close()
    stale = db.get_stale_high_tasks(db_path, days=3)
    assert len(stale) == 1
    assert stale[0]["id"] == item_id


def test_get_stale_high_tasks_excludes_recent_items(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Recent high task")
    db.triage_item(db_path, item_id, "task", priority="high")
    stale = db.get_stale_high_tasks(db_path, days=3)
    assert len(stale) == 0
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
pytest tests/test_db.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'db'`

- [ ] **Step 3: Write `db.py`**

Every function takes `db_path` as its **first, required, positional** argument — never a default parameter bound to a module-level path. This is deliberate: default argument values are bound once at function-definition time, so a default like `db_path=DEFAULT_DB_PATH` can't be swapped out later for tests (patching `DEFAULT_DB_PATH` after the fact wouldn't change the already-bound default). Requiring it explicitly avoids that trap entirely.

```python
# db.py
import sqlite3
from pathlib import Path
from datetime import datetime, timedelta

DEFAULT_DB_PATH = Path(__file__).parent / "dashboard.db"


def get_connection(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


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
    conn.commit()
    conn.close()


def insert_item(db_path, text, who=None, notes=None):
    conn = get_connection(db_path)
    now = datetime.now().isoformat()
    cursor = conn.execute(
        "INSERT INTO items (text, who, notes, type, status, captured_at) "
        "VALUES (?, ?, ?, 'inbox', 'open', ?)",
        (text, who, notes, now),
    )
    conn.commit()
    item_id = cursor.lastrowid
    conn.close()
    return item_id


def get_items(db_path, status="open"):
    conn = get_connection(db_path)
    rows = conn.execute(
        "SELECT * FROM items WHERE status = ? ORDER BY captured_at DESC", (status,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def triage_item(db_path, item_id, item_type, priority=None):
    conn = get_connection(db_path)
    now = datetime.now().isoformat()
    conn.execute(
        "UPDATE items SET type = ?, priority = ?, triaged_at = ? WHERE id = ?",
        (item_type, priority, now, item_id),
    )
    conn.commit()
    conn.close()


def complete_item(db_path, item_id):
    conn = get_connection(db_path)
    now = datetime.now().isoformat()
    conn.execute(
        "UPDATE items SET status = 'completed', completed_at = ? WHERE id = ?",
        (now, item_id),
    )
    conn.commit()
    conn.close()


def get_stale_high_tasks(db_path, days=3):
    conn = get_connection(db_path)
    cutoff = (datetime.now() - timedelta(days=days)).isoformat()
    rows = conn.execute(
        """
        SELECT * FROM items
        WHERE status = 'open' AND type = 'task' AND priority = 'high'
        AND COALESCE(triaged_at, captured_at) < ?
        """,
        (cutoff,),
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_db.py -v
```

Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add db.py tests/test_db.py
git commit -m "Add SQLite database layer with capture/triage/complete/stale-query functions"
```

---

### Task 3: Notification module

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/notify.py`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_notify.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_notify.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import notify


def test_send_toast_calls_toast_with_title_and_message(monkeypatch):
    calls = []
    monkeypatch.setattr(notify, "toast", lambda title, message: calls.append((title, message)))
    notify.send_toast("Test Title", "Test Message")
    assert calls == [("Test Title", "Test Message")]
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest tests/test_notify.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'notify'`

- [ ] **Step 3: Write `notify.py`**

```python
# notify.py
from win11toast import toast


def send_toast(title, message):
    toast(title, message)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pytest tests/test_notify.py -v
```

Expected: 1 passed

- [ ] **Step 5: Commit**

```bash
git add notify.py tests/test_notify.py
git commit -m "Add Windows toast notification wrapper"
```

---

### Task 4: Flask app skeleton + capture endpoint

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_capture.py`

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_capture.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from app import create_app
import db
import notify


@pytest.fixture
def client(tmp_path):
    db_path = tmp_path / "test.db"
    app = create_app(db_path=db_path)
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client, db_path


def test_capture_creates_inbox_item(client, monkeypatch):
    monkeypatch.setattr(notify, "send_toast", lambda *a, **kw: None)
    test_client, db_path = client
    response = test_client.post("/capture", json={"text": "Fix slicer", "who": "John"})
    assert response.status_code == 201
    items = db.get_items(db_path, status="open")
    assert len(items) == 1
    assert items[0]["text"] == "Fix slicer"
    assert items[0]["who"] == "John"


def test_capture_requires_text(client, monkeypatch):
    monkeypatch.setattr(notify, "send_toast", lambda *a, **kw: None)
    test_client, db_path = client
    response = test_client.post("/capture", json={"who": "John"})
    assert response.status_code == 400


def test_capture_sends_toast_notification(client, monkeypatch):
    test_client, db_path = client
    calls = []
    monkeypatch.setattr(notify, "send_toast", lambda title, message: calls.append((title, message)))
    test_client.post("/capture", json={"text": "Fix slicer"})
    assert len(calls) == 1
    assert calls[0][1] == "Fix slicer"
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_capture.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'app'`

- [ ] **Step 3: Write `app.py`** (capture route + app factory only — dashboard/triage routes come in later tasks)

```python
# app.py
from flask import Flask, request, jsonify, render_template
import db
import notify


def create_app(db_path=None):
    if db_path is None:
        db_path = db.DEFAULT_DB_PATH

    app = Flask(__name__)
    app.config["DB_PATH"] = db_path
    db.init_db(db_path)

    @app.route("/capture", methods=["POST"])
    def capture():
        data = request.get_json(force=True)
        text = (data.get("text") or "").strip()
        if not text:
            return jsonify({"error": "text is required"}), 400
        who = data.get("who")
        notes = data.get("notes")
        item_id = db.insert_item(app.config["DB_PATH"], text, who=who, notes=notes)
        notify.send_toast("Captured", text)
        return jsonify({"id": item_id}), 201

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(port=5151)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_capture.py -v
```

Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add app.py tests/test_capture.py
git commit -m "Add Flask app factory and capture endpoint"
```

---

### Task 5: Shared dark-theme CSS + quick-add form

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/style.css`
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/quick-add.js`
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/quick-add.html`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py` (add `/quick-add` route)

This task has no automated tests — it's a UI page, verified manually in Step 5. `render_template` needs a real Flask request context to test meaningfully, and the value here is visual, not logical.

- [ ] **Step 1: Write `static/style.css`**

```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #020817; color: #f1f5f9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 32px 24px; min-height: 100vh; }
.dashboard { max-width: 820px; margin: 0 auto; background: #0f172a; border-radius: 10px; overflow: hidden; border: 1px solid #1e293b; }
.header { background: #1e293b; padding: 14px 20px; display: flex; align-items: center; justify-content: space-between; }
.header-title { color: #f1f5f9; font-weight: 600; font-size: 1rem; }
.header-link { color: #3b5bfd; font-size: .8rem; text-decoration: none; }
.section { padding: 12px 20px 8px; }
.section + .section { border-top: 1px solid #1e293b; }
.priority-label { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: .7rem; font-weight: 700; letter-spacing: .08em; margin-bottom: 8px; }
.high     { background: #ef444422; color: #ef4444; }
.medium   { background: #f59e0b22; color: #f59e0b; }
.low      { background: #22c55e22; color: #22c55e; }
.inbox    { background: #3b5bfd22; color: #3b5bfd; }
.question { background: #a855f722; color: #a855f7; }
.idea     { background: #06b6d422; color: #06b6d4; }
.empty { color: #334155; font-style: italic; font-size: .85rem; padding: 4px 0 8px; }
.task-row { display: grid; grid-template-columns: 1fr 1fr auto; gap: 1px; background: #1e293b; border-radius: 6px; overflow: hidden; margin-bottom: 4px; align-items: center; }
.task-cell { background: #0f172a; padding: 9px 14px; display: flex; align-items: center; gap: 10px; font-size: .9rem; }
.notes-cell { background: #080f1a; padding: 9px 14px; display: flex; align-items: center; font-size: .82rem; color: #64748b; }
.triage-cell { background: #080f1a; padding: 6px 10px; display: flex; gap: 6px; align-items: center; }
.completed-section { padding: 12px 20px 8px; border-top: 1px solid #1e293b; opacity: .5; }
.completed-label { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: .7rem; font-weight: 700; letter-spacing: .08em; margin-bottom: 8px; background: #1e293b; color: #475569; }
.task-done { text-decoration: line-through; color: #475569; }
.complete-checkbox { width: 16px; height: 16px; cursor: pointer; }
.triage-type, .triage-priority { background: #0f172a; color: #f1f5f9; border: 1px solid #2a3348; border-radius: 4px; padding: 4px 8px; font-size: .78rem; }
.quick-add-form .section input { display: block; width: 100%; background: #0f172a; border: 1px solid #2a3348; border-radius: 6px; padding: 10px 12px; font-size: .9rem; color: #f1f5f9; margin-bottom: 8px; }
.quick-add-form .section button { background: #3b5bfd; color: white; border: none; border-radius: 6px; padding: 10px; font-size: .9rem; width: 100%; cursor: pointer; }
#capture-status { margin-top: 8px; font-size: .82rem; color: #64748b; }
```

- [ ] **Step 2: Write `templates/quick-add.html`**

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
    <input type="text" id="capture-text" placeholder="What does John need?" autofocus>
    <input type="text" id="capture-who" placeholder="Who asked / context (optional)">
    <button id="capture-submit">Add to Inbox</button>
    <div id="capture-status"></div>
  </div>
</div>
<script src="{{ url_for('static', filename='quick-add.js') }}"></script>
</body>
</html>
```

- [ ] **Step 3: Write `static/quick-add.js`**

```javascript
document.getElementById("capture-submit").addEventListener("click", function () {
  var text = document.getElementById("capture-text").value.trim();
  var who = document.getElementById("capture-who").value.trim();
  var status = document.getElementById("capture-status");
  if (!text) {
    status.textContent = "Type something first.";
    return;
  }
  fetch("/capture", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: text, who: who || null })
  }).then(function (response) {
    if (response.ok) {
      status.textContent = "Captured ✓";
      document.getElementById("capture-text").value = "";
      document.getElementById("capture-who").value = "";
      document.getElementById("capture-text").focus();
    } else {
      status.textContent = "Something went wrong.";
    }
  });
});

document.getElementById("capture-text").addEventListener("keydown", function (e) {
  if (e.key === "Enter") {
    document.getElementById("capture-submit").click();
  }
});
```

- [ ] **Step 4: Add the `/quick-add` route to `app.py`**

Add this route inside `create_app()`, alongside the existing `/capture` route:

```python
    @app.route("/quick-add", methods=["GET"])
    def quick_add_form():
        return render_template("quick-add.html")
```

- [ ] **Step 5: Manually verify**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
python app.py
```

Open `http://localhost:5151/quick-add` in a browser. Type something, click "Add to Inbox," confirm "Captured ✓" appears and a Windows toast notification pops up. Stop the server (Ctrl+C).

- [ ] **Step 6: Commit**

```bash
git add static/style.css static/quick-add.js templates/quick-add.html app.py
git commit -m "Add quick-add capture form with shared dark theme"
```

---

### Task 6: Dashboard route + template (view only)

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/templates/dashboard.html`
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py` (add `/` route)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_dashboard.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_dashboard.py
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


def test_dashboard_shows_inbox_item(client):
    test_client, db_path = client
    db.insert_item(db_path, "Untriaged thing")
    response = test_client.get("/")
    assert response.status_code == 200
    assert b"Untriaged thing" in response.data


def test_dashboard_groups_tasks_by_priority(client):
    test_client, db_path = client
    high_id = db.insert_item(db_path, "High priority task")
    db.triage_item(db_path, high_id, "task", priority="high")
    low_id = db.insert_item(db_path, "Low priority task")
    db.triage_item(db_path, low_id, "task", priority="low")
    response = test_client.get("/")
    body = response.data.decode("utf-8")
    assert "High priority task" in body
    assert "Low priority task" in body


def test_dashboard_shows_completed_items_separately(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Done thing")
    db.complete_item(db_path, item_id)
    response = test_client.get("/")
    assert b"Done thing" in response.data
    assert b"task-done" in response.data
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_dashboard.py -v
```

Expected: FAIL — `werkzeug.routing.exceptions.NotFound` (no `/` route yet)

- [ ] **Step 3: Write `templates/dashboard.html`**

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
<div class="dashboard">
  <div class="header">
    <span class="header-title">&#128203; Brian's Dashboard</span>
    <a href="/quick-add" class="header-link">+ Quick Add</a>
  </div>

  <div class="section">
    <span class="priority-label inbox">INBOX &mdash; needs triage</span>
    {% if inbox %}
      {% for item in inbox %}
      <div class="task-row" data-id="{{ item.id }}">
        <div class="task-cell">{{ item.text }}</div>
        <div class="notes-cell">{{ item.who or "No context" }}</div>
        <div class="triage-cell">
          <select class="triage-type" data-id="{{ item.id }}">
            <option value="">Sort as...</option>
            <option value="task">Task</option>
            <option value="question">Question</option>
            <option value="idea">Idea</option>
          </select>
          <select class="triage-priority" data-id="{{ item.id }}" style="display:none;">
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
      <div class="task-row" data-id="{{ item.id }}">
        <div class="task-cell">
          <input type="checkbox" class="complete-checkbox" data-id="{{ item.id }}">
          {{ item.text }}
        </div>
        <div class="notes-cell">{{ item.notes or item.who or "No notes" }}</div>
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
      <div class="task-row" data-id="{{ item.id }}">
        <div class="task-cell">
          <input type="checkbox" class="complete-checkbox" data-id="{{ item.id }}">
          {{ item.text }}
        </div>
        <div class="notes-cell">{{ item.notes or item.who or "No notes" }}</div>
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
      <div class="task-row" data-id="{{ item.id }}">
        <div class="task-cell">
          <input type="checkbox" class="complete-checkbox" data-id="{{ item.id }}">
          {{ item.text }}
        </div>
        <div class="notes-cell">{{ item.notes or item.who or "No notes" }}</div>
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

- [ ] **Step 4: Add the `/` route to `app.py`**

Add this route inside `create_app()`:

```python
    @app.route("/", methods=["GET"])
    def dashboard():
        db_path = app.config["DB_PATH"]
        items = db.get_items(db_path, status="open")
        inbox = [i for i in items if i["type"] == "inbox"]
        tasks_high = [i for i in items if i["type"] == "task" and i["priority"] == "high"]
        tasks_medium = [i for i in items if i["type"] == "task" and i["priority"] == "medium"]
        tasks_low = [i for i in items if i["type"] == "task" and i["priority"] == "low"]
        questions = [i for i in items if i["type"] == "question"]
        ideas = [i for i in items if i["type"] == "idea"]
        completed = db.get_items(db_path, status="completed")
        return render_template(
            "dashboard.html",
            inbox=inbox,
            tasks_high=tasks_high,
            tasks_medium=tasks_medium,
            tasks_low=tasks_low,
            questions=questions,
            ideas=ideas,
            completed=completed,
        )
```

Note: this references `static/dashboard.js`, which doesn't exist yet (built in Task 8) — the page will still render fine without it for now (browser just logs a 404 for the script, harmless for this task's tests).

- [ ] **Step 5: Run tests to verify they pass**

```bash
pytest tests/test_dashboard.py -v
```

Expected: 3 passed

- [ ] **Step 6: Commit**

```bash
git add templates/dashboard.html app.py tests/test_dashboard.py
git commit -m "Add dashboard view grouped by inbox/priority/type/completed"
```

---

### Task 7: Triage + complete endpoint

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/app.py` (add `PATCH /items/<id>`)
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_triage.py`

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_triage.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from app import create_app
import db
import notify


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(notify, "send_toast", lambda *a, **kw: None)
    db_path = tmp_path / "test.db"
    app = create_app(db_path=db_path)
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client, db_path


def test_triage_sets_type_and_priority(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Investigate GlTrans failure")
    response = test_client.patch(f"/items/{item_id}", json={"type": "task", "priority": "high"})
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["type"] == "task"
    assert items[0]["priority"] == "high"


def test_triage_question_needs_no_priority(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "What did John mean by this?")
    response = test_client.patch(f"/items/{item_id}", json={"type": "question"})
    assert response.status_code == 200
    items = db.get_items(db_path, status="open")
    assert items[0]["type"] == "question"
    assert items[0]["priority"] is None


def test_complete_moves_item_to_completed(client):
    test_client, db_path = client
    item_id = db.insert_item(db_path, "Send reminder")
    response = test_client.patch(f"/items/{item_id}", json={"status": "completed"})
    assert response.status_code == 200
    open_items = db.get_items(db_path, status="open")
    completed_items = db.get_items(db_path, status="completed")
    assert len(open_items) == 0
    assert len(completed_items) == 1
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_triage.py -v
```

Expected: FAIL — `werkzeug.routing.exceptions.MethodNotAllowed` or `NotFound` (no `PATCH /items/<id>` route yet)

- [ ] **Step 3: Add the `PATCH /items/<id>` route to `app.py`**

```python
    @app.route("/items/<int:item_id>", methods=["PATCH"])
    def update_item(item_id):
        data = request.get_json(force=True)
        db_path = app.config["DB_PATH"]
        if data.get("status") == "completed":
            db.complete_item(db_path, item_id)
        elif "type" in data:
            db.triage_item(db_path, item_id, data["type"], priority=data.get("priority"))
        return jsonify({"ok": True})
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_triage.py -v
```

Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add app.py tests/test_triage.py
git commit -m "Add triage and complete endpoint"
```

---

### Task 8: Dashboard client-side interactivity

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/static/dashboard.js`

No automated test — this is DOM event wiring, verified manually in Step 2 (same reasoning as Task 5: the logic it calls is already covered by Task 7's endpoint tests, what's untested here is purely "does clicking a checkbox in a real browser fire the right request").

- [ ] **Step 1: Write `static/dashboard.js`**

```javascript
document.querySelectorAll(".complete-checkbox").forEach(function (checkbox) {
  checkbox.addEventListener("change", function () {
    var id = this.dataset.id;
    fetch("/items/" + id, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status: "completed" })
    }).then(function () {
      window.location.reload();
    });
  });
});

document.querySelectorAll(".triage-type").forEach(function (select) {
  select.addEventListener("change", function () {
    var id = this.dataset.id;
    var type = this.value;
    var row = this.closest(".task-row");
    var prioritySelect = row.querySelector(".triage-priority");
    if (type === "task") {
      prioritySelect.style.display = "inline-block";
      return;
    }
    fetch("/items/" + id, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: type })
    }).then(function () {
      window.location.reload();
    });
  });
});

document.querySelectorAll(".triage-priority").forEach(function (select) {
  select.addEventListener("change", function () {
    var id = this.dataset.id;
    var priority = this.value;
    var typeSelect = this.closest(".task-row").querySelector(".triage-type");
    fetch("/items/" + id, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: typeSelect.value, priority: priority })
    }).then(function () {
      window.location.reload();
    });
  });
});
```

- [ ] **Step 2: Manually verify**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
python app.py
```

In a browser: go to `http://localhost:5151/quick-add`, capture something. Go to `http://localhost:5151/`, confirm it shows in Inbox. Set its type to "Task," set priority to "High," confirm it moves into the HIGH section. Click its checkbox, confirm it moves to COMPLETED. Stop the server (Ctrl+C).

- [ ] **Step 3: Commit**

```bash
git add static/dashboard.js
git commit -m "Add dashboard triage and completion interactivity"
```

---

### Task 9: Daily digest script

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/daily_digest.py`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_daily_digest.py`

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_daily_digest.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

import db
import daily_digest


def test_build_digest_message_counts_by_type(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    db.insert_item(db_path, "Untriaged item")
    high_id = db.insert_item(db_path, "High task")
    db.triage_item(db_path, high_id, "task", priority="high")
    message = daily_digest.build_digest_message(db_path)
    assert "1 to triage" in message
    assert "1 high" in message


def test_build_digest_message_when_empty(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    message = daily_digest.build_digest_message(db_path)
    assert message == "Nothing open — clean slate"
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_daily_digest.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'daily_digest'`

- [ ] **Step 3: Write `scripts/daily_digest.py`**

```python
# scripts/daily_digest.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import db
import notify


def build_digest_message(db_path):
    open_items = db.get_items(db_path, status="open")
    inbox_count = len([i for i in open_items if i["type"] == "inbox"])
    high_count = len([i for i in open_items if i["type"] == "task" and i["priority"] == "high"])
    medium_count = len([i for i in open_items if i["type"] == "task" and i["priority"] == "medium"])
    low_count = len([i for i in open_items if i["type"] == "task" and i["priority"] == "low"])
    question_count = len([i for i in open_items if i["type"] == "question"])

    parts = []
    if inbox_count:
        parts.append(f"{inbox_count} to triage")
    if high_count:
        parts.append(f"{high_count} high")
    if medium_count:
        parts.append(f"{medium_count} medium")
    if low_count:
        parts.append(f"{low_count} low")
    if question_count:
        parts.append(f"{question_count} questions")

    return ", ".join(parts) if parts else "Nothing open — clean slate"


def main():
    message = build_digest_message(db.DEFAULT_DB_PATH)
    notify.send_toast("Daily Digest", message)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_daily_digest.py -v
```

Expected: 2 passed

- [ ] **Step 5: Commit**

```bash
git add scripts/daily_digest.py tests/test_daily_digest.py
git commit -m "Add daily digest script"
```

---

### Task 10: Stale-item check script

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/stale_check.py`
- Test: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/tests/test_stale_check.py`

- [ ] **Step 1: Write the failing tests**

```python
# tests/test_stale_check.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

import sqlite3
from datetime import datetime, timedelta
import db
import stale_check


def test_build_stale_message_reports_old_high_items(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    item_id = db.insert_item(db_path, "Old high task")
    db.triage_item(db_path, item_id, "task", priority="high")
    old_date = (datetime.now() - timedelta(days=5)).isoformat()
    conn = sqlite3.connect(db_path)
    conn.execute("UPDATE items SET triaged_at = ? WHERE id = ?", (old_date, item_id))
    conn.commit()
    conn.close()
    message = stale_check.build_stale_message(db_path, days=3)
    assert "1 high-priority item" in message
    assert "Old high task" in message


def test_build_stale_message_returns_none_when_nothing_stale(tmp_path):
    db_path = tmp_path / "test.db"
    db.init_db(db_path)
    message = stale_check.build_stale_message(db_path, days=3)
    assert message is None
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_stale_check.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'stale_check'`

- [ ] **Step 3: Write `scripts/stale_check.py`**

```python
# scripts/stale_check.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import db
import notify


def build_stale_message(db_path, days=3):
    stale = db.get_stale_high_tasks(db_path, days=days)
    if not stale:
        return None
    lines = [item["text"] for item in stale]
    return f"{len(stale)} high-priority item(s) untouched {days}+ days: " + "; ".join(lines)


def main():
    message = build_stale_message(db.DEFAULT_DB_PATH, days=3)
    if message:
        notify.send_toast("Stale High-Priority Items", message)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_stale_check.py -v
```

Expected: 2 passed

- [ ] **Step 5: Commit**

```bash
git add scripts/stale_check.py tests/test_stale_check.py
git commit -m "Add stale high-priority item check script"
```

---

### Task 11: Windows Task Scheduler registration

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/register-scheduled-tasks.ps1`

No automated test — this registers real Windows Task Scheduler entries, verified manually in Step 2.

- [ ] **Step 1: Write `scripts/register-scheduled-tasks.ps1`**

```powershell
# scripts/register-scheduled-tasks.ps1
$repoRoot = Split-Path -Parent $PSScriptRoot
$pythonExe = (Get-Command python).Source
$appScript = Join-Path $repoRoot "app.py"
$digestScript = Join-Path $repoRoot "scripts\daily_digest.py"
$staleScript = Join-Path $repoRoot "scripts\stale_check.py"

# 1. Server auto-start at login, restart on failure
$serverAction = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$appScript`"" -WorkingDirectory $repoRoot
$serverTrigger = New-ScheduledTaskTrigger -AtLogOn
$serverSettings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "PersonalDashboard-Server" -Action $serverAction -Trigger $serverTrigger -Settings $serverSettings -Force

# 2. Daily digest at 7:00 AM
$digestAction = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$digestScript`"" -WorkingDirectory $repoRoot
$digestTrigger = New-ScheduledTaskTrigger -Daily -At 7:00AM
Register-ScheduledTask -TaskName "PersonalDashboard-DailyDigest" -Action $digestAction -Trigger $digestTrigger -Force

# 3. Stale-item check, weekdays at 1:00 PM
$staleAction = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$staleScript`"" -WorkingDirectory $repoRoot
$staleTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 1:00PM
Register-ScheduledTask -TaskName "PersonalDashboard-StaleCheck" -Action $staleAction -Trigger $staleTrigger -Force

Write-Host "Registered 3 scheduled tasks: PersonalDashboard-Server, PersonalDashboard-DailyDigest, PersonalDashboard-StaleCheck"
```

- [ ] **Step 2: Manually verify**

```powershell
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
powershell -File scripts\register-scheduled-tasks.ps1
Get-ScheduledTask -TaskName "PersonalDashboard-*"
```

Expected: 3 tasks listed, all `Ready`. Manually run each once to confirm they work:

```powershell
Start-ScheduledTask -TaskName "PersonalDashboard-Server"
# wait a couple seconds, then check http://localhost:5151/ loads in a browser
Start-ScheduledTask -TaskName "PersonalDashboard-DailyDigest"
# confirm a toast notification appears
Start-ScheduledTask -TaskName "PersonalDashboard-StaleCheck"
# confirm a toast notification appears only if a stale high item exists
```

- [ ] **Step 3: Commit**

```bash
git add scripts/register-scheduled-tasks.ps1
git commit -m "Add Windows Task Scheduler registration for server auto-start and reminders"
```

---

### Task 12: AutoHotkey hotkey capture

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/hotkey/quick-capture.ahk`

No automated test — this is an AutoHotkey script, verified manually in Step 2. Requires AutoHotkey v2 installed (https://www.autohotkey.com/).

- [ ] **Step 1: Write `hotkey/quick-capture.ahk`**

```autohotkey
; hotkey/quick-capture.ahk
; Requires AutoHotkey v2.
; Global hotkey Ctrl+Alt+T opens a quick capture box that posts to the local
; personal-dashboard server. Run this script directly, or add a shortcut to
; it in shell:startup to have it running whenever you log in.

^!t::
{
    result := InputBox("Quick Capture", "What's on your mind?", "w400 h130")
    if (result.Result = "Cancel") {
        return
    }
    text := Trim(result.Value)
    if (text = "") {
        return
    }

    escapedText := StrReplace(text, '"', '\"')
    jsonBody := '{"text":"' . escapedText . '"}'

    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("POST", "http://localhost:5151/capture", false)
    whr.SetRequestHeader("Content-Type", "application/json")
    try {
        whr.Send(jsonBody)
        if (whr.Status != 201) {
            MsgBox("Capture failed (server returned " . whr.Status . "). Is the dashboard server running?")
        }
    } catch as err {
        MsgBox("Capture failed: could not reach the dashboard server. Is it running?`n`n" . err.Message)
    }
}
```

- [ ] **Step 2: Manually verify**

Make sure the server is running (`python app.py`, or via the scheduled task from Task 11). Double-click `hotkey/quick-capture.ahk` to run it (requires AutoHotkey v2 installed). From any application, press Ctrl+Alt+T — a small input box should appear. Type something and press OK. Confirm a Windows toast confirms the capture, and the item shows up in the dashboard's Inbox.

Test the failure path too: stop the server, press Ctrl+Alt+T again, confirm you get a clear "could not reach the dashboard server" message rather than a silent failure.

- [ ] **Step 3: Commit**

```bash
git add hotkey/quick-capture.ahk
git commit -m "Add AutoHotkey global hotkey capture script"
```

---

### Task 13: Claude Code integration — retire todo.md/todo.html, add SQLite-aware session summary

**Files:**
- Create: `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/session_summary.py`
- Modify: `C:/Users/bfox/.claude/settings.json`
- Modify: `C:/Users/bfox/.claude/scripts/git-status-check.sh`

- [ ] **Step 1: Write `scripts/session_summary.py`**

```python
# scripts/session_summary.py
# Standalone script for Claude Code's SessionStart hook — prints open
# high/medium tasks and flags anything still sitting untriaged in Inbox.
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import db


def main():
    open_items = db.get_items(db.DEFAULT_DB_PATH, status="open")
    inbox = [i for i in open_items if i["type"] == "inbox"]
    high = [i for i in open_items if i["type"] == "task" and i["priority"] == "high"]
    medium = [i for i in open_items if i["type"] == "task" and i["priority"] == "medium"]

    if inbox:
        print(f"\U0001F4E5 {len(inbox)} item(s) in Inbox, still need triage")

    if high or medium:
        print("\U0001F4CB Your open tasks:")
        for item in high:
            print(f"  HIGH   {item['text']}")
        for item in medium:
            print(f"  MEDIUM {item['text']}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Remove the todo.md-parsing block from `git-status-check.sh`**

In `C:/Users/bfox/.claude/scripts/git-status-check.sh`, find and delete this exact block (added 2026-07-01, appended at the end of the file after the git status checks for both repos):

```bash
# --- Daily To-Do Check ---
TODO_FILE="C:/Users/bfox/todo.md"
if [ -f "$TODO_FILE" ]; then
    TASKS=$(awk '
        /^## High/   { section="HIGH"; next }
        /^## Medium/ { section="MEDIUM"; next }
        /^## /       { section=""; next }
        section && /^- \[ \]/ {
            line = $0
            sub(/^- \[ \] /, "", line)
            split(line, parts, " \\| ")
            printf "  %-6s %s\n", section, parts[1]
        }
    ' "$TODO_FILE")

    if [ -n "$TASKS" ]; then
        echo "📋 Your open tasks:"
        echo "$TASKS"
        echo ""
    fi
fi
```

That logic is being replaced by `session_summary.py`, called as its own hook in Step 3. Everything above this block (the git status checks for both repos) stays untouched. If the file's current contents don't exactly match this block (e.g., it's been edited since), locate the "Daily To-Do Check" section by its comment header and delete through the matching closing `fi` instead.

- [ ] **Step 3: Update `~/.claude/settings.json`**

Two changes to the `hooks` object:

1. In `SessionStart`, replace the entry that calls `render_todo_html.py`:

```json
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"C:/Users/bfox/.claude/scripts/render_todo_html.py\"",
            "timeout": 10
          }
        ]
      },
```

with:

```json
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python \"C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/session_summary.py\"",
            "timeout": 10
          }
        ]
      },
```

2. In `PostToolUse`, remove the entry that calls `todo-html-sync.sh` entirely:

```json
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"C:/Users/bfox/.claude/scripts/todo-html-sync.sh\"",
            "timeout": 10
          }
        ]
      },
```

(No replacement needed — Claude no longer needs to sync anything, since capture/triage/completion all happen through the dashboard app directly, and Claude can read/write via the same `db.py` functions or the HTTP API when asked mid-conversation.)

- [ ] **Step 4: Verify settings.json is still valid JSON**

```bash
python3 -c "import json; json.load(open('C:/Users/bfox/.claude/settings.json'))" && echo VALID
```

Expected: `VALID`

- [ ] **Step 5: Manually verify the new session hook**

```bash
python "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/session_summary.py"
```

Expected: prints Inbox count (if any) and open High/Medium tasks (if any), matching whatever's actually in the dashboard at the time.

- [ ] **Step 6: Archive the old todo.md/todo.html files** (don't delete — keep as historical reference)

```powershell
New-Item -ItemType Directory -Force "C:\Users\bfox\archive"
Move-Item "C:\Users\bfox\todo.md" "C:\Users\bfox\archive\todo.md.v1"
Move-Item "C:\Users\bfox\todo.html" "C:\Users\bfox\archive\todo.html.v1"
```

- [ ] **Step 7: Remove the now-orphaned v1 renderer scripts**

```bash
rm "C:/Users/bfox/.claude/scripts/render_todo_html.py"
rm "C:/Users/bfox/.claude/scripts/todo-html-sync.sh"
```

- [ ] **Step 8: Commit** (in the `personal-dashboard` repo)

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add scripts/session_summary.py
git commit -m "Add Claude Code SessionStart integration reading from SQLite"
```

(Steps 2, 3, 6, 7 touch files outside any git repo tracking — `~/.claude/` isn't version-controlled, and `~/todo.md`/`~/todo.html` never were either per the original v1 design. Nothing further to commit for those.)

---

### Task 14: End-to-end manual verification

No new files — this is a final walkthrough confirming every piece works together as designed.

- [ ] **Step 1: Run the full test suite**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/personal-dashboard"
pytest -v
```

Expected: all tests pass (Tasks 2–10 contributed tests; expect ~18-20 passing).

- [ ] **Step 2: Start the server and register scheduled tasks**

```bash
python app.py
```

(in a separate terminal)

```powershell
powershell -File scripts\register-scheduled-tasks.ps1
```

- [ ] **Step 3: Capture via the browser quick-add form**

Open `http://localhost:5151/quick-add`, capture "Test item from browser." Confirm a toast fires and it appears in the dashboard's Inbox.

- [ ] **Step 4: Capture via the AutoHotkey hotkey**

Run `hotkey/quick-capture.ahk`, press Ctrl+Alt+T, capture "Test item from hotkey." Confirm a toast fires and it appears in the dashboard's Inbox.

- [ ] **Step 5: Triage both items**

On the dashboard, set "Test item from browser" to Task/High and "Test item from hotkey" to Question. Confirm they move into the correct sections.

- [ ] **Step 6: Complete an item**

Click the checkbox on the High task. Confirm it moves to Completed, muted and struck through.

- [ ] **Step 7: Verify the daily digest**

```powershell
Start-ScheduledTask -TaskName "PersonalDashboard-DailyDigest"
```

Confirm a toast summarizing open items appears.

- [ ] **Step 8: Verify Claude Code's session summary reads the same data**

```bash
python "C:/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/session_summary.py"
```

Confirm the High/Medium tasks and Inbox count printed match what's shown on the dashboard.

- [ ] **Step 9: Clean up test items**

Delete "Test item from browser" and "Test item from hotkey" from the database (mark completed via the dashboard, or `sqlite3 dashboard.db "DELETE FROM items WHERE text LIKE 'Test item from%'"`), so the real dashboard starts clean.
