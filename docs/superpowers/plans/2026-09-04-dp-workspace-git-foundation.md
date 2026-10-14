# DP Workspace, Variable Library & Git Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the 4 new Fabric workspaces for the bronze/silver/gold backend redesign (`DP - Staging - Dev/Prod`, `DP - Presentation - Dev/Prod`), connect each to `fabric-workspace-docs` with the correct branch from creation, and scaffold a Variable Library for environment-specific parameterization — the foundation every later plan (bronze shortcuts, silver, gold, report deployment) builds on.

**Architecture:** 4 workspaces on the `fabric1cap1` (F8) capacity, each git-connected to `fabric-workspace-docs` under `/workspaces/<workspace name>` (Dev workspaces → `dev` branch, Prod workspaces → `main` branch — correct from day one, unlike the existing report workspaces). A single Variable Library item (created in `DP - Staging - Dev`, the first workspace touched each session) holds environment-specific values (workspace/lakehouse GUIDs) with `Dev` and `Prod` value sets.

**Tech Stack:** Microsoft Fabric CLI (`fab`), Fabric portal (workspace creation is CLI-scriptable, but Git connection and Variable Library creation are done in the portal — no verified CLI syntax for those two operations, and this plan does not guess at unverified commands).

---

### Task 1: Create the 4 workspaces and assign capacity

**Files:** none (Fabric tenant infrastructure, no local files)

- [ ] **Step 1: Create `DP - Staging - Dev` with capacity assigned at creation**

**Corrected 2026-09-04 during execution:** the installed `fab` CLI version requires the capacity to be specified at `mkdir` time via the `-P capacityName=` custom parameter — a separate `fab assign` call after an unqualified `mkdir` fails with `[InvalidInput] The specified capacity was not found or is invalid`. Confirmed via `fab mkdir "test.Workspace" -P` (lists `capacityName` as the only optional param for the `.Workspace` item type).

Run:
```
fab mkdir "DP - Staging - Dev.Workspace" -P capacityName=fabric1cap1
```
Expected: command completes with no error, and the workspace appears in `fab ls`, already on the `fabric1cap1` capacity (verify with `fab get "DP - Staging - Dev.Workspace" -q "capacityId"` returning a non-null value — no separate assignment step needed).

- [ ] **Step 2: Repeat Step 1 for the other 3 workspaces**

Run each of these three commands in turn:
```
fab mkdir "DP - Staging - Prod.Workspace" -P capacityName=fabric1cap1
fab mkdir "DP - Presentation - Dev.Workspace" -P capacityName=fabric1cap1
fab mkdir "DP - Presentation - Prod.Workspace" -P capacityName=fabric1cap1
```
Expected: all three commands complete with no error.

- [ ] **Step 3: Verify all 4 workspaces exist and are on the right capacity**

Run:
```
fab ls | grep "DP -"
```
Expected output: 4 lines, one per workspace:
```
DP - Presentation - Dev.Workspace
DP - Presentation - Prod.Workspace
DP - Staging - Dev.Workspace
DP - Staging - Prod.Workspace
```

If any workspace is missing, re-run its `mkdir -P capacityName=fabric1cap1` command from Step 1 or 2 before continuing — do not proceed to Task 2 with a missing workspace.

---

### Task 2: Connect each workspace to git

**Files:** none (Fabric portal action)

Do this once per workspace, 4 times total. `fabric-workspace-docs` (GitHub, owner `SlyFox18`) is the target repo for all 4, matching every other Fabric-integrated workspace already in this tenant.

**⚠️ Confirmed gotcha (found during execution 2026-09-04):** the actual connect dialog is **Workspace settings → Git integration**, with three fields: Repository URL, Branch (dropdown), and **Git folder** (a text box, placeholder "Enter name of folder"). This last field is easy to skip — leaving it blank connects the workspace to the **root** of the repo, not a scoped subfolder. On a repo this size that means Fabric queues up hundreds of unrelated items from every other workspace as "pending updates" (280, in the case hit here) and can trigger spurious Logical ID conflicts on hidden system items (like `DataflowsStagingLakehouse`) that exist identically-named-but-differently-IDed across multiple unrelated workspace folders. **If "Updates" shows anything more than a handful right after connecting, do not click Update All** — disconnect and reconnect with the Git folder field actually filled in. Also: type the folder **without** a leading slash (`workspaces/DP - Staging - Dev`, not `/workspaces/DP - Staging - Dev`) — the leading slash only shows up in the API's `directoryName` response, not in what the field itself expects.

- [ ] **Step 1: Connect `DP - Staging - Dev` to `dev`**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Workspace settings → **Git integration**
3. Confirm the connected account shows the existing GitHub connection already used by every other workspace in this tenant (do not log into/add a new GitHub account)
4. Repository URL: `https://github.com/SlyFox18/fabric-workspace-docs`
5. Branch: `dev`
6. **Git folder: `workspaces/DP - Staging - Dev`** (no leading slash — see gotcha above)
7. Select **Connect and sync**
8. **Immediately check the Updates count** in the Source control panel before doing anything else. Expect 0 or near-0 (this is a brand-new empty folder — nothing should be pending). If it shows a large number, you hit the gotcha above — disconnect and redo Step 6 with the folder field actually filled in.
9. Since this is a brand-new empty workspace and the `dev` branch has no folder at this path yet, there's nothing to pull — no further action needed once Updates shows 0

