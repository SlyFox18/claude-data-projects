<#
.SYNOPSIS
    Decision logic and I/O helpers for the gateway watchdog (Invoke-GatewayWatchdog.ps1).
.DESCRIPTION
    Get-WatchdogDecision is pure (no I/O) and is what GatewayWatchdog.Tests.ps1 covers. Everything
    else talks to Windows, Entra, the Power BI REST API or Microsoft Graph.

    Windows PowerShell 5.1 compatible on purpose: the gateway hosts (SPI01SR2034W, SPI00T4022W11) have no PowerShell 7.
    No ?? / ?: operators, no -AsHashtable.
#>

Set-StrictMode -Version 2.0

# ---------------------------------------------------------------------------------------------
# Pure decision logic
# ---------------------------------------------------------------------------------------------

function New-WatchdogState {
    @{ ConsecutiveFailures = 0; SourceFailures = 0; Restarts = @(); OpenProblem = $null; LastAlertKey = $null; LastAlertUtc = $null }
}

function Get-RestartsInWindow {
    param([string[]]$Restarts, [datetime]$NowUtc, [double]$WindowHours)
    $cutoff = $NowUtc.AddHours(-$WindowHours)
    @($Restarts | Where-Object { $_ -and ([datetime]::Parse($_, $null, 'RoundtripKind') -gt $cutoff) })
}

