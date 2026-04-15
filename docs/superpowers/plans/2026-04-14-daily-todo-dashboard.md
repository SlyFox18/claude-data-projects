# Daily To-Do Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal daily task dashboard — a markdown file Claude reads/writes and a polished HTML viewer Brian opens in his browser each morning.

**Architecture:** Two files at `C:/Users/bfox/` — `todo.md` (data, human-readable) and `todo.html` (rendered viewer, Claude regenerates whenever the markdown changes). CLAUDE.md updated to surface open High/Medium tasks at every session start.

**Tech Stack:** Plain Markdown, standalone HTML/CSS (no dependencies, no server, no build step)

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `C:/Users/bfox/todo.md` | Task data file — source of truth |
| Create | `C:/Users/bfox/todo.html` | Polished viewer — open in browser, refresh to reload |
| Modify | `C:/Users/bfox/Documents/Git-Projects/data-projects/CLAUDE.md` | Add session-start todo protocol |

---

## Task 1: Create `todo.md` with starter content

**Files:**
- Create: `C:/Users/bfox/todo.md`

- [ ] **Step 1: Create the markdown file**

Write `C:/Users/bfox/todo.md` with this exact content:

```markdown
# Todo

## High
- [ ] Set up and test daily todo dashboard | Open todo.html in browser to verify it looks right

## Medium
- [ ] Discuss GPS Power App scope with stakeholder
- [ ] Review pipeline run — confirm data is fresh after weekend

## Low
- [ ] Update Obsidian KB with Inspections report changes

## Completed
- [x] Design and spec daily todo dashboard
```

