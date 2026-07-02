# Design Spec: Personal Capture & Todo Dashboard v2

**Date:** 2026-07-02
**Status:** Approved
**Author:** Brian Fox + Claude
**Supersedes:** `2026-04-14-daily-todo-dashboard-design.md`

---

## Overview

A personal task/note capture system replacing the v1 markdown + static-HTML dashboard, which failed in practice because it depended on a manual sync step that never reliably happened, and couldn't handle the real capture pattern: someone drops by the office, something needs to be jotted down with context fast, sorted properly later.

v2 is a small local web application: one Flask server, one SQLite database, two capture paths, one interactive dashboard, and scheduled Windows notifications.

---

## Why v1 failed (context for this rebuild)

- `todo.html` was a static file Claude was supposed to manually re-render "whenever the task list changes" — nothing enforced this, so it sat frozen for 2.5 months (April 16 → July 2026) despite a memory note explicitly telling future sessions to remember the sync step
- No capture mechanism existed outside asking Claude in a live Claude Code session — didn't match the real pattern (a verbal request in the office needs instant jotting, not opening VS Code)
- No way to mark things done except asking Claude or hand-editing markdown
- No reminders at all — a purely passive file nobody was prompted to check

---

## Goals

- **Frictionless capture** — type it and move on, no decisions required at the moment of capture
- **Preserve context** — who asked, when, what it relates to — captured automatically or with minimal typing, so it's never lost between "someone mentions it" and "you look at it again"
- **Two capture paths** — a pinned browser tab (quick-add form) and a global hotkey popup (AutoHotkey), both landing in the same place
- **Later triage** — raw captures start in an Inbox; sorting into Task / Question / Idea (and priority, for Tasks) happens on your own time, not forced at capture
- **Real interactivity** — check items off directly in the dashboard; no asking Claude, no hand-editing files
- **Reminders** — instant capture confirmation, a daily digest, and stale-High-Task nagging, via Windows toast notifications
- **Don't block the future** — architecture should not preclude AI-assisted triage, proactive surfacing (calendar/email/Teams), or a conversational capture interface — none of which are being built now

---

## Architecture

```
┌─────────────────────┐     ┌───────────────────────┐
│  Browser tab          │     │  AutoHotkey hotkey     │
│  (quick-add form +    │     │  popup (global          │
│  dashboard)           │     │  shortcut, any app)     │
└──────────┬────────────┘     └───────────┬─────────────┘
           │  HTTP                          │  HTTP POST
           ▼                                ▼
     ┌───────────────────────────────────────────┐
     │   Local Flask server (localhost)            │
     │   - Dashboard route (view + complete)       │
     │   - Quick-add route                         │
     │   - Capture API (POST /capture)              │
     │   - Triage API (PATCH /items/:id)            │
     └──────────────────┬──────────────────────────┘
                         │
                         ▼
                 ┌────────────────┐
                 │   SQLite DB      │
                 │   (items table)  │
                 └────────────────┘
                         ▲
          ┌──────────────┴───────────────┐
          │                               │
   Windows Task Scheduler          Claude Code
   (daily digest, stale-item        (reads/writes via
   check → toast notification)      API or direct SQLite,
                                     session-start summary)
```

The Flask server auto-starts at login via Windows Task Scheduler (same pattern as the `projects/fabric-monitoring/` scripts). It's the single point of truth for reads and writes — the browser dashboard, the hotkey popup, the scheduled reminder checks, and Claude Code all go through it (or its underlying SQLite database) rather than each keeping their own copy of the data.

---

## Data model

SQLite table `items`:

| Column | Type | Notes |
|---|---|---|
| `id` | integer, PK | auto |
| `text` | text | the captured content |
| `who` | text, nullable | who asked / context source |
| `notes` | text, nullable | additional context |
| `type` | text | `inbox` \| `task` \| `question` \| `idea` — starts `inbox` |
| `priority` | text, nullable | `high` \| `medium` \| `low` — only meaningful once `type=task` |
| `status` | text | `open` \| `completed` |
| `captured_at` | timestamp | set on insert |
| `triaged_at` | timestamp, nullable | set when moved out of inbox |
| `completed_at` | timestamp, nullable | set on completion |

