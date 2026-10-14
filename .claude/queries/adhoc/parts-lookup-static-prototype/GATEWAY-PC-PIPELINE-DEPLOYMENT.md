# Parts Lookup Refresh Pipeline — Gateway PC Deployment Record

**Migrated:** 2026-08-26
**Status:** Live, running as primary on the Gateway PC, fully proven through real use. Brian's PC's equivalent scheduled task is **disabled, not deleted** — kept as a fallback. Failure alerting, a staleness check, and (as of 2026-08-31) an app-uptime check are all in place - see below.

**Note on this machine's role:** as of 2026-08-31, the Gateway PC is retired as the app's *frontend* host (see `docs/GATEWAY-PC-DEPLOYMENT.md` in `parts-lookup-app` - it had a real, hard 10-connection IIS limit that couldn't support the real user count). It kept this refresh pipeline and the Fabric on-premises Gateway service, both unrelated to that limit. The actual production frontend now runs on a separate Windows Server 2016 machine (`parts-lookup-app`'s `WINDOWS-SERVER-2016-DEPLOYMENT.md`), reachable at `https://go-parts.spitractor.com`.

This is the technical reference for what's actually running, so anyone picking this up later (including future-you) doesn't have to reconstruct it from scratch.

---

## Where it lives

| | |
|---|---|
| Machine | `SPI00T4022W11` (`10.30.100.50`) - the same Gateway PC hosting the frontend and the Fabric on-premises Gateway |
| Repo clone | `C:\data-projects` (git, tracks `dev` - matches how this pipeline is actually iterated day-to-day; unlike `parts-lookup-app`, this repo doesn't currently use a per-change `dev` → `main` PR cadence) |
| Pipeline folder | `C:\data-projects\.claude\queries\adhoc\parts-lookup-static-prototype\` |
| Scheduled tasks | `Parts Lookup Refresh` (hourly, Mon-Fri 8am-8pm), `Parts Lookup Staleness Check` (hourly, offset +45 min, same window), `Parts Availability App Uptime Check` (every 15 min, all day every day - added 2026-08-31, see below) |
| Monitoring | VS Code Remote Tunnels for live log viewing (see below), Teams alerts on failure/staleness/downtime |

## What the pipeline actually does (recap)

`run_refresh.py` → `extract.py` → `partition.py` → `upload.py`, hourly Mon-Fri 8am-8pm. No dependency on the ODBC `dsn=EquipRDB64` connection used by the Fabric Gateway's own dataflows - this pipeline reads straight from the Lakehouse via OneLake (DuckDB + Delta/Azure extensions) and writes to SharePoint via Microsoft Graph, both authenticated with one dedicated service principal (client-credentials flow, no interactive login required). See `README.md` in this folder for the original prototype design/validation, and each script's own header comment for current behavior (gzip compression, adaptive 3-char splitting, retry/timeout handling, the lock-file mechanism, etc. - all added after this doc's original prototype phase).

## One-time setup on this machine

1. **Python 3.13** via `winget install Python.Python.3.13` - wasn't present before (this machine hadn't been used for Python development).
2. **Read-only deploy key** for `claude-data-projects`, separate from the one used for `parts-lookup-app` (each repo has its own, both scoped read-only, neither can push):
   ```powershell
   ssh-keygen -t ed25519 -C "gateway-pc-data-projects-deploy" -f "$env:USERPROFILE\.ssh\id_ed25519_dataprojects_deploy" -N '""'
   ```
   Registered via `gh repo deploy-key add` against `SlyFox18/claude-data-projects`, confirmed `read_only: true`.
3. **SSH config alias** (needed because this machine now has *two* different deploy keys, both authenticating to `github.com`):
   ```
   Host github.com-dataprojects
       HostName github.com
       User git
       IdentityFile ~/.ssh/id_ed25519_dataprojects_deploy
       IdentitiesOnly yes
   ```
   Clone with `git clone git@github.com-dataprojects:SlyFox18/claude-data-projects.git C:\data-projects`, then `git checkout dev`.
4. **Pinned dependencies** - `requirements.txt` (added 2026-08-25, didn't exist before this migration) pins exact versions matching what was running on Brian's PC:
   ```
   duckdb==1.5.5
   pandas==3.0.3
   pyarrow==25.0.1
   python-dotenv==1.2.3
   msal==1.37.0
   requests==2.32.5
   ```
   `pip install -r requirements.txt` from the pipeline folder. Note `pyarrow` isn't imported directly by any script here, but `pandas.DataFrame.to_parquet()` (used by `extract.py`) needs it at runtime - easy to miss on a clean install.
5. **`.env` with the service principal credentials** - gitignored, so `git clone` never brings it over (same situation as `parts-lookup-app`'s `.env`, but this one is a *real* secret, not a public SPA client ID). Copied via RDP clipboard/Notepad directly between machines, never through chat or committed anywhere. Required keys: `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SITE_ID`, `DRIVE_ID`, `LIBRARY_BASE` (see `config.py` and `.env.example` in this folder). Must land in this exact folder - `python-dotenv`'s `load_dotenv()` looks in the current working directory, which Task Scheduler sets via its Action's "Start in" field.

   **Watch out for Notepad silently saving as `.env.txt`** - when saving, set "Save as type" to **All Files**, not the default `.txt`. Hit this for real during setup.

   **Service principal secret expiration: 2026-08-17 to 2028-08-16.** Checked via `az ad app credential list --id 678f50be-0c5a-4e5b-8b46-6357dfb30a23` on 2026-08-26. About 2 years of runway as of this migration - not urgent, but write it down now so a sudden auth failure in 2028 isn't a mystery. Whoever rotates it needs to update `.env` on **both** this machine and Brian's PC (the fallback).

## Task Scheduler configuration

Created via PowerShell rather than the GUI wizard, to exactly replicate the trigger shape already running on Brian's PC (`New-ScheduledTaskTrigger -Weekly` doesn't support `-RepetitionInterval` directly - the workaround is building a throwaway `-Once` trigger just to copy its `.Repetition` property onto the real weekly one):

```powershell
$action = New-ScheduledTaskAction -Execute "C:\Users\bfox\AppData\Local\Programs\Python\Python313\python.exe" -Argument "run_refresh.py" -WorkingDirectory "C:\data-projects\.claude\queries\adhoc\parts-lookup-static-prototype"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 8:00AM
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At 8:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Hours 12)).Repetition

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

