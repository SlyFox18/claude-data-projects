# Design Spec: Personal Dashboard — Notes, Due Date, Tags, Timestamps

**Date:** 2026-07-02
**Status:** Approved
**Author:** Brian Fox + Claude
**Builds on:** `2026-07-02-todo-dashboard-v2-design.md` (v2 — the original capture/triage/dashboard build, now shipped)

---

## Overview

After using the v2 dashboard for the first time, a few real gaps showed up:

- The database already has a `notes` column, but no capture path (browser form or hotkey) ever sends one — there's no way to add context beyond a one-line item and who asked
- No way to flag a due date on anything
- No visible sense of how long something's been sitting, beyond the 3-day stale-High-Task nag
- No way to mark an item's state (blocked, waiting on info, in progress, etc.) — priority alone doesn't capture this

This round adds four related pieces: a real Notes field, an optional Due Date, a growable multi-select Tags system, and visible relative timestamps on every item.

**Explicitly out of scope for this round:** screenshot/image attachments — flagged by Brian as the biggest lift (file storage, paste/attach UI, thumbnails) and deliberately deferred to its own future round once there's a clearer sense of how often it'd actually get used.

---

## Data model

```sql
ALTER TABLE items ADD COLUMN due_date TEXT;  -- nullable, ISO date YYYY-MM-DD

CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    color TEXT NOT NULL  -- one of a fixed 6-color palette key, auto-assigned round-robin
);

CREATE TABLE item_tags (
    item_id INTEGER NOT NULL REFERENCES items(id),
    tag_id INTEGER NOT NULL REFERENCES tags(id),
    PRIMARY KEY (item_id, tag_id)
);
```

- `notes` already exists on `items` from the v2 schema — it's populated starting now, no migration needed for that column.
- `due_date` is a new nullable column, date-only (no time component), applies to any item type (Inbox/Task/Question/Idea alike) — not scoped to Tasks only.
- Tags are many-to-many via `item_tags`. The tag list grows over time — anyone can create a new tag by typing a name in the tag picker. Tag names are deduped case-insensitively (typing "blocked" when "Blocked" exists reuses the existing tag rather than creating a duplicate).
- Tag colors are auto-assigned round-robin from a fixed 6-color palette (not user-chosen) — keeps tag creation to just typing a name, no color picker UI needed.

**Migration handling:** since `dashboard.db` already exists with real data from the v2 build, `init_db()` must apply this as a safe, idempotent migration rather than assuming a fresh database:
- Check for the `due_date` column via `PRAGMA table_info(items)` before running `ALTER TABLE ... ADD COLUMN` — SQLite errors on adding a column that already exists, so this must be guarded (e.g., a try/except around the `ALTER TABLE` catching the "duplicate column" error, or checking `PRAGMA table_info` first).
- `tags` and `item_tags` use `CREATE TABLE IF NOT EXISTS`, consistent with the existing `items` table creation — safe to call on every `init_db()` invocation.
- On first migration, seed the starter tag set (see below) only if the `tags` table is empty, so re-running `init_db()` doesn't create duplicates.

**Starter tag set** (seeded once, on first migration to an empty `tags` table):

| Name | Color |
|---|---|
| Not Started | gray |
| In Progress | blue |
| Blocked | red |
| Waiting on Info | amber |
| On Hold | purple |
| Needs Follow-up | cyan |

These are a starting point, not a fixed list — new tags can be added anytime via the tag picker, and existing ones aren't locked.

---

## API changes

