<#
.SYNOPSIS
    Watchdog for an on-premises data gateway: JD's 049694-Gateway on SPI01SR2034W, or SPI-Data-Gateway on
    SPI00T4022W11 (which one is in config.json). Run by two scheduled tasks as SYSTEM; see README.md in this folder.
.DESCRIPTION
    -Mode Check (every 10 minutes):
        0. Gateway installer (GatewayInstall.exe) running?   Yes -> hands off (also skips the 23:30 restart).
        1. Is the PBIEgwService service running?            Stopped twice in a row -> start it.
        2. Does Fabric see the gateway as Live?              Not Live twice in a row -> restart the service.
        3. Gateway Live: can it reach Equip (config DatasourceId)?   Failed -> alert only (a restart won't fix Equip).
        4. Couldn't ask Fabric: can this server reach Fabric on 443?  No -> alert only.
        At most MaxRestarts restarts per RestartWindowHours, then it alerts "giving up" and leaves it to a person.
    -Mode NightlyRestart (23:30): restart, wait for Live, alert if it doesn't come back.
    -Mode Test: run the checks, print what it sees and what it would do; changes nothing.
        Add -SendTestEmail to also send a test email.

    Config: config.json next to this script. LogOnly=true means it decides and emails but never touches
    the service (the email says what it would have done).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-GatewayWatchdog.ps1 -Mode Test -SendTestEmail
#>
[CmdletBinding()]
param(
    [ValidateSet('Check', 'NightlyRestart', 'Test')]
    [string]$Mode = 'Check',
    [switch]$SendTestEmail
)

$ErrorActionPreference = 'Stop'
# Emoji built from code points: Windows PowerShell 5.1 reads a BOM-less script as ANSI.
$red = [char]::ConvertFromUtf32(0x1F534); $yellow = [char]::ConvertFromUtf32(0x1F7E1); $green = [char]::ConvertFromUtf32(0x1F7E2)
Import-Module (Join-Path $PSScriptRoot 'GatewayWatchdog.psm1') -Force

$root = $PSScriptRoot
$config = ConvertTo-Hashtable (Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json)
# Configs written before the SPI-Data-Gateway install (2026-10-16) have neither key: they are JD's.
if (-not $config.GatewayName) { $config.GatewayName = 'JD gateway' }
if (-not $config.Runbook) { $config.Runbook = 'data-projects/projects/jd-bronze-pipelines/README.md' }
$name = $config.GatewayName
$logDir = Join-Path $root 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir "watchdog-$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-WatchdogLog {
    param([string]$Level, [string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Mode] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $logPath -Value $line -Encoding UTF8    # 5.1's default (ANSI) turns the emoji into ??
}

function Format-Html {
    param([string]$Summary, [string]$Detail, [hashtable]$Obs)
    $e = { param($s) [Net.WebUtility]::HtmlEncode([string]$s) }
    $rows = ($Obs.Keys | Sort-Object | ForEach-Object { "<tr><td>$(& $e $_)</td><td>$(& $e $Obs[$_])</td></tr>" }) -join ''
    "<p><b>$(& $e $Summary)</b></p>" +
    $(if ($Detail) { "<p>$(& $e $Detail)</p>" } else { '' }) +
    "<p>Server: $(& $e $env:COMPUTERNAME) &middot; $(Get-Date -Format 'yyyy-MM-dd HH:mm') local</p>" +
    "<p>What the check found (before acting):</p>" +
    "<table border='1' cellpadding='4' style='border-collapse:collapse'>$rows</table>" +
    "<p>Log: $(& $e $logPath)<br>Runbook: $(& $e $config.Runbook)</p>"
}

function Send-Safely {
    param([string]$Subject, [string]$Html, [switch]$Normal)
    try {
        Send-WatchdogMail -Config $config -Secret $secret -Subject $Subject -Html $Html -Normal:$Normal
        Write-WatchdogLog 'INFO' "Email sent: $Subject"
    }
    catch { Write-WatchdogLog 'ERROR' "Email FAILED ($Subject): $($_.Exception.Message)" }
}

# One run at a time across both tasks (a 23:30 restart can overlap a 10-minute check). Test changes
# nothing, so it doesn't take the lock.
$mutex = $null
if ($Mode -ne 'Test') {
    $mutex = New-Object Threading.Mutex($false, "Global\GatewayWatchdog-$($config.GatewayId)")
    if (-not $mutex.WaitOne(0)) { Write-WatchdogLog 'INFO' 'Another watchdog run is in progress; exiting'; exit 0 }
}

$exitCode = 0
try {
    # Keep 30 days of logs.
    Get-ChildItem $logDir -Filter 'watchdog-*.log' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force

    $secret = Unprotect-WatchdogSecret -Path (Join-Path $root 'secret.bin')
    $logOnly = [bool]$config.LogOnly
    $tag = if ($logOnly) { ' [log-only]' } else { '' }

    if ($Mode -eq 'NightlyRestart') {
        if (Get-Process -Name 'GatewayInstall' -ErrorAction SilentlyContinue) {
            Write-WatchdogLog 'INFO' 'Gateway installer is running; skipping the planned restart'
        }
        elseif ($logOnly) {
            Write-WatchdogLog 'INFO' 'Log-only: would restart the gateway service now'
        }
        else {
            $how = Restart-GatewayService -ServiceName $config.ServiceName
            $status = Wait-GatewayLive -Config $config -Secret $secret -TimeoutSeconds $config.VerifyWaitSeconds
            Write-WatchdogLog 'INFO' "Planned restart: $how; gateway status afterwards: $status"
            if ($status -ne 'Live') {
                Send-Safely -Subject "$red $name did not come back after the nightly restart ($status)" `
                    -Html (Format-Html -Summary "The planned 23:30 restart finished ($how) but Fabric reports the gateway as '$status' after $($config.VerifyWaitSeconds) s. The 10-minute check will keep trying." -Obs @{ Status = $status })
            }
        }
        return
    }

    $obs = Get-GatewayObservation -Config $config -Secret $secret
    $obsText = ($obs.Keys | Sort-Object | ForEach-Object { "$_=$($obs[$_])" }) -join '; '

    $statePath = Join-Path $root 'state.json'
    $state = Read-WatchdogState -Path $statePath
    $nowUtc = (Get-Date).ToUniversalTime()
    $d = Get-WatchdogDecision -Observation $obs -State $state -Config $config -NowUtc $nowUtc

    if ($Mode -eq 'Test') {
        Write-WatchdogLog 'INFO' "Test: $obsText"
        Write-WatchdogLog 'INFO' "Test: decision=$($d.Action); $($d.Summary)"
        if ($SendTestEmail) {
            Send-Safely -Normal -Subject "$name watchdog: test email" `
                -Html (Format-Html -Summary "Test from the watchdog. Decision right now: $($d.Action) - $($d.Summary)" -Obs $obs)
        }
        return
    }

    $level = if ($d.Problem -or $d.Action -ne 'None') { 'WARN' } else { 'INFO' }
    Write-WatchdogLog $level "$($d.Summary) | $obsText"

    $result = ''
    $afterLive = $false
    if ($d.Action -ne 'None') {
        if ($logOnly) {
            $result = "Log-only mode: did NOT $($d.Action)."
            $d.State.Restarts = @($state.Restarts)    # nothing happened, so it doesn't count toward the cap
        }
        else {
            try {
                if ($d.Action -eq 'StartService') {
                    Start-Service -Name $config.ServiceName
                    (Get-Service -Name $config.ServiceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(120))
                    $how = 'started'
                }
                else {
                    $how = Restart-GatewayService -ServiceName $config.ServiceName
                }
                $status = Wait-GatewayLive -Config $config -Secret $secret -TimeoutSeconds $config.VerifyWaitSeconds
                $result = "Service $how; Fabric status afterwards: $status."
                if ($status -eq 'Live') {
                    $afterLive = $true
                    $d.State.OpenProblem = $null; $d.State.LastAlertKey = $null; $d.State.LastAlertUtc = $null
                }
            }
            catch {
                $result = "The $($d.Action) attempt FAILED: $($_.Exception.Message)"
                $exitCode = 1
            }
        }
        Write-WatchdogLog 'WARN' $result
    }

    # Catch-up trigger: ask the DP pipeline to check for work after a recovery, and at the JD backup times.
    # The pipeline decides whether anything needs doing; this only starts it.
    $catchupNote = ''
    $t = Get-CatchupTrigger -Decision $d -AfterActionLive $afterLive -State $d.State -Config $config -NowLocal (Get-Date)
    $d.State = $t.State
    Save-WatchdogState -Path $statePath -State $d.State
    if ($t.Start) {
        $enabled = $config.ContainsKey('CatchupEnabled') -and [bool]$config.CatchupEnabled
        if ($enabled) {
            $r = Start-CatchupRun -Config $config -Secret $secret -Reason $t.Reason
            if ($r.Ok) {
                Write-WatchdogLog 'INFO' "Started catch-up ($($t.Reason)): HTTP $($r.Status)"
                $catchupNote = 'A catch-up run was started.'
            }
            else {
                Write-WatchdogLog 'ERROR' "Catch-up start FAILED ($($t.Reason)): $($r.Status)"
                $catchupNote = "Catch-up start failed: $($r.Status)"
            }
        }
        else {
            Write-WatchdogLog 'INFO' "[log-only] would start catch-up ($($t.Reason))"
            $catchupNote = 'Catch-up would be started (log-only).'
        }
    }

    if ($d.Alert) {
        $icon = if ($d.Action -ne 'None' -and $result -match 'Live\.$') { $yellow } else { $red }
        $det = (($d.Detail, $result) -join ' ').Trim()
        if ($catchupNote -and $afterLive) { $det = "$det $catchupNote".Trim() }
        Send-Safely -Subject "$icon $name$($tag): $($d.Summary)" `
            -Html (Format-Html -Summary $d.Summary -Detail $det -Obs $obs)
    }
    elseif ($d.Recovered) {
        Send-Safely -Normal -Subject "$green $name$($tag): $($d.Summary)" -Html (Format-Html -Summary $d.Summary -Detail $catchupNote -Obs $obs)
    }
}
catch {
    Write-WatchdogLog 'ERROR' "Watchdog run failed: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
}
exit $exitCode