function Get-WatchdogDecision {
    <#
    .SYNOPSIS
        What to do about one set of observations. Returns a hashtable:
          Action    'None' | 'StartService' | 'RestartService'
          Problem   problem key, or $null when healthy (or not yet confirmed)
          Summary   one line for the log and the email subject
          Detail    longer text for the email body
          Alert     $true when an email should go out now
          Recovered $true when a previously alerted problem has cleared
          State     the new state (persist it)
    .PARAMETER Observation
        Service  'Running' | 'Stopped' | 'Missing' | any other ServiceControllerStatus name
        Gateway  'Live' | 'Unknown' (couldn't ask Fabric) | any other gatewayStatus value
        GatewayError, SourceError  error text or $null
        Source   'Ok' | 'Failed' | 'Unknown' | 'NotChecked'
        Network  $true / $false / $null (only probed when Gateway is 'Unknown')
        Installing  $true while the gateway installer (GatewayInstall.exe) runs: hands off, counters reset
    #>
    param(
        [Parameter(Mandatory)] [hashtable]$Observation,
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [hashtable]$Config,
        [Parameter(Mandatory)] [datetime]$NowUtc
    )
    $o = $Observation
    # Keys added after the first release may be missing from an old state.json or config.json; a missing hashtable
    # key throws under StrictMode 2, so ask first.
    $srcFailures = 0; $srcTimes = @()
    if ($State.ContainsKey('SourceFailures')) { $srcFailures = [int]$State.SourceFailures }
    if ($State.ContainsKey('SourceFailureTimes')) { $srcTimes = @($State.SourceFailureTimes) }
    $srcWindowHours = 2.0; $srcInWindow = 3
    if ($Config.ContainsKey('SourceFailureWindowHours')) { $srcWindowHours = [double]$Config.SourceFailureWindowHours }
    if ($Config.ContainsKey('SourceFailuresInWindow')) { $srcInWindow = [int]$Config.SourceFailuresInWindow }
    $new = @{
        ConsecutiveFailures = [int]$State.ConsecutiveFailures
        SourceFailures      = $srcFailures
        SourceFailureTimes  = @(Get-RestartsInWindow -Restarts $srcTimes -NowUtc $NowUtc -WindowHours $srcWindowHours)
        Restarts            = @(Get-RestartsInWindow -Restarts $State.Restarts -NowUtc $NowUtc -WindowHours $Config.RestartWindowHours)
        OpenProblem         = $State.OpenProblem
        LastAlertKey        = $State.LastAlertKey
        LastAlertUtc        = $State.LastAlertUtc
    }
    if ($State.ContainsKey('LastCatchupSlot')) { $new.LastCatchupSlot = $State.LastCatchupSlot }   # owned by Get-CatchupTrigger
    $capReached = $new.Restarts.Count -ge $Config.MaxRestarts
    $action = 'None'; $problem = $null; $summary = 'Healthy'; $detail = ''

    if ($o.Installing) {
        # An upgrade stops (and can briefly remove) the service. Starting it mid-install could break the upgrade.
        $new.ConsecutiveFailures = 0
        $new.SourceFailures = 0
        $summary = 'Gateway installer is running; leaving the service alone'
    }
    elseif ($o.Service -eq 'Missing') {
        $new.SourceFailures = 0
        $problem = 'service-missing'
        $summary = "Gateway service $($Config.ServiceName) is not installed on this server"
        $detail = 'The watchdog cannot fix this. Was the gateway uninstalled or renamed?'
    }
    elseif ($o.Service -ne 'Running') {
        # A stopped service is waited out like an offline gateway: a clean stop is usually deliberate (maintenance,
        # upgrade), and Windows' own recovery options already restart it after a crash.
        $new.SourceFailures = 0
        $new.ConsecutiveFailures++
        if ($new.ConsecutiveFailures -lt $Config.FailuresBeforeRestart) {
            $summary = "Gateway service is $($o.Service) (check $($new.ConsecutiveFailures) of $($Config.FailuresBeforeRestart) before starting it)"
        }
        elseif ($capReached) {
            $problem = 'gave-up'
            $summary = "Gateway service is $($o.Service) and the watchdog already restarted it $($new.Restarts.Count) times in $($Config.RestartWindowHours) h; giving up"
            $detail = "Needs a person: RDP to the server, check Event Viewer and the gateway app. Runbook: $($Config.Runbook)"
        }
        else {
            $action = 'StartService'
            $problem = 'service-stopped'
            $summary = "Gateway service has been $($o.Service) for $($new.ConsecutiveFailures) checks; starting it"
        }
    }
    elseif ($o.Gateway -eq 'Live') {
        $new.ConsecutiveFailures = 0
        if ($o.Source -eq 'Failed') {
            # One failed test is noise (Equip busy overnight, 2026-10-19 00:37); alert only when it repeats.
            # Also alert when it keeps failing every other check (fail, ok, fail, ok, fail).
            $new.SourceFailures++
            $new.SourceFailureTimes = @($new.SourceFailureTimes) + @($NowUtc.ToString('o'))
            $inWindow = $new.SourceFailureTimes.Count
            if ($new.SourceFailures -lt $Config.FailuresBeforeRestart -and $inWindow -lt $srcInWindow) {
                $summary = "Equip test through the gateway failed (check $($new.SourceFailures) of $($Config.FailuresBeforeRestart) before alerting)"
            }
            elseif ($new.SourceFailures -lt $Config.FailuresBeforeRestart) {
                $problem = 'source-failed'
                $summary = "Equip test through the gateway keeps failing ($inWindow times in the last $srcWindowHours h)"
                $detail = "Restarting the gateway will not fix this; check the Equip server, the ODBC DSN on this machine and the connection credentials. Error: $($o.SourceError)"
            }
            else {
                $problem = 'source-failed'
                $summary = 'Gateway is online, but it cannot reach Equip through its ODBC connection'
                $detail = "Restarting the gateway will not fix this; check the Equip server, the ODBC DSN on this machine and the connection credentials. Error: $($o.SourceError)"
            }
        }
        else {
            $new.SourceFailures = 0
        }
    }
    elseif ($o.Gateway -eq 'Unknown') {
        $new.SourceFailures = 0
        if ($o.Network -eq $false) {
            $problem = 'network'
            $summary = "This server cannot reach $($Config.ProbeHost):443; the gateway cannot work until its network or firewall is fixed"
            $detail = "Restarting the gateway will not help. Error asking Fabric: $($o.GatewayError)"
        }
        else {
            $problem = 'cannot-check'
            $summary = 'The watchdog could not ask Fabric for the gateway status (secret expired, or permission removed?)'
            $detail = "The gateway itself may be fine. Error: $($o.GatewayError)"
        }
    }
    else {
        $new.SourceFailures = 0
        $new.ConsecutiveFailures++
        if ($new.ConsecutiveFailures -lt $Config.FailuresBeforeRestart) {
            $summary = "Fabric reports the gateway as '$($o.Gateway)' (check $($new.ConsecutiveFailures) of $($Config.FailuresBeforeRestart) before restarting)"
        }
        elseif ($capReached) {
            $problem = 'gave-up'
            $summary = "Fabric reports the gateway as '$($o.Gateway)' and the watchdog already restarted it $($new.Restarts.Count) times in $($Config.RestartWindowHours) h; giving up"
            $detail = "Needs a person: RDP to the server, open the On-premises data gateway app, run Diagnostics. Runbook: $($Config.Runbook)"
        }
        else {
            $action = 'RestartService'
            $problem = 'gateway-offline'
            $summary = "Fabric reports the gateway as '$($o.Gateway)' while the service is running; restarting it"
            $detail = "Status error: $($o.GatewayError)"
        }
    }

    if ($action -ne 'None') {
        $new.Restarts = @($new.Restarts) + @($NowUtc.ToString('o'))
        $new.ConsecutiveFailures = 0
    }

    $alert = $false; $recovered = $false
    if ($problem) {
        $repeatDue = (-not $new.LastAlertUtc) -or
            ($NowUtc - [datetime]::Parse($new.LastAlertUtc, $null, 'RoundtripKind')).TotalHours -ge $Config.AlertRepeatHours
        if ($action -ne 'None' -or $problem -ne $new.LastAlertKey -or $repeatDue) {
            $alert = $true
            $new.LastAlertKey = $problem
            $new.LastAlertUtc = $NowUtc.ToString('o')
        }
        $new.OpenProblem = $problem
    }
    elseif ($new.OpenProblem -eq 'source-failed' -and $o.Service -eq 'Running' -and $o.Gateway -eq 'Live' -and
            $new.SourceFailureTimes.Count -ge $srcInWindow) {
        # A flapping Equip test stays one open problem until the failures in the window drop below the threshold:
        # no Recovered email now, and no new alert when it fails again (AlertRepeatHours still applies).
        $summary = "Equip test through the gateway is Ok again, but it failed $($new.SourceFailureTimes.Count) times in the last $srcWindowHours h; staying open until that drops below $srcInWindow"
    }
    elseif ($new.OpenProblem -and $o.Service -eq 'Running' -and $o.Gateway -eq 'Live') {
        $recovered = $true
        $summary = "Recovered: gateway is Live again (was: $($new.OpenProblem))"
        $new.OpenProblem = $null
        $new.LastAlertKey = $null
        $new.LastAlertUtc = $null
    }

    @{ Action = $action; Problem = $problem; Summary = $summary; Detail = $detail
       Alert = $alert; Recovered = $recovered; State = $new }
}

function Get-CatchupTrigger {
    <#
    .SYNOPSIS
        Should this check start a catch-up run of Pipeline_DP_Refresh? Pure. Returns @{ Start; Reason; State }.
        Recovery (decision Recovered, or an action taken and the gateway is Live afterwards) always starts.
        Backup: a weekday, within 10 minutes after one of Config.CatchupTimes, once per slot (State.LastCatchupSlot).
        At most one Start per call; the slot is recorded even when a recovery start wins.
    #>
    param(
        [Parameter(Mandatory)] [hashtable]$Decision,
        [bool]$AfterActionLive = $false,
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [hashtable]$Config,
        [Parameter(Mandatory)] [datetime]$NowLocal
    )
    $new = $State.Clone()
    $start = $false; $reason = ''
    $gwName = 'gateway'
    if ($Config.ContainsKey('GatewayName') -and $Config.GatewayName) { $gwName = [string]$Config.GatewayName }

    if ($Decision.Recovered -or ($Decision.Action -ne 'None' -and $AfterActionLive)) {
        $start = $true
        $reason = "$gwName gateway recovered $($NowLocal.ToString('HH:mm'))"
    }

    $times = @()
    if ($Config.ContainsKey('CatchupTimes') -and $Config.CatchupTimes) { $times = @($Config.CatchupTimes) }
    $last = ''
    if ($State.ContainsKey('LastCatchupSlot') -and $State.LastCatchupSlot) { $last = [string]$State.LastCatchupSlot }
    if ($NowLocal.DayOfWeek -ne [DayOfWeek]::Saturday -and $NowLocal.DayOfWeek -ne [DayOfWeek]::Sunday) {
        foreach ($t in $times) {
            $slotStart = $NowLocal.Date + [TimeSpan]::Parse([string]$t)
            $key = "$($NowLocal.ToString('yyyy-MM-dd')) $t"
            if ($NowLocal -ge $slotStart -and $NowLocal -lt $slotStart.AddMinutes(10) -and $last -ne $key) {
                $new.LastCatchupSlot = $key
                if (-not $start) { $start = $true; $reason = "backup $t" }
                break
            }
        }
    }
    @{ Start = $start; Reason = $reason; State = $new }
}

# ---------------------------------------------------------------------------------------------
# State, config and secret files
# ---------------------------------------------------------------------------------------------

function ConvertTo-Hashtable {
    param($Object)
    if ($null -eq $Object) { return $null }
    $h = @{}
    foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = $p.Value }
    $h
}