**Format rules (for Claude's reference when editing this file):**
- Task line: `- [ ] Task text` or `- [ ] Task text | Notes text`
- Pipe `|` separates task from optional notes
- Completed: change `[ ]` to `[x]` and move line to `## Completed` section
- Three priority sections only: `## High`, `## Medium`, `## Low`

- [ ] **Step 2: Verify the file is readable**

Open `C:/Users/bfox/todo.md` in VS Code and confirm it renders cleanly as markdown.

- [ ] **Step 3: Commit**

This file lives outside the repo — no commit needed. Proceed to Task 2.

---

## Task 2: Create `todo.html` — the polished viewer

**Files:**
- Create: `C:/Users/bfox/todo.html`

This file is a **complete self-contained HTML snapshot**. Claude regenerates the entire file each time `todo.md` changes. The HTML below is the template — substitute actual task content from `todo.md` when regenerating.

- [ ] **Step 1: Write the HTML viewer**

Write `C:/Users/bfox/todo.html` with this content (substituting the real tasks from todo.md):

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Brian's Daily Focus</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #020817; color: #f1f5f9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 32px 24px; min-height: 100vh; }
  .dashboard { max-width: 820px; margin: 0 auto; background: #0f172a; border-radius: 10px; overflow: hidden; border: 1px solid #1e293b; }
  .header { background: #1e293b; padding: 14px 20px; display: flex; align-items: center; justify-content: space-between; }
  .header-title { color: #f1f5f9; font-weight: 600; font-size: 1rem; }
  .header-date { color: #64748b; font-size: .8rem; }
  .section { padding: 12px 20px 8px; }
  .section + .section { border-top: 1px solid #1e293b; }
  .priority-label { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: .7rem; font-weight: 700; letter-spacing: .08em; margin-bottom: 8px; }
  .high   { background: #ef444422; color: #ef4444; }
  .medium { background: #f59e0b22; color: #f59e0b; }
  .low    { background: #22c55e22; color: #22c55e; }
  .task-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1px; background: #1e293b; border-radius: 6px; overflow: hidden; margin-bottom: 4px; }
  .task-cell { background: #0f172a; padding: 9px 14px; display: flex; align-items: center; gap: 10px; font-size: .9rem; }
  .notes-cell { background: #080f1a; padding: 9px 14px; display: flex; align-items: center; font-size: .82rem; color: #64748b; }
  .no-notes { color: #334155; font-style: italic; }
  .checkbox { font-size: .95rem; flex-shrink: 0; }
  .completed-section { padding: 12px 20px 8px; border-top: 1px solid #1e293b; opacity: .5; }
  .completed-label { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: .7rem; font-weight: 700; letter-spacing: .08em; margin-bottom: 8px; background: #1e293b; color: #475569; }
  .task-done { text-decoration: line-through; color: #475569; }
  .footer { padding: 8px 20px; background: #1e293b; border-top: 1px solid #0f172a; display: flex; gap: 20px; align-items: center; }
  .footer span { color: #64748b; font-size: .78rem; }
  .footer .right { margin-left: auto; }
</style>
</head>
<body>
<div class="dashboard">

  <div class="header">
    <span class="header-title">📋 Brian's Daily Focus</span>
    <span class="header-date"><!-- DATE --></span>
  </div>

  <!-- HIGH PRIORITY -->
  <div class="section">
    <span class="priority-label high">HIGH</span>
    <div class="task-row">
      <div class="task-cell"><span class="checkbox">⬜</span>Set up and test daily todo dashboard</div>
      <div class="notes-cell">Open todo.html in browser to verify it looks right</div>
    </div>
  </div>

  <!-- MEDIUM PRIORITY -->
  <div class="section">
    <span class="priority-label medium">MEDIUM</span>
    <div class="task-row">
      <div class="task-cell"><span class="checkbox">⬜</span>Discuss GPS Power App scope with stakeholder</div>
      <div class="notes-cell no-notes">No notes</div>
    </div>
    <div class="task-row">
      <div class="task-cell"><span class="checkbox">⬜</span>Review pipeline run — confirm data is fresh after weekend</div>
      <div class="notes-cell no-notes">No notes</div>
    </div>
  </div>

  <!-- LOW PRIORITY -->
  <div class="section">
    <span class="priority-label low">LOW</span>
    <div class="task-row">
      <div class="task-cell"><span class="checkbox">⬜</span>Update Obsidian KB with Inspections report changes</div>
      <div class="notes-cell no-notes">No notes</div>
    </div>
  </div>

  <!-- COMPLETED -->
  <div class="completed-section">
    <span class="completed-label">COMPLETED</span>
    <div class="task-row">
      <div class="task-cell"><span class="checkbox">✅</span><span class="task-done">Design and spec daily todo dashboard</span></div>
      <div class="notes-cell no-notes">No notes</div>
    </div>
  </div>

  <div class="footer">
    <span>4 open</span>
    <span>1 completed</span>
    <span class="right"><!-- TIMESTAMP --></span>
  </div>

</div>
</body>
</html>
```

**How to fill in `<!-- DATE -->` and `<!-- TIMESTAMP -->`:** When Claude regenerates this file, it writes the current date (e.g., `Monday, April 14, 2026`) and current time (e.g., `Last updated: 8:12 AM`) into those comment slots. Use Bash `date` command if needed: `date "+%A, %B %-d, %Y"` for the date, `date "+%-I:%M %p"` for the time.

- [ ] **Step 2: Open in browser and verify**

Open `C:/Users/bfox/todo.html` in your browser (double-click the file or drag to browser). Confirm:
- Dark background, task rows visible
- High/Medium/Low sections with correct colors (red/amber/green)
- Two-column layout: task left, notes right
- Footer shows correct counts
- Completed section shows strikethrough task

- [ ] **Step 3: No commit needed**

File lives outside the repo. Proceed to Task 3.

---

## Task 3: Update CLAUDE.md — session-start todo protocol

**Files:**
- Modify: `C:/Users/bfox/Documents/Git-Projects/data-projects/CLAUDE.md`

- [ ] **Step 1: Read the current session start protocol in CLAUDE.md**

Find the `### Session Start Protocol` section (currently around line 100–120). It ends with a `Flag any of these conditions` block.

- [ ] **Step 2: Add todo reading to the session start protocol**

After the existing "Flag any of these conditions" block, add this new block:

```markdown
### Daily To-Do Check (run at every session start)

After the git orientation check, read `C:/Users/bfox/todo.md` and print open High and Medium items in this format:

```
📋 Your open tasks:
  HIGH   Meet with HR re: Technician Pay data access
  HIGH   Review pipeline run — Friday data looked stale
  MEDIUM Minor adjustment to Customer Anatomy — slicer width
```

Only show High and Medium. Skip Low and Completed. If the file doesn't exist yet, skip silently.
```

- [ ] **Step 3: Commit the CLAUDE.md change**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add CLAUDE.md
git commit -m "feat: add daily todo check to session start protocol"
```

---

## Task 4: Document how Claude manages the list

**Files:**
- Create: `C:/Users/bfox/TODO-README.md`

This is a quick reference so the rules for editing the list are always findable.

- [ ] **Step 1: Write the reference file**

Write `C:/Users/bfox/TODO-README.md`:

```markdown
# Daily To-Do — Quick Reference

## Files
- `todo.md` — edit this directly OR ask Claude to update it
- `todo.html` — open in browser; Claude regenerates this whenever todo.md changes

## Asking Claude to manage your list

| What you want | What to say |
|--------------|-------------|
| Add a task | "Add 'Fix report slicer' as medium with note 'John asked for this'" |
| Complete a task | "Mark the HR meeting task as done" |
| Reprioritize | "Move the Obsidian KB item to medium" |
| See your list | "What's on my todo list?" |
| Clear completed | "Clear the completed section" |

When Claude updates todo.md it also regenerates todo.html automatically.

## Markdown format
```
- [ ] Task text
- [ ] Task text | Optional notes here
- [x] Completed task
```

Sections: `## High`, `## Medium`, `## Low`, `## Completed`
```

- [ ] **Step 2: No commit needed** — file lives outside the repo.

---

## Regeneration Reference (for Claude)

When Brian asks Claude to update the todo list, Claude must:

1. Read `C:/Users/bfox/todo.md`
2. Edit `todo.md` with the requested change (add/complete/reprioritize)
3. Regenerate `C:/Users/bfox/todo.html` from scratch using the HTML template in Task 2 Step 1, substituting actual tasks from the updated `todo.md`
4. Fill `<!-- DATE -->` with today's date and `<!-- TIMESTAMP -->` with current time

The footer counts must be accurate: count `- [ ]` lines across all priority sections for "open", count `- [x]` lines in `## Completed` for "completed".

---

## Done

When all tasks are complete:
- `C:/Users/bfox/todo.md` exists with starter tasks
- `C:/Users/bfox/todo.html` opens cleanly in the browser showing the v2 mockup layout
- `C:/Users/bfox/TODO-README.md` exists as a quick reference
- CLAUDE.md surfaces High/Medium tasks at every future session start
- CLAUDE.md change committed to `dev`