$cred = Get-Credential -UserName "SPI\bfox" -Message "Enter your domain password - this lets the task run even when nobody's logged in"

Register-ScheduledTask -TaskName "Parts Lookup Refresh" -Action $action -Trigger $trigger -Settings $settings -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Limited
```

**Deliberately set to "run whether user is logged on or not"** (via the stored-credential `-User`/`-Password` registration above), unlike Brian's PC's task, which uses "Interactive/Background" logon mode. This machine is meant to run unattended indefinitely and could get rebooted by IT without anyone logging back in - the Fabric Gateway service itself already runs this way (as a true Windows service under `NT SERVICE\PBIEgwService`, not tied to any login session), so this matches that posture rather than the "stay logged in" assumption that happens to work fine on Brian's daily-use PC.

`Get-Credential` was used specifically to avoid the domain password ever appearing as literal text in a command or in PowerShell history - it opens a native masked-input dialog instead.

## Cutover validation (2026-08-25/26)

Two consecutive real runs confirmed clean before trusting this as primary:
- **2026-08-25, ~8:00 AM (manual, deliberately timed to when Brian's PC's task would have fired):** disabled Brian's PC's task first to remove any ambiguity about which machine did the work. 1381 files uploaded, SharePoint library confirmed updated, app's "Data as of" timestamp confirmed matching. Total run time ~33 minutes - unusually long, see anomaly note below.
- **2026-08-26, 9:00 AM (fully automatic via Task Scheduler, not triggered manually):** confirms the scheduled task genuinely fires unattended. 1381 files, ~18 minutes total - back to the expected duration.

**One-time timing anomaly, not reproduced:** the first (8am) run had an unexplained ~15-16 minute gap in `refresh.log` between `upload.py`'s own "Uploaded N files" print and `run_refresh.py`'s final "completed successfully" log line - two lines with no real work between them in the code. The second (9am) run logged those same two lines **1 millisecond apart**, as expected. Best guess: antivirus/endpoint security doing a one-time deep scan of the freshly-installed, unfamiliar native binaries (duckdb, pyarrow, cryptography) the first time that exact `python.exe` process tree ran and exited, then trusting/caching it afterward. Not chased further since it didn't recur and total runtime is comfortably inside the hourly window either way - worth revisiting only if it comes back.

## Monitoring: VS Code Remote Tunnels

Brian previously watched `refresh.log` live in VS Code on his own PC (same machine the pipeline ran on). Now that the pipeline runs on a separate machine with no direct filesystem access from Brian's PC (SMB blocked cross-subnet, same constraint documented in the frontend's deployment doc), VS Code's built-in **Remote Tunnels** feature replaces that workflow without needing an open RDP session:

**One-time setup (via RDP, in VS Code running on the Gateway PC):**
1. Click the remote indicator (bottom-left `><` icon) → **Tunnel** (installs a small component the first time)
2. Sign in with the `SlyFox18` GitHub account
3. Tunnel comes up named after the hostname (`spi00t4022w11`)
4. Run `code tunnel service install` in a terminal there to install it as a background Windows service, so it stays available across reboots/logouts - matching the same "must survive unattended" posture as the scheduled task itself

**From Brian's own PC, whenever he wants to check on it:**
1. Open a **new** VS Code window first (File → New Window) - connecting to a tunnel takes over whichever window does it, so starting fresh avoids losing track of other work
2. Remote indicator → **Connect to Tunnel** → sign in with the same GitHub account → pick `spi00t4022w11`
3. File → Open Folder → `C:\data-projects` (connecting to the tunnel alone doesn't open anything - the folder has to be opened explicitly, and the Open Folder dialog now browses the *Gateway PC's* filesystem, not the local one)
4. Navigate to `.claude\queries\adhoc\parts-lookup-static-prototype\refresh.log` - updates live, same as before

## Failure alerting, staleness check, and app uptime check (added 2026-08-26/31)

Three layers of Teams alerting now exist, all posting to the "Parts Availability App Alerts" channel via the same webhook (`TEAMS_WEBHOOK_URL` in `.env`, a Teams Workflow's "Send webhook alerts to a channel" trigger - the modern replacement for the old Office 365 Incoming Webhook connector). All three reuse `run_refresh.py`'s `notify_teams_failure()`/`log_failure()` helpers, which never raise on their own (a Teams outage can't crash any of these checks) and are optional per-environment (no webhook configured just means no alerts, not an error).

1. **`run_refresh.py` itself** - every existing `FAILED` path now also posts to Teams, not just `refresh.log`. Closes the original gap: a failed 3 AM run used to have no signal beyond someone happening to check the log by hand.
2. **`check_staleness.py`** - a separate scheduled task, offset 45 minutes after each hourly refresh trigger, only during the same Mon-Fri 8am-8pm window. Catches the blind spot failure-alerting alone can't: if the scheduled task itself gets disabled, or the machine loses power, nothing *fails* - the pipeline just silently stops running. This checks `output/2char/_meta.json`'s age directly and alerts if it's older than 90 minutes.
3. **`check_app_uptime.py`** (2026-08-31) - a different concern entirely: not "did the pipeline run," but "is the app itself actually reachable and correct." Runs every 15 minutes, every day, checking `https://go-parts.spitractor.com` from *this* machine (deliberately not from the server being checked - a monitor can't alert about its own host going down). Checks two things, both real failure modes already hit once building this project: the root page serving actual app content (not IIS's generic default page) and `manifest.webmanifest` returning valid JSON (not a 404 - see `parts-lookup-app`'s `WINDOWS-SERVER-2016-DEPLOYMENT.md` for both incidents). Only alerts on a state *change* (up→down or down→up) via a small `uptime_state.json` file, so a multi-hour outage doesn't spam a new message every 15 minutes.