function Read-WatchdogState {
    param([string]$Path)
    $state = New-WatchdogState
    if (Test-Path $Path) {
        try {
            $saved = ConvertTo-Hashtable (Get-Content $Path -Raw | ConvertFrom-Json)
            foreach ($k in @($saved.Keys)) { $state[$k] = $saved[$k] }
            $state.Restarts = @($state.Restarts | Where-Object { $_ })
        }
        catch { }   # a corrupt state file just means starting fresh
    }
    $state
}

function Save-WatchdogState {
    param([string]$Path, [hashtable]$State)
    $tmp = "$Path.tmp"
    $State | ConvertTo-Json -Depth 4 | Set-Content -Path $tmp -Encoding UTF8
    Move-Item -Path $tmp -Destination $Path -Force
}

function Protect-WatchdogSecret {
    <# DPAPI LocalMachine: SYSTEM (the scheduled task) can decrypt what an admin encrypted. The file ACL
       (SYSTEM + Administrators only, set by the installer) is what keeps other accounts out. #>
    param([Security.SecureString]$Secret, [string]$Path)
    Add-Type -AssemblyName System.Security
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret))
    $bytes = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($plain), $null,
        [Security.Cryptography.DataProtectionScope]::LocalMachine)
    [IO.File]::WriteAllBytes($Path, $bytes)
}

