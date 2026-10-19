# Gateway watchdog

A scheduled task that keeps an on-premises data gateway online by itself: it starts or restarts the gateway
service when it's down and emails what it did. The same code is installed on two machines:

| `-Gateway` | Gateway | Machine | Install folder | Task names (`\SPI\`) | Status |
|---|---|---|---|---|---|
| `JD` (default) | JD's `049694-Gateway` (JD Bronze pipelines) | SPI01SR2034W | `C:\ProgramData\JDGatewayWatchdog` | `JD Gateway Watchdog - …` | **live** since 2026-10-16 |
| `SPI` | `SPI-Data-Gateway` (DP staging dataflows, hourly Parts Availability load, ODBC models) | SPI00T4022W11 | `C:\ProgramData\SPIDataGatewayWatchdog` | `SPI Data Gateway Watchdog - …` | installed 2026-10-16, **live** the same day (code already proven on the JD gateway) |

Background: on 2026-10-14 a JD gateway blip made one midnight copy fail, and on 2026-10-15 that gateway was
offline from before midnight until someone restarted it at about 07:30. Both mornings the DP refresh was blocked.
SPI-Data-Gateway got the same watchdog so a failure there heals before the 06:15 dataflows or an hourly load miss.
SPI00T4022W11's Windows Update active hours are 05:00–21:00 (2026-10-16), so update restarts stay clear of the
06:16 dataflows, the 06:50–16:50 Parts loads and the hourly ODBC models.

## What it does

| Task (under `\SPI\` in Task Scheduler, runs as SYSTEM) | When | |
|---|---|---|
| … Watchdog - Check | every 10 min | the checks below |
| … Watchdog - Nightly restart | 23:30 daily | restarts `PBIEgwService` (before JD's midnight Full load on the JD gateway), waits up to 5 min for Fabric to report it Live, and alerts if it doesn't |

Each check:

0. **Gateway installer** (`GatewayInstall.exe`) running → **hands off** (an upgrade stops the service), and the
   failure count starts over. The 23:30 restart is skipped too.
1. **Service** `PBIEgwService` not running on **two checks in a row** (about 20 min) → **start it**. A clean stop is
   usually deliberate, and Windows' recovery options already restart the service after a crash.
2. **Fabric's view** (Power BI REST `GET /gateways/{id}` → `gatewayStatus`). Not `Live` on **two checks in a row**
   (about 20 min) while the service runs → **restart the service** (it kills the process if the stop hangs).
3. **Equip through the gateway** (`GET /gateways/{id}/datasources/{DatasourceId}/status`, a live ODBC test), only
   when the gateway is Live. A failure must happen on **two checks in a row** (about 20 min) before it alerts; a
   single failed test (e.g. Equip busy overnight, 2026-10-19 00:37) is logged, not emailed. It also alerts when the test fails **3 times within 2 hours** even if Ok checks come
   in between (config `SourceFailuresInWindow` / `SourceFailureWindowHours`, optional); such a flapping test stays one open problem and "Recovered" is sent only once fewer than 3 failures remain in the window. Then → **alert only**; restarting the gateway doesn't fix Equip, the DSN or the
   credentials. JD: the `049694-Gateway` connection (`dsn=EquipRDB`). SPI: `dsn=EquipRDB64` (`70ea8af2`, the one
   Parts Availability uses).
4. If it **couldn't ask Fabric**, it tests TCP 443 to `ncu.frontend.clouddatahub.net`. Unreachable → alert
   "network/firewall"; reachable → alert "watchdog can't check" (expired secret, removed permission).

Limits: at most **3 restarts in 6 hours** (the 23:30 one doesn't count), then a "giving up, needs a person"
alert. The same problem is re-alerted at most every 4 hours. When an alerted problem clears, a green
"Recovered" email goes out.

**Alerts** use the same route as the DP refresh: Graph `sendMail` as `dp-refresh@spitractor.com`, a
high-importance email to the alert list and a copy to the Teams channel address. The subject names the gateway
and starts with 🔴 (problem / restart didn't help), 🟡 (restarted and it came back) or 🟢 (recovered). The table
in the email is what the check found **before** acting.

**What it can't catch:** the machine being off, asleep or mid-reboot, or the secret expiring. In those cases
nothing runs or nothing can be sent. The DP refresh's Bronze check (JD) and its failed-items list and the Parts
Availability alert (SPI) still catch the outcome.

## Catch-up trigger

When a gateway comes back, the watchdog asks the DP backend to catch up: it starts `Pipeline_DP_Refresh` in
DP - Presentation - Prod with `mode=catchup` and `reason=<text>` (Fabric REST `POST /workspaces/{id}/items/{id}/jobs/instances?jobType=Pipeline`,
as SPN-Fabric-Refresh-Automation, which already has Contributor on that workspace). It starts on:

- **Recovery**: the check that sends 🟢 Recovered, or a 🟡 start/restart after which Fabric reports the gateway Live.
  Reason: `<GatewayName> recovered HH:mm`.
- **Backup times** (JD only, weekdays): the first check within 20 minutes after each of `CatchupTimes` (default 08:30 and
  10:30 local), once per slot (`LastCatchupSlot` in `state.json`). Fabric pipeline schedules can't pass parameters, so these live here.
  Reason: `backup HH:mm`.

The pipeline itself decides whether anything needs doing and stays quiet when it doesn't; the watchdog only triggers.
At most one start per check. Not done in `-Mode Test` or `NightlyRestart`. The Recovered / restarted email says whether a
catch-up run was started, would be started (log-only) or failed to start.

| `config.json` key | Default |
|---|---|
| `CatchupEnabled` | `false` (**log-only**: logs `[log-only] would start catch-up (...)` and starts nothing) |
| `CatchupWorkspaceId` | `7836042d-adb1-4846-b70d-bd42980054c5` (DP - Presentation - Prod) |
| `CatchupPipelineId` | `1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c` (`Pipeline_DP_Refresh`) |
| `CatchupTimes` | `["08:30","10:30"]` for JD, `[]` for SPI |

Missing keys are treated as these defaults. Re-running the installer adds missing keys to an existing `config.json`
without changing values already there. To enable, set `"CatchupEnabled": true` in `config.json` (no re-install needed).

## Identity and permissions

- Service principal **SPN-Fabric-Refresh-Automation** (app `9adca971-f328-4d79-9b48-713c298a238c`), with **one
  client secret per machine**: **gateway-watchdog** (SPI01SR2034W) and **gateway-watchdog-spi** (SPI00T4022W11).
  If a machine is ever in doubt, revoke just its secret; the DP refresh keeps working.
- Per gateway, **Admin** on the gateway (Manage connections and gateways → On-premises data gateways → Manage
  users) and **User** on the test connection (Connections tab → the connection → Manage users):
  - JD: gateway `049694-Gateway`, connection `049694-Gateway` (`b062a489`). Granted 2026-10-15.
  - SPI: gateway `SPI-Data-Gateway`, connection `dsn=EquipRDB64` (`70ea8af2`). Granted 2026-10-16.
Secrets expire **10/15/2027** (gateway-watchdog) and **10/16/2027** (gateway-watchdog-spi); rotate with
`-NewSecret` about two weeks before (fabric-workspace-docs OPERATIONS-GUIDE secrets table).
- Mail.Send through the existing DP-refresh mail setup.

The secret is in `secret.bin`, DPAPI-encrypted with the machine key. The install folder is locked to SYSTEM and
Administrators; that ACL is what protects it.

## Files

Installed to the gateway's install folder (table above):

| File | |
|---|---|
| `Invoke-GatewayWatchdog.ps1` | entry point: `-Mode Check`, `NightlyRestart` or `Test` (`-SendTestEmail`) |
| `GatewayWatchdog.psm1` | decision logic (pure, tested) and the REST/service/mail helpers |
| `config.json` | gateway name and IDs, recipients, limits, `LogOnly` |
| `secret.bin` | the encrypted client secret |
| `state.json` | failure count, recent restarts, last alert (delete it to reset) |
| `logs\watchdog-YYYY-MM-DD.log` | one line per check; kept 30 days |

Windows PowerShell 5.1 only: no PowerShell 7 and no extra modules. Tests (Pester 3.4):
`powershell -NoProfile -Command "Invoke-Pester .\projects\jd-bronze-pipelines\gateway-watchdog"`.

## Install / update

On the gateway's machine, copy this folder somewhere local (e.g. `C:\gateway-watchdog`), open **Windows
PowerShell as administrator**, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\gateway-watchdog
.\Install-GatewayWatchdog.ps1                 # SPI01SR2034W (JD gateway); asks for the gateway-watchdog secret
.\Install-GatewayWatchdog.ps1 -Gateway SPI    # SPI00T4022W11 (SPI-Data-Gateway); asks for gateway-watchdog-spi
```

The installer refuses to run on the wrong machine for the chosen `-Gateway`. It ends with a Test pass that should
show `Service=Running; Gateway=Live; Source=Ok` and decision `None; Healthy`. Send a test email with
`& '<install folder>\Invoke-GatewayWatchdog.ps1' -Mode Test -SendTestEmail`.

It starts in **log-only** mode: it checks, logs and emails, but never touches the service (emails say
"[log-only]" and what it would have done). After a day or two of clean logs, re-run with `-Live` (plus
`-Gateway SPI` on SPI00T4022W11).

Then run a drill: `Stop-Service PBIEgwService`. Within 10–20 minutes the service should be started again, with a
🟡 email.

Re-running the installer updates the scripts and tasks and keeps config, secret, state and logs. Other
switches: `-NewSecret` (rotation), `-ResetConfig`.

## Stopping the gateway on purpose

Anyone who stops the gateway deliberately for more than ~20 minutes (maintenance, troubleshooting, JD
support) must **disable the Check task first** and re-enable it afterwards, or the watchdog will start the service
again. Gateway upgrades are detected automatically.

## Turning it off

```powershell
Disable-ScheduledTask -TaskPath '\SPI\' -TaskName 'JD Gateway Watchdog - Check'          # or 'SPI Data Gateway Watchdog - Check'
Disable-ScheduledTask -TaskPath '\SPI\' -TaskName 'JD Gateway Watchdog - Nightly restart'
```

Or set `"LogOnly": true` in `config.json` to keep the checks and alerts without restarts.