- `POST /capture` — gains an optional `due_date` field (ISO date string). `notes` was already accepted by the endpoint but never sent by any client — now the browser quick-add form sends it.
- `PATCH /items/<id>` — extended to accept `notes` and `due_date` in the request body (in addition to the existing `type`/`priority`/`status` fields), so either can be edited anytime from the dashboard, not just at capture time. Any subset of fields may be present; only the fields included are updated.
- `POST /tags` — body `{"name": "..."}`. Creates a tag if the name doesn't already exist (case-insensitive match), or returns the existing tag's id if it does. Auto-assigns the next color in the round-robin palette for newly created tags.
- `GET /tags` — returns all tags (id, name, color), for populating the tag picker panel.
- `POST /items/<id>/tags` — body `{"tag_id": N}`. Attaches a tag to an item (idempotent — attaching an already-attached tag is a no-op, not an error).
- `DELETE /items/<id>/tags/<tag_id>` — detaches a tag from an item.

Tags use per-tag attach/detach endpoints rather than a single "replace the whole tag set" endpoint — each click in the tag picker becomes one small, independently testable action, and the client doesn't need to track and resend full tag state on every toggle.

---

## UI behavior

**Quick-add form** (browser only — `/quick-add`) gains two fields, for four total:
1. Item text — placeholder "New Item" (was "What does John need?")
2. Who's it for (optional) — placeholder "Who's it for (optional)" (was "Who asked / context (optional)")
3. Notes (optional) — new field, placeholder "Notes (optional)"
4. Due date (optional) — new field, native date input

The hotkey popup (Ctrl+Alt+T) is unchanged — still a single-line text-only capture, for speed. Notes, due date, and tags can be added afterward from the dashboard for hotkey-captured items.

**Item rows** switch from the current single-line 3-column grid to a two-line layout:
- Line 1: item text (left) + relative timestamp (right, e.g. "2 days ago")
- Line 2: tag badges + due-date badge (if set) + who/notes summary text

This applies to every section (Inbox, Tasks by priority, Questions, Ideas) — Completed items keep their current muted single-line treatment, unchanged.

**Due date:** displayed as a badge (e.g., "📅 Due Jul 5") when set, or a ghost "+ Due date" affordance when not. Clicking it opens a small inline date picker; selecting a date (or clearing it) fires a `PATCH /items/<id>` with the new `due_date`.

**Notes:** clicking the notes area reveals a small textarea for editing; saves on blur or Enter via the same `PATCH /items/<id>` endpoint.

**Tags:** a "🏷️ Tags" button on every row (including Inbox items, so status can be set before triage if useful) opens a tag panel showing all existing tags as chips — filled/highlighted if applied to this item, outlined if not. Clicking a chip toggles it (fires `POST` or `DELETE` to the tag attach/detach endpoints immediately, no separate save step). A "+ New tag name..." input at the bottom creates a new tag and applies it to the current item in one action.

**Timestamps:** every item shows relative time since `captured_at` (e.g., "2 days ago", "3 hours ago", "just now"), computed server-side and passed into the template — not just on stale/flagged items, on all of them.

---

## Testing approach

Same TDD pattern as the original v2 build: one bite-sized task per component, tests written first.

- `db.py`: migration logic (idempotent `ALTER TABLE`/`CREATE TABLE IF NOT EXISTS`, starter tag seeding only when empty), tag CRUD functions (`create_tag`, `get_tags`, `add_tag_to_item`, `remove_tag_from_item`), extending `get_items` to include each item's tags, extending item update logic for `notes`/`due_date`
- `app.py`: new tag routes tested via the Flask test client; extended `/capture` and `PATCH /items/<id>` tested for the new optional fields
- Templates/JS: dashboard route tests confirm tag badges, due-date badges, and relative timestamps render correctly; no new JS test framework introduced (matches the existing project convention — `dashboard.js`/`quick-add.js` aren't unit tested today, verified via the Flask route tests plus manual verification)

---

## Success criteria

- Notes can be added at capture time (browser form) and edited anytime afterward, including for hotkey-captured items
- Due dates are optional on any item type, settable at capture or anytime after
- Tags are multi-select, growable without code changes, and toggleable in one click each
- Every item shows how long it's been open at a glance
- Existing `dashboard.db` data survives the upgrade untouched — migration is additive and idempotent