function Unprotect-WatchdogSecret {
    param([string]$Path)
    Add-Type -AssemblyName System.Security
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($Path), $null,
        [Security.Cryptography.DataProtectionScope]::LocalMachine)
    [Text.Encoding]::UTF8.GetString($bytes)
}

# ---------------------------------------------------------------------------------------------
# Observations
# ---------------------------------------------------------------------------------------------

function Get-AccessToken {
    param([hashtable]$Config, [string]$Secret, [string]$Scope)
    $body = @{ grant_type = 'client_credentials'; client_id = $Config.ClientId; client_secret = $Secret; scope = $Scope }
    (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$($Config.TenantId)/oauth2/v2.0/token" `
        -Body $body -TimeoutSec 30).access_token
}

function Get-HttpErrorText {
    param($ErrorRecord)
    $text = $ErrorRecord.Exception.Message
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { $text += " | $($ErrorRecord.ErrorDetails.Message)" }
    if ($text.Length -gt 600) { $text = $text.Substring(0, 600) }
    $text
}

function Get-HttpStatusCode {
    param($ErrorRecord)
    try { [int]$ErrorRecord.Exception.Response.StatusCode } catch { 0 }
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port = 443, [int]$TimeoutMs = 5000)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        $task.Wait($TimeoutMs) -and $client.Connected
    }
    catch { $false }
    finally { $client.Dispose() }
}

function Get-GatewayObservation {
    <# Service state, Fabric's view of the gateway, and (only when the gateway is Live) a live test of the
       Equip ODBC connection (config DatasourceId) through it. #>
    param([hashtable]$Config, [string]$Secret)
    $o = @{ Service = 'Missing'; Gateway = 'Unknown'; GatewayError = $null; Source = 'NotChecked'; SourceError = $null; Network = $null
            Installing = [bool](Get-Process -Name 'GatewayInstall' -ErrorAction SilentlyContinue) }

    $svc = Get-Service -Name $Config.ServiceName -ErrorAction SilentlyContinue
    if ($svc) { $o.Service = $svc.Status.ToString() }

    $base = "https://api.powerbi.com/v1.0/myorg/gateways/$($Config.GatewayId)"
    $token = $null
    try {
        $token = Get-AccessToken -Config $Config -Secret $Secret -Scope 'https://analysis.windows.net/powerbi/api/.default'
        $gw = Invoke-RestMethod -Uri $base -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 60
        $o.Gateway = [string]$gw.gatewayStatus
        if (-not $o.Gateway) { $o.Gateway = 'Unknown'; $o.GatewayError = 'Response had no gatewayStatus' }
    }
    catch {
        $o.GatewayError = Get-HttpErrorText $_
    }

    if ($o.Gateway -eq 'Unknown') {
        $o.Network = Test-TcpPort -HostName $Config.ProbeHost -Port 443
    }
    elseif ($o.Gateway -eq 'Live' -and $Config.DatasourceId) {
        try {
            Invoke-RestMethod -Uri "$base/datasources/$($Config.DatasourceId)/status" `
                -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 120 | Out-Null
            $o.Source = 'Ok'
        }
        catch {
            $o.SourceError = Get-HttpErrorText $_
            $code = Get-HttpStatusCode $_
            # 401/403 = our permission, not Equip. Anything else (400 with a DM_GWPipeline error, 5xx) = the source.
            if ($code -eq 401 -or $code -eq 403) { $o.Source = 'Unknown' } else { $o.Source = 'Failed' }
        }
    }
    $o
}

# ---------------------------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------------------------

function Restart-GatewayService {
    <# Stop (killing the process if it hangs in StopPending), then start. Returns a short description. #>
    param([string]$ServiceName, [int]$StopTimeoutSeconds = 120)
    $notes = @()
    $svc = Get-Service -Name $ServiceName
    if ($svc.Status -ne 'Stopped') {
        try {
            $svc.Stop()
            $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds($StopTimeoutSeconds))
            $notes += 'stopped'
        }
        catch {
            $procId = (Get-CimInstance Win32_Service -Filter "Name='$ServiceName'").ProcessId
            if ($procId) {
                Stop-Process -Id $procId -Force
                $notes += "stop hung; killed process $procId"
                Start-Sleep -Seconds 5
            }
        }
    }
    Start-Service -Name $ServiceName
    (Get-Service -Name $ServiceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(120))
    $notes += 'started'
    $notes -join ', '
}

function Wait-GatewayLive {
    <# Poll Fabric until the gateway reports Live or the time runs out. Returns the last status seen. #>
    param([hashtable]$Config, [string]$Secret, [int]$TimeoutSeconds = 300, [int]$PollSeconds = 30)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $status = 'Unknown'
    do {
        Start-Sleep -Seconds $PollSeconds
        try {
            $token = Get-AccessToken -Config $Config -Secret $Secret -Scope 'https://analysis.windows.net/powerbi/api/.default'
            $status = [string](Invoke-RestMethod -Uri "https://api.powerbi.com/v1.0/myorg/gateways/$($Config.GatewayId)" `
                -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 60).gatewayStatus
        }
        catch { $status = 'Unknown' }
    } while ($status -ne 'Live' -and (Get-Date) -lt $deadline)
    $status
}