- [ ] **Step 2: Verify via CLI**

Run:
```
fab api -A fabric "workspaces/<DP - Staging - Dev workspace ID>/git/connection"
```
(Get the workspace ID first with `fab get "DP - Staging - Dev.Workspace" -q "id"` if you don't already have it noted from Task 1.)

Expected: JSON response contains
```
"branchName": "dev"
"directoryName": "/workspaces/DP - Staging - Dev"
"gitConnectionState": "ConnectedAndInitialized"
```

- [ ] **Step 3: Repeat Steps 1-2 for the other 3 workspaces**

| Workspace | Branch |
|---|---|
| `DP - Staging - Prod` | `main` |
| `DP - Presentation - Dev` | `dev` |
| `DP - Presentation - Prod` | `main` |

Git folder for each: `workspaces/<workspace name>`, no leading slash (matching its own name, same convention as above). Check the Updates count immediately after each connect, same as Step 1.8.

**Do not proceed to Task 3 until all 4 workspaces show `gitConnectionState: "ConnectedAndInitialized"` with the correct branch** — a wrong branch binding here is exactly the mistake found in the existing report workspaces during the September 2026 git audit, and this plan exists specifically to not repeat it.

---

### Task 3: Create the Variable Library

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the Variable Library item**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. **New item** → **Variable library**
3. Name it `DP - Environment Config`
4. Select **Create**

- [ ] **Step 2: Define the variables**

Add two variables (type **String** for both, since the Fabric IDs used elsewhere in this repo's `.pq` files are 36-character GUID strings, not the dedicated GUID variable type, for consistency with how they're referenced today):
- `staging_lakehouse_id`
- `presentation_lakehouse_id`

(Only these two for now — this plan creates the library and proves the mechanism works. Later plans, once the Staging and Presentation lakehouses actually exist with real IDs, add the values. Do not fill in placeholder/fake GUID values now — an empty variable with no value set yet is the correct state for this task.)

- [ ] **Step 3: Create the `Dev` and `Prod` value sets**

In the Variable Library's value-set panel, create two value sets named exactly `Dev` and `Prod` (case-sensitive — `fabric-cicd` and deployment pipelines match value-set names to environment names exactly, per Fabric CI/CD documentation). Leave both variables' values blank in both sets for now.

- [ ] **Step 4: Commit the Variable Library to git**

In `DP - Staging - Dev`'s workspace view, use **Source control** → **Commit** to push the new Variable Library item to the `dev` branch.

- [ ] **Step 5: Verify the commit landed**

Run:
```
git -C "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" fetch origin dev
git -C "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" log origin/dev --oneline -3 -- "workspaces/DP - Staging - Dev"
```
Expected: at least one commit touching `workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary`.

---

### Task 4: Record the new topology and do end-to-end verification

**Files:**
- Create: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Write the reference doc**

```markdown
# Data Platform Workspace Reference

Created 2026-09-04 as part of the JD Bronze migration / data platform redesign
(see `docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md`).

| Workspace | Workspace ID | Purpose | Git branch | Capacity |
|---|---|---|---|---|
| DP - Staging - Dev | `<fill in from fab get>` | Bronze shortcuts + silver (dev) | dev | fabric1cap1 (F8) |
| DP - Staging - Prod | `<fill in from fab get>` | Bronze shortcuts + silver (prod) | main | fabric1cap1 (F8) |
| DP - Presentation - Dev | `<fill in from fab get>` | Gold + semantic models (dev) | dev | fabric1cap1 (F8) |
| DP - Presentation - Prod | `<fill in from fab get>` | Gold + semantic models (prod) | main | fabric1cap1 (F8) |

Variable Library: `DP - Environment Config` (lives in DP - Staging - Dev, git-synced
to all consumers via the shared `fabric-workspace-docs` repo). Value sets: `Dev`, `Prod`.
Variables defined so far: `staging_lakehouse_id`, `presentation_lakehouse_id` (values
not yet populated — set once the Staging/Presentation lakehouses are created in a
later plan).
```

Fill in the 4 real workspace IDs by running `fab get "<workspace name>.Workspace" -q "id"` for each before saving.

- [ ] **Step 2: Commit the reference doc**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Add data platform workspace reference doc

Records the 4 new DP workspaces created for the JD Bronze migration
backend redesign, their git branch bindings, and the Variable Library
scaffold.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

- [ ] **Step 3: Final end-to-end check**

Run:
```
fab ls | grep "DP -"
```
For each of the 4 workspaces, run:
```
fab api -A fabric "workspaces/<workspace ID>/git/connection" -q "text.gitConnectionState"
```
Expected: `"ConnectedAndInitialized"` for all 4, with each one's `branchName` matching the table in Step 1 (Dev workspaces → `dev`, Prod workspaces → `main`).

If any workspace shows a different branch than intended, **do not proceed to Plan 2 (Bronze Shortcuts)** — fix the git connection first (Workspace settings → Git integration → Disconnect, then reconnect with the correct branch per Task 2).
