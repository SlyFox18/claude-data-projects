# Git Workflow Cheat Sheet — Data Projects

## The Two Repos

| Repo | GitHub | Purpose |
|------|--------|---------|
| `data-projects` | SlyFox18/claude-data-projects | Your working repo — queries, docs, TMDL files |
| `fabric-workspace-docs` | SlyFox18/fabric-workspace-docs | Fabric's Git Integration mirror — auto-syncs FROM Fabric |

## The Two Branches

| Branch | Fabric Workspace | Use For |
|--------|-----------------|---------|
| `dev` | RP - Sandbox, RP - Parts Reports | Active development and testing |
| `main` | RP - Service Reports, RP - Financial Reports | Production — requires PR to push |

---

## Standard Workflow (Step by Step)

### 1. Make your changes
Edit TMDL files, DAX measures, Power Query, docs — whatever the task is.
If you changed something in Fabric directly (published from Desktop, edited in the browser),
Fabric may have already committed to the dev branch in fabric-workspace-docs automatically.

### 2. Check what changed
```bash
git status          # shows modified/untracked files
git diff            # shows the actual line-by-line changes
```

### 3. Stage the files you want to commit
```bash
# Stage specific files (preferred — avoids accidentally committing unrelated stuff)
git add "path/to/file.tmdl"
git add "path/to/another/file.json"

# Stage everything in a folder
git add "projects/transfers - report/"

# Stage ALL tracked modified files (use only when everything is intentional)
git add -u
```

### 4. Commit with a descriptive message
```bash
git commit -m "Short description of what changed and why"
```

**Good commit messages:**
- `Transfers: add Page 2 branch comparison chart`
- `Fix Data Refresh UTC timezone bug across all reports`
- `Parts on Open Orders: correct branch slicer to include all locations`

**Keep commits focused** — one logical change per commit makes it easier to understand history
and revert individual things if needed.

### 5. Push to dev
```bash
git push origin dev
```
→ Fabric auto-syncs RP - Sandbox (and RP - Parts Reports) within a minute or two.

### 6. Validate in Sandbox
- Open the report in RP - Sandbox
- Refresh the semantic model
- Spot-check the visuals, measures, slicers
- Verify the Data Refresh timestamp shows correct Central Time

### 7. Promote to production (PR)
When you're satisfied with sandbox testing:

**Option A — GitHub UI (easiest):**
1. Go to github.com/SlyFox18/claude-data-projects
2. Click "Compare & pull request" (appears after a push to dev)
3. Base: `main` ← Compare: `dev`
4. Fill in the PR template (reports changed, testing notes)
5. Click "Create pull request" → then "Merge pull request"
6. Repeat for fabric-workspace-docs

**Option B — Claude Code:**
```
/promote-sandbox "report name"
```

---

## Useful Git Commands

```bash
# See recent commit history
git log --oneline -10

# See what's different between dev and main
git diff main..dev --stat

# Undo staged changes (before commit)
git restore --staged "path/to/file"

# Undo file changes entirely (CAREFUL — loses your edits)
git restore "path/to/file"

# Check which branch you're on
git branch
```

---

## When Fabric Pushes Changes to the Repo

Fabric's Git Integration sometimes auto-commits to `fabric-workspace-docs/dev` when you
publish from Power BI Desktop or make changes in the browser. Before pushing your local
changes, always pull first to avoid conflicts:

```bash
cd "c:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git pull origin dev   # get Fabric's auto-commits first
git push origin dev   # then push yours
```

---

## Quick Reference — Common Scenarios

| Scenario | What to do |
|----------|-----------|
| Made DAX/visual changes in Desktop, published | Pull fabric-workspace-docs, commit data-projects changes, push both |
| Made TMDL edits directly in VS Code | Commit data-projects, push to dev, update fabric-workspace-docs manually or let Fabric sync |
| Ready to go to production | Open PR dev → main on both repos |
| Need to fix something in production only | Still use dev → test → PR. Never commit directly to main |
| Fabric has changes you don't have locally | `git pull origin dev` before your push |

---

## The Golden Rules

1. **Always work on `dev`** — never commit directly to `main`
2. **Commit early and often** — small focused commits are better than one giant one
3. **Pull before push** (especially fabric-workspace-docs) — Fabric may have auto-committed
4. **Test in Sandbox before PR** — once it's in main, production reports are affected
5. **New reports use the template** — copy from `.claude/queries/DATA-REFRESH-TEMPLATE.pq` for the Data Refresh table