function Start-CatchupRun {
    <# POST a Pipeline_DP_Refresh run with mode=catchup. Never throws. Ok=$true when Fabric accepted it (202). #>
    param([hashtable]$Config, [string]$Secret, [string]$Reason)
    $wsId = '7836042d-adb1-4846-b70d-bd42980054c5'; $plId = '1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c'
    if ($Config.ContainsKey('CatchupWorkspaceId') -and $Config.CatchupWorkspaceId) { $wsId = [string]$Config.CatchupWorkspaceId }
    if ($Config.ContainsKey('CatchupPipelineId') -and $Config.CatchupPipelineId) { $plId = [string]$Config.CatchupPipelineId }
    try {
        $token = Get-AccessToken -Config $Config -Secret $Secret -Scope 'https://api.fabric.microsoft.com/.default'
        $body = @{ executionData = @{ parameters = @{ mode = 'catchup'; reason = $Reason } } } | ConvertTo-Json -Depth 5
        $r = Invoke-WebRequest -Method Post -UseBasicParsing -TimeoutSec 60 `
            -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/items/$plId/jobs/instances?jobType=Pipeline" `
            -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes($body))
        @{ Ok = $true; Status = [int]$r.StatusCode }
    }
    catch {
        $code = Get-HttpStatusCode $_
        if ($code -gt 0) { $st = $code } else { $st = Get-HttpErrorText $_ }
        @{ Ok = $false; Status = $st }
    }
}

function Send-WatchdogMail {
    <# Same route as the DP refresh notifications: Graph sendMail as the shared sender mailbox. Alert list
       gets a high-importance email; the Teams channel address gets a copy. #>
    param([hashtable]$Config, [string]$Secret, [string]$Subject, [string]$Html, [switch]$Normal)
    $token = Get-AccessToken -Config $Config -Secret $Secret -Scope 'https://graph.microsoft.com/.default'
    $batches = @(@{ To = @($Config.AlertTo); Importance = $(if ($Normal) { 'normal' } else { 'high' }) })
    if (@($Config.TeamsTo).Count -gt 0) { $batches += @{ To = @($Config.TeamsTo); Importance = 'normal' } }
    foreach ($b in $batches) {
        $msg = @{
            message = @{
                subject      = $Subject
                body         = @{ contentType = 'HTML'; content = $Html }
                toRecipients = @($b.To | ForEach-Object { @{ emailAddress = @{ address = $_ } } })
                importance   = $b.Importance
            }
            saveToSentItems = $false
        }
        Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/users/$($Config.Sender)/sendMail" `
            -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes(($msg | ConvertTo-Json -Depth 8))) -TimeoutSec 60 | Out-Null
    }
}

Export-ModuleMember -Function New-WatchdogState, Get-RestartsInWindow, Get-WatchdogDecision, ConvertTo-Hashtable,
    Read-WatchdogState, Save-WatchdogState, Protect-WatchdogSecret, Unprotect-WatchdogSecret, Get-GatewayObservation,
    Restart-GatewayService, Wait-GatewayLive, Send-WatchdogMail, Test-TcpPort, Get-CatchupTrigger, Start-CatchupRun