Uses a distinct Teams card title ("Parts Availability App Uptime") from the pipeline's own alerts ("Parts Lookup Refresh") - `notify_teams_failure()`/`log_failure()` both take an optional `title` parameter for exactly this, so an uptime alert can't be mistaken for the refresh pipeline itself failing.

Task Scheduler registration for the uptime check hit the same trigger-construction issue as the others but with a new twist - `-RepetitionDuration ([TimeSpan]::MaxValue)` (attempting "run forever") failed with `The task XML contains a value which is incorrectly formatted or out of range` (Task Scheduler's schema has a real duration ceiling `TimeSpan.MaxValue` blows past). Fixed with the same daily-recurring-with-bounded-repetition pattern as the other two tasks, just scoped to (nearly) the whole day instead of a business-hours window:
```powershell
$trigger = New-ScheduledTaskTrigger -Daily -At "12:00AM"
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 59)).Repetition
```

## Redeploying after a pipeline code change

```powershell
cd C:\data-projects
git pull origin dev
cd .claude\queries\adhoc\parts-lookup-static-prototype
pip install -r requirements.txt  # only needed if dependencies changed
```
No restart of anything needed - Task Scheduler launches a fresh `python.exe run_refresh.py` process each trigger, so the next scheduled run automatically picks up whatever's on disk.

## Open items

- ~~Failure alerting~~ - **done**, see "Failure alerting, staleness check, and app uptime check" above.
- **This machine is still a single point of failure for the pipeline.** The frontend no longer depends on it (that risk went away when the frontend moved to its own Server 2016 machine), but if the Gateway PC goes down, nothing refreshes the underlying data until either it comes back or Brian's PC's disabled task is manually re-enabled. Acceptable given the fallback is one `Enable-ScheduledTask` away, but worth keeping in mind.
- **True push-triggered CI/CD** - not part of this migration, not yet pursued.
