# JD gateway watchdog

A scheduled task on **SPI01SR2034W** that keeps JD's gateway (`049694-Gateway`) online. Background: on
2026-10-14 a gateway blip made one midnight copy fail, and on 2026-10-15 the gateway was offline from
before midnight until someone restarted it at about 07:30. Both mornings the DP refresh was blocked.

## What it does

| Task (under `\SPI\` in Task Scheduler, runs as SYSTEM) | When | |
|---|---|---|
| JD Gateway Watchdog - Check | every 10 min | the checks below |
| JD Gateway Watchdog - Nightly restart | 23:30 daily | restarts `PBIEgwService` before JD's midnight Full load, waits up to 5 min for Fabric to report it Live, and alerts if it doesn't |

Each check:

1. **Service** `PBIEgwService` not running → **start it** right away.
2. **Fabric's view** (Power BI REST `GET /gateways/{id}` → `gatewayStatus`). Not `Live` on **two checks in a row**
   (about 20 min) while the service runs → **restart the service** (it kills the process if the stop hangs).
3. **Equip through the gateway** (`GET /gateways/{id}/datasources/{EquipRDB}/status`, a live ODBC test), only
   when the gateway is Live. Failure → **alert only**; restarting the gateway doesn't fix Equip, the DSN or the
   credentials.
4. If it **couldn't ask Fabric**, it tests TCP 443 to `ncu.frontend.clouddatahub.net`. Unreachable → alert
   "network/firewall"; reachable → alert "watchdog can't check" (expired secret, removed permission).

Limits: at most **3 restarts in 6 hours** (the 23:30 one doesn't count), then a "giving up, needs a person"
alert. The same problem is re-alerted at most every 4 hours. When an alerted problem clears, a green
"Recovered" email goes out.

**Alerts** use the same route as the DP refresh: Graph `sendMail` as `dp-refresh@spitractor.com`, a
high-importance email to the alert list and a copy to the Teams channel address. Subjects start with
🔴 (problem / restart didn't help), 🟡 (restarted and it came back), 🟢 (recovered).

**What it can't catch:** the whole server being off or the secret expiring. In both cases nothing runs or
nothing can be sent. The DP refresh's Bronze check still catches the outcome at 06:21.

## Identity and permissions

- Service principal **SPN-Fabric-Refresh-Automation** (app `9adca971-f328-4d79-9b48-713c298a238c`), with its own
  client secret **gateway-watchdog**. If the server is ever in doubt, revoke just that secret; the DP refresh
  keeps working.
- **Admin** on the gateway `049694-Gateway` (Manage connections and gateways → On-premises data gateways →
  Manage users) and **User** on the connection `049694-Gateway` (`b062a489`). Both granted 2026-10-15.
- Mail.Send through the existing DP-refresh mail setup.

The secret is in `secret.bin`, DPAPI-encrypted with the machine key. The install folder is locked to SYSTEM and
Administrators; that ACL is what protects it.

## Files

Installed to `C:\ProgramData\JDGatewayWatchdog\`:

| File | |
|---|---|
| `Invoke-GatewayWatchdog.ps1` | entry point: `-Mode Check`, `NightlyRestart` or `Test` (`-SendTestEmail`) |
| `GatewayWatchdog.psm1` | decision logic (pure, tested) and the REST/service/mail helpers |
| `config.json` | IDs, recipients, limits, `LogOnly` |
| `secret.bin` | the encrypted client secret |
| `state.json` | failure count, recent restarts, last alert (delete it to reset) |
| `logs\watchdog-YYYY-MM-DD.log` | one line per check; kept 30 days |

Windows PowerShell 5.1 only: no PowerShell 7 and no extra modules. Tests (Pester 3.4):
`powershell -NoProfile -Command "Invoke-Pester .\projects\jd-bronze-pipelines\gateway-watchdog"`.

## Install / update

On SPI01SR2034W, copy this folder somewhere local, open **Windows PowerShell as administrator**, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-GatewayWatchdog.ps1              # first time: asks for the gateway-watchdog secret Value
& 'C:\ProgramData\JDGatewayWatchdog\Invoke-GatewayWatchdog.ps1' -Mode Test -SendTestEmail
```

The Test pass should show `Service=Running; Gateway=Live; Source=Ok` and decision `None; Healthy`.

It starts in **log-only** mode: it checks, logs and emails, but never touches the service (emails say
"[log-only]" and what it would have done). After a day or two of clean logs:

```powershell
.\Install-GatewayWatchdog.ps1 -Live
```

Then run a drill: `Stop-Service PBIEgwService`. Within 10 minutes the service should be started again, with a
🟡 email.

Re-running the installer updates the scripts and tasks and keeps config, secret, state and logs. Other
switches: `-NewSecret` (rotation), `-ResetConfig`.

## Turning it off

```powershell
Disable-ScheduledTask -TaskPath '\SPI\' -TaskName 'JD Gateway Watchdog - Check'
Disable-ScheduledTask -TaskPath '\SPI\' -TaskName 'JD Gateway Watchdog - Nightly restart'
```

Or set `"LogOnly": true` in `config.json` to keep the checks and alerts without restarts.
