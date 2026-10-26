---
name: wrap-up
description: End-of-session close-out across both repos (data-projects and fabric-workspace-docs). Shows what changed, commits only the files this session touched to dev, pushes dev, notes memory/doc updates, and lists next steps including any release steps still owed. Use when Brian says wrap up, end of session, or runs /wrap-up.
argument-hint: "[optional one-line summary of the session]"
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

Close out the session. Brian's summary (may be empty): **$ARGUMENTS**

Repos:
- `C:/Users/bfox/Documents/Git-Projects/data-projects` (docs, specs, plans, tools)
- `C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs` (all Fabric code, `deploy/`)

## 1. What changed
For each repo: `git -C <repo> branch --show-current`, `git -C <repo> status --short`, `git -C <repo> log origin/dev..HEAD --oneline`.
Both repos often hold **unrelated uncommitted changes of Brian's**. Sort the changes into "this session" and "not mine". Only "this session" files get staged. If unsure about a file, ask.

## 2. Checks before committing (fabric-workspace-docs only, if code changed)
- DAG config or a notebook's outputs changed: `python deploy/dag_check.py`
- `deploy/*.py` changed: `python -m pytest deploy -q`
- A Gold notebook changed: `python deploy/hygiene_audit.py`
- `dp_refresh_dag.json` changed: `python deploy/table_lineage.py` (regenerates TABLE-LINEAGE.md)
- orchestrator/notify sources changed: re-render with `python deploy/render_orchestrator.py` (never hand-edit the Run_/Notify_ notebooks)

Report failures with their output. Don't commit around them.

## 3. Commit and push dev
- Must be on `dev`. Stage named files only (`git add "<path>"`, never `-A` / `.`).
- One commit per logical change. Message: imperative summary line, then a short body on why. End with the attribution line from the current system reminder.
- `git -C <repo> push origin dev`. Never push main (a deny rule blocks it anyway).

## 4. Knowledge capture
- New error and fix → `fabric-workspace-docs/docs/TROUBLESHOOTING.md`. New business or source-data fact → `docs/BUSINESS-GLOSSARY.md`. Repo docs beat memory for shared knowledge.
- Progress on a spec or plan → update the progress notes at the top of the file in `docs/superpowers/`.
- Memory: update an existing file rather than adding a duplicate. Make sure any new file has a line in `MEMORY.md`. Move finished work out of "In Progress".

## 5. Summary for Brian
Keep it short:
- **Committed / pushed:** per repo, commit subjects.
- **Left uncommitted:** files that aren't this session's, so he knows they're still there.
- **Release steps owed** (only those that apply): Dev git sync (`python tools/dp-migration/git_sync.py <workspaceId>`) and a Dev test; `python deploy/merge_preview.py` + PR `dev → main` (Brian merges with a merge commit); "Deploy DP backend" then `python deploy/claim_prod_pipeline.py` and fast-forward dev; "Deploy reports" (sandbox, then production + org app).
- **Unfinished / follow-ups:** what's left, plus anything worth capturing as a task in Reynard (Brian's task app, quick-add at http://localhost:5151/quick-add). Suggest it; don't write to its db.
