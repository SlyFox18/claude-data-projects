# Git Sync Walkthrough - Deploying Pipeline Changes to Fabric

This guide walks you through committing pipeline changes in Git and syncing them to your Fabric workspace. We'll use the Pipeline_Raw_Data batching change as our first example.

---

## Prerequisites

- Your **LH_Master_Data** workspace is already connected to the `fabric-workspace-docs` Git repo
- You have the `fabric-workspace-docs` repo cloned locally at `c:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`
- The pipeline-content.json file has already been updated (Claude did this)

---

## How Fabric Git Sync Works

```
Your Local Git Repo ──push──> Remote (Azure DevOps / GitHub)
                                        │
                                    Fabric reads
                                        │
                                        ▼
                              LH_Master_Data Workspace
                              (Pipelines, Dataflows, etc.)
```

1. You edit files locally (pipeline JSON, notebook code, etc.)
2. You commit and push to the remote repository
3. In Fabric, you click **"Update from Git"** to pull the changes into the workspace
4. Fabric reads the JSON and updates the pipeline definition

**It's a one-way pull** - you choose when Fabric picks up changes. Nothing happens automatically.

---

## Step-by-Step: Deploy the Batched Pipeline_Raw_Data

### Step 1: Review the Change

Before committing, let's verify what changed. Open a terminal (PowerShell or Git Bash) and run:

```powershell
cd "c:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git status
```

You should see something like:
```
modified: workspaces/LH_Master_Data/Pipelines/Pipeline_Raw_Data.DataPipeline/pipeline-content.json
```

To see the actual diff:
```powershell
git diff "workspaces/LH_Master_Data/Pipelines/Pipeline_Raw_Data.DataPipeline/pipeline-content.json"
```

This shows exactly what changed - the new batch gates (Wait_Batch1_Gate, etc.), the dependency chains, and the timeout increases.

### Step 2: Stage the File

```powershell
git add "workspaces/LH_Master_Data/Pipelines/Pipeline_Raw_Data.DataPipeline/pipeline-content.json"
```

### Step 3: Commit

```powershell
git commit -m "Restructure Pipeline_Raw_Data into 4 sequential batches of 5-6 concurrent DFs"
```

### Step 4: Push to Remote

```powershell
git push
```

If this is your first push, Git might ask for credentials. Use your Azure DevOps / GitHub credentials.

### Step 5: Sync in Fabric

This is the step where the change actually takes effect in your workspace:

1. Open **Microsoft Fabric** in your browser
2. Navigate to the **LH_Master_Data** workspace
3. Look at the top of the workspace - you should see a **Source control** button (or a banner saying "Updates available from Git")
4. Click **Source control**
5. You'll see a list of changes from Git - the Pipeline_Raw_Data modification should appear
6. Click **"Update all"** (or select just the pipeline and click "Update")
7. Fabric will process the JSON and update the pipeline definition

### Step 6: Verify in Fabric

After the sync completes:

1. Open **Pipeline_Raw_Data** in the pipeline editor
2. You should see the new structure:
   - Batch 1 (5 DFs) starting immediatelyIs there 
   - **Wait_Batch1_Gate** connecting to Batch 2
   - **Wait_Batch2_Gate** connecting to Batch 3
   - **Wait_Batch3_Gate** connecting to Batch 4
   - **Wait_For_All_Dataflows** at the end
   - Email notifications after the final Wait
3. The visual layout might need rearranging (Fabric auto-layouts activities), but the logic will be correct

### Step 7: Test Run

Run Pipeline_Raw_Data manually to validate:

1. Click **Run** in the pipeline editor
2. Watch the monitoring view - you should see:
   - Batch 1 (5 DFs) start immediately
   - After Batch 1 completes → Batch 2 (5 DFs) starts
   - After Batch 2 completes → Batch 3 (5 DFs) starts
   - After Batch 3 completes → Batch 4 (1 active + 5 inactive) starts
3. Expected total time: **~14-16 minutes** (vs 13+ min with timeouts before)

---

## What If Something Goes Wrong?

### Sync shows conflicts
If someone edited the pipeline in Fabric UI after your last Git pull:
1. Fabric will show a conflict
2. You can choose to **accept incoming** (your Git version) or **keep workspace** (Fabric version)
3. For this change, choose **accept incoming** since we want the batched version

### Pipeline looks wrong after sync
If the pipeline doesn't look right:
1. Don't panic - Git has your history
2. In terminal: `git log --oneline -5` to see recent commits
3. Revert if needed: `git revert HEAD` then push again
4. Sync in Fabric again

### Want to undo before pushing
If you committed but haven't pushed yet:
```powershell
git reset --soft HEAD~1
```
This un-commits (but keeps your changes staged).

---

## Future Changes: The General Pattern

Whenever you need to modify a Fabric item via Git:

1. **Pull latest first:** `git pull` (in the fabric-workspace-docs repo)
2. **Make your edit** (or have Claude generate the JSON)
3. **Review:** `git diff`
4. **Commit:** `git add <file> && git commit -m "description"`
5. **Push:** `git push`
6. **Sync in Fabric:** Source control > Update all
7. **Verify:** Open the item in Fabric and check

---

## Tips

- **Always pull before editing** - `git pull` ensures you have the latest version from Fabric
- **Commit messages matter** - they help you track what changed and when
- **One change at a time** - commit pipeline changes separately from notebook changes
- **Fabric > Commit to Git** - after making changes in the Fabric UI, use "Commit to Git" to save them to the repo. This goes the other direction (workspace → Git).
- **The .platform file** - each Fabric item has a `.platform` file with its logical ID. Don't modify these unless you know what you're doing.

---

*Created: February 2026*
