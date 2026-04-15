# Design Spec: Daily To-Do Dashboard

**Date:** 2026-04-14  
**Status:** Approved  
**Author:** Brian Fox + Claude

---

## Overview

A personal daily task dashboard consisting of two files:

1. `C:/Users/bfox/todo.md` — the data file (human-readable, Claude-writable)
2. `C:/Users/bfox/todo.html` — the viewer (open in browser, refresh to update)

At the start of each Claude Code session, Claude reads `todo.md` and surfaces open high-priority items before starting work. Claude can add, update, and complete tasks on request via natural language (e.g., "add this to my list" or "mark item 2 done").

---

## Goals

- Frictionless morning view: open `todo.html` in browser, see the day at a glance
- Claude-assisted task management: ask Claude to add/update/complete tasks without leaving Claude Code
- Manual editing: user can edit `todo.md` directly in VS Code at any time
- Presentable: clean, polished dark-theme view suitable for showing stakeholders
- Expandable: v1 is intentionally simple; designed so future enhancements don't break existing data

---

## Data Format (`todo.md`)

```markdown
# Todo

## High
- [ ] Meet with HR re: Technician Pay data access | Schedule before Thursday — they have the pay sheets
- [ ] Review pipeline run — Friday data looked stale

## Medium
- [ ] Minor adjustment to Customer Anatomy — slicer width | Requested by John — branch 5 page only
- [ ] Follow up with stakeholder on GPS Power App scope

## Low
- [ ] Update Obsidian KB with Inspections changes

## Completed
- [x] Set up daily todo dashboard
```

**Format rules:**
- Each task: `- [ ] Task text` or optionally `- [ ] Task text | Notes text`
- Pipe `|` separates task from notes (notes are optional)
- Completed items: `- [x] Task text` — moved to `## Completed` section
- Three priority sections: `## High`, `## Medium`, `## Low`
- One `## Completed` section at the bottom (cleared periodically)

---

## Viewer (`todo.html`)

A standalone HTML file that Claude regenerates from `todo.md` whenever the task list changes. No build step, no dependencies, no server required. Claude writes both files atomically — edit the markdown, then re-render the HTML. Opening `todo.html` directly in the browser always shows current state.

**Layout:**
- Dark theme matching existing Power BI work aesthetic
- Header: "Brian's Daily Focus" + current date
- Tasks grouped by priority with color-coded labels (High = red, Medium = amber, Low = green)
- Two-column rows: task text on the left, notes on the right
- Footer: open count, completed-today count, last-updated time
- "No notes" shown in muted italic when notes field is empty

**Interaction (v1):**
- No interactive checkboxes — user asks Claude to mark things done, or edits markdown directly
- Browser refresh reloads current state of `todo.md`

---

## Claude Integration

At session start, Claude reads `todo.md` and prints a brief summary of open High and Medium items before beginning work.

On request, Claude can:
- **Add a task:** "Add 'Fix slicer on branch 5 page' as medium priority with note 'John asked for this'"
- **Complete a task:** "Mark the HR meeting task as done"
- **Reprioritize:** "Move the Obsidian KB task to medium"
- **Show the list:** "What's on my todo list?"

Claude reads and writes `todo.md` directly using the Read and Edit tools.

---

## File Locations

| File | Path |
|------|------|
| Data file | `C:/Users/bfox/todo.md` |
| Viewer | `C:/Users/bfox/todo.html` |

Stored at user root (not inside any project repo) so it works across all Claude Code sessions regardless of working directory.

---

## Out of Scope (v1)

- Interactive checkboxes in the browser
- Live-updating server (no refresh needed)
- Due dates or categories
- Multiple lists or projects
- Mobile access
- Notifications or reminders

These are all candidates for v2 after using v1 for a while.

---

## Success Criteria

- Brian can open `todo.html` in the morning and see all open tasks in under 3 seconds
- Brian can ask Claude to add a task mid-conversation and it's in the file immediately
- The viewer looks polished enough to show a stakeholder without embarrassment
- The markdown file is readable and editable without any tooling
