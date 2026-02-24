# Fabric Monitoring — Scheduled Tasks

## Overview

**Location:** `data-projects/projects/fabric-monitoring/`

Two Windows scheduled tasks handle automated Fabric monitoring:

| Task | Schedule | Script | Purpose |
|------|----------|--------|---------|
| `\Fabric\Post-Pipeline Monitoring` | 6:00 AM Mon-Fri | `scripts/scheduled/Run-PostPipeline-Monitoring.ps1` | Inventory, refresh history, CU tracking, push docs to dev, Teams notification |
| `\Fabric\Azure Login Refresh` | 7:00 AM Mon-Fri | `scripts/Startup-AzureLogin.ps1` | Keep cached Azure context alive for next day's token requests |

---

## One-Time Setup (Required Before First Run)

### Step 1 — Save your Azure context

Open PowerShell as your **normal user** (not Administrator) and run:

```powershell
Connect-AzAccount
Save-AzContext -Path "$env:USERPROFILE\.azure\AzureRmContext.json" -Force
```

This saves your credentials so future token requests work without a browser prompt.
You may need to redo this if your organization forces MFA re-enrollment (typically every 90 days).

### Step 2 — Verify the token works

```powershell
& "C:\Users\bfox\Documents\Git-Projects\data-projects\projects\fabric-monitoring\scripts\scheduled\Get-FreshToken.ps1"
```

You should see a long token string returned. If you get an error, fix it before proceeding.

### Step 3 — Set up Teams notifications (optional)

1. Go to [flow.microsoft.com](https://flow.microsoft.com) → **Create** → **Instant cloud flow**
2. Trigger: **"When an HTTP request is received"**
3. Click "Use sample payload to generate schema" and paste:
   ```json
   {"date":"2026-02-25","status":"SUCCESS","failedCount":0,"failedSteps":"","duration":"90s"}
   ```
4. Add action: **"Post message in a chat or channel"** (Teams)
5. Choose your team and channel (e.g. create a "Fabric Monitoring" channel)
6. Build the message using dynamic content:
   ```
   @{if(equals(triggerBody()?['status'], 'SUCCESS'), '✅', '❌')} Fabric Monitoring — @{triggerBody()?['date']}
   Status: @{triggerBody()?['status']}  |  Duration: @{triggerBody()?['duration']}
   @{if(greater(int(triggerBody()?['failedCount']), 0), concat('❌ Failed: ', triggerBody()?['failedSteps']), 'All steps completed successfully')}
   ```
7. **Save** the flow → copy the HTTP POST URL
8. Open `Run-PostPipeline-Monitoring.ps1` and paste the URL into the `$TeamsWebhookUrl` variable

### Step 4 — Run the monitoring script manually once

```powershell
& "C:\Users\bfox\Documents\Git-Projects\data-projects\projects\fabric-monitoring\scripts\scheduled\Run-PostPipeline-Monitoring.ps1"
```

Check for any FAIL lines. Review the log in `projects/fabric-monitoring/logs/`.

### Step 5 — Register the scheduled tasks

Open PowerShell **as Administrator** and run:

```powershell
& "C:\Users\bfox\Documents\Git-Projects\data-projects\projects\fabric-monitoring\scripts\scheduled\Register-ScheduledTasks.ps1"
```

### Step 6 — Verify in Task Scheduler

Open Task Scheduler → Task Scheduler Library → **Fabric**.
You should see both tasks. Right-click `Post-Pipeline Monitoring` → **Run** to test it.

---

## How the Token Works

Runtime token requests — no stale `.token` file:

```
Task runs at 6 AM
  → Get-FreshToken.ps1 runs
  → Loads saved Azure context from AzureRmContext.json
  → Calls Get-AzAccessToken (no browser needed)
  → Returns fresh token (valid for ~60 min)
  → Monitoring scripts use that token
  → Done
```

The Azure context file (`AzureRmContext.json`) persists across reboots and stays valid for
~90 days before MFA re-enrollment is required.

---

## What Gets Committed to Git

The monitoring task commits only to the **`dev` branch** of `data-projects`:
- `projects/fabric-monitoring/documentation/` — updated CSV files and markdown reports
- `projects/fabric-monitoring/logs/` — today's log file

It does **not** auto-merge to `main`. Review the docs in GitHub and open a PR when ready.

---

## Log Files

Location: `projects/fabric-monitoring/logs/post-pipeline-YYYY-MM-DD.log`

Example of a healthy log:
```
[2026-02-24 06:00:01] [INFO] Post-Pipeline Monitoring - Start
[2026-02-24 06:00:03] [INFO] OK:    Get fresh Fabric API token
[2026-02-24 06:00:05] [INFO] OK:    Refresh dataflow inventory
[2026-02-24 06:00:30] [INFO] OK:    Log refresh history from Fabric API
...
[2026-02-24 06:01:15] [INFO] Post-Pipeline Monitoring - COMPLETED SUCCESSFULLY
```

Example of a failure:
```
[2026-02-24 06:00:04] [ERROR] FAIL: Log refresh history from Fabric API - Connection timeout
[2026-02-24 06:01:15] [ERROR] Post-Pipeline Monitoring - COMPLETED WITH 1 FAILURE(S)
```

Task Scheduler sees a non-zero exit code and marks the task as Failed — visible in the
Task Scheduler history panel.

---

## Troubleshooting

### "No saved Azure context found"
Run `Connect-AzAccount` then `Save-AzContext` interactively (Step 1 above).

### "Authentication failed — MFA required"
Your org's MFA policy requires re-enrollment. Run `Connect-AzAccount` again interactively,
then `Save-AzContext -Force` to refresh the saved context. Typically happens every 90 days.

### "Could not switch to dev branch"
Run `git status` in the `data-projects` repo root and resolve any uncommitted changes
or merge conflicts before the next scheduled run.

### Task shows "Last Run Result: 0x1" in Task Scheduler
Exit code 1 means at least one monitoring step failed. Check the log file for `[ERROR]` lines.

### Task doesn't run at all
- Confirm the machine was on at 6 AM (or `StartWhenAvailable` picked it up later)
- Check Task Scheduler → History tab on the task for error details
- Ensure the user account is logged in (tasks use `Interactive` logon type)

### Git push fails
The task pushes to `dev` using your cached git credentials. If push fails:
- Run `git push origin dev` manually from `data-projects` to re-cache credentials
- Check that the `dev` branch exists on origin

---

## Re-Enrollment Reminder (Every 90 Days)

Set a calendar reminder every 90 days to refresh your Azure context:

```powershell
Connect-AzAccount
Save-AzContext -Path "$env:USERPROFILE\.azure\AzureRmContext.json" -Force
```

Without this, the monitoring tasks will start failing with auth errors.