---

## Capture flow

1. Browser quick-add form or AutoHotkey popup submits `text` (+ optional `who`/`notes`) to `POST /capture`
2. Server inserts a row with `type=inbox`, `status=open`, `captured_at=now`
3. A Windows toast fires immediately confirming the capture (e.g., "Captured: Fix slicer on branch 5 page")

---

## Triage flow

- Dashboard shows an **Inbox** section for untriaged items
- Each Inbox item has inline controls to assign `type` (Task / Question / Idea) and, if Task, `priority` — a `PATCH /items/:id` call, sets `triaged_at=now`
- Once triaged, the item moves into the appropriate dashboard section (Tasks grouped by priority, Questions, Ideas)

---

## Dashboard

- Sections: Inbox (untriaged), Tasks (by High/Medium/Low), Questions, Ideas, Completed (muted, collapsible)
- Every item has a real checkbox — clicking calls `PATCH /items/:id` with `status=completed`, `completed_at=now`, and the item moves to Completed immediately (small amount of client-side JS, no full page reload)
- Keeps the current dark-theme visual style (status colors paired with text labels, never color-alone) — not being redesigned, it already works

---

## Reminders (Windows toast notifications, via scheduled tasks)

- **Instant capture confirmation** — fired by the server itself immediately after a successful `POST /capture`
- **Daily digest** — scheduled task queries open items grouped by type/priority, fires a summary toast at **7:00 AM** (matching the existing pipeline-monitoring schedule's morning check-in; easy to change)
- **Stale-item nagging** — scheduled task queries open High-priority Tasks where `triaged_at` (or `captured_at` if still untriaged) is older than **3 days**, fires a toast listing them (threshold configurable)
- All three reuse the existing Windows Task Scheduler pattern already proven out in `projects/fabric-monitoring/`

---

## Claude Code integration

- Claude can add/query/complete items via the same API (or direct SQLite access) when asked mid-conversation, same as today's natural-language interaction
- The `SessionStart` hook is updated to query SQLite instead of parsing `todo.md`, surfacing open High/Medium Task items — and now also flags anything sitting untriaged in Inbox
- `todo.md` / `todo.html` and their sync hooks (`render_todo_html.py`, `todo-html-sync.sh`, the `SessionStart`/`PostToolUse` entries in `~/.claude/settings.json` added 2026-07-01) are retired once v2 is live, replaced by the new server-rendered dashboard and SQLite-aware `SessionStart` hook

---

## Error handling

- If the Flask server isn't running when the hotkey popup or browser form tries to submit, the capture would otherwise be silently lost — the Task Scheduler entry that starts it at login should be configured to restart on failure, and the AutoHotkey script should show a clear error (not fail silently) if the POST fails
- SQLite is appropriate for this single-user, single-machine workload — no concurrency handling worth engineering around

---

## File locations (proposed — needs confirmation)

Unlike v1 (two files at `C:/Users/bfox/`), this is real application code that should be version-controlled. Proposed: a new sibling repo, `C:/Users/bfox/Documents/Git-Projects/personal-dashboard/`, separate from `data-projects` since this isn't Power BI/Fabric work. To be confirmed before the implementation plan is written.

---

## Out of scope for v2 (deliberately deferred — architecture doesn't block any of these)

- AI-assisted triage suggestions
- Proactive surfacing tied to calendar/email/Teams (Graph API integration)
- Conversational capture interface
- Phone/remote access
- Teams-based reminders (toast is the v2 default; the existing fabric-monitoring Graph pattern is available to add later without architecture changes)

---

## Success criteria

- A quick note (from either capture path) is saved and confirmed within 2 seconds, with no forced decisions at capture time
- Triage takes under 10 seconds per item from the dashboard
- Completing an item is a single click, reflected immediately, no Claude interaction needed
- Daily digest and stale-item nagging fire reliably without manual triggering
- Context (who/when) is never lost between capture and triage
