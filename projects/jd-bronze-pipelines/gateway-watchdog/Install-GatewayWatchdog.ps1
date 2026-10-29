<#
.SYNOPSIS
    Installs (or updates) the gateway watchdog on a gateway host. Run in an ELEVATED Windows PowerShell, from
    a copy of this folder, on the machine that runs the gateway:
      -Gateway JD   (default) JD's 049694-Gateway on SPI01SR2034W
      -Gateway SPI  SPI-Data-Gateway on SPI00T4022W11
.DESCRIPTION
    1. Copies GatewayWatchdog.psm1 and Invoke-GatewayWatchdog.ps1 to the gateway's install folder
       (C:\ProgramData\JDGatewayWatchdog or C:\ProgramData\SPIDataGatewayWatchdog).
    2. Writes config.json (first install, or with -ResetConfig). Starts in log-only mode.
    3. Prompts for the service principal secret ("gateway-watchdog" for JD, "gateway-watchdog-spi" for SPI, both on
       SPN-Fabric-Refresh-Automation) and
       stores it DPAPI-encrypted (LocalMachine) in secret.bin (first install, or with -NewSecret).
    4. Locks the folder to SYSTEM + Administrators.
    5. Registers two tasks running as SYSTEM:
         "<Gateway> Watchdog - Check"           every 10 minutes
         "<Gateway> Watchdog - Nightly restart" daily at 23:30
    6. Runs one Test pass (changes nothing).

    Re-running it updates the scripts and tasks and keeps config.json, secret.bin, state.json and logs.
.PARAMETER Live
    Write LogOnly=false into config.json (lets the watchdog restart the service). Without it, an existing
    config keeps its LogOnly value and a new one starts as log-only.
.EXAMPLE
    .\Install-GatewayWatchdog.ps1                       # JD gateway, SPI01SR2034W
    .\Install-GatewayWatchdog.ps1 -Gateway SPI          # SPI-Data-Gateway, SPI00T4022W11
    .\Install-GatewayWatchdog.ps1 -Gateway SPI -Live    # after a day or two of clean log-only runs
    .\Install-GatewayWatchdog.ps1 -NewSecret            # secret rotation
#>
[CmdletBinding()]
param(
    [ValidateSet('JD', 'SPI')]
    [string]$Gateway = 'JD',
    [switch]$NewSecret,
    [switch]$ResetConfig,
    [switch]$Live,
    [switch]$AnyHost    # install even though this isn't the gateway's usual machine
)

$ErrorActionPreference = 'Stop'

$presets = @{
    JD  = @{ GatewayName = 'JD gateway'; Host = 'SPI01SR2034W'; Dir = 'C:\ProgramData\JDGatewayWatchdog'
             Tasks = 'JD Gateway Watchdog'; Secret = 'gateway-watchdog'
             GatewayId = 'e896ed96-9c3a-43b8-82da-dcb99af18260'      # 049694-Gateway
             DatasourceId = 'b062a489-87a3-4c63-9bfe-fdfe2c4732fb'   # 049694-Gateway connection, dsn=EquipRDB
             Runbook = 'data-projects/projects/jd-bronze-pipelines/README.md' }
    SPI = @{ GatewayName = 'SPI-Data-Gateway'; Host = 'SPI00T4022W11'; Dir = 'C:\ProgramData\SPIDataGatewayWatchdog'
             Tasks = 'SPI Data Gateway Watchdog'; Secret = 'gateway-watchdog-spi'
             GatewayId = 'd98a8d2c-d0df-4a42-a281-aab18e49dbd7'      # SPI-Data-Gateway
             DatasourceId = '70ea8af2-b529-4843-aee6-28297801fe71'   # dsn=EquipRDB64 (Parts Availability's connection)
             Runbook = 'data-projects/projects/jd-bronze-pipelines/gateway-watchdog/README.md' }
}
$p = $presets[$Gateway]
$InstallDir = $p.Dir
if ($env:COMPUTERNAME -ne $p.Host -and -not $AnyHost) {
    throw "$($p.GatewayName) runs on $($p.Host), but this is $env:COMPUTERNAME. Wrong -Gateway? (-AnyHost to install anyway.)"
}

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this from an elevated (Run as administrator) PowerShell window.'
}

Write-Host "Installing to $InstallDir"
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $InstallDir 'logs') -Force | Out-Null
foreach ($f in 'GatewayWatchdog.psm1', 'Invoke-GatewayWatchdog.ps1') {
    Copy-Item -Path (Join-Path $PSScriptRoot $f) -Destination $InstallDir -Force
}
Import-Module (Join-Path $InstallDir 'GatewayWatchdog.psm1') -Force

# --- config.json -------------------------------------------------------------------------------
$configPath = Join-Path $InstallDir 'config.json'
# Catch-up trigger (Pipeline_DP_Refresh in DP - Presentation - Prod, mode=catchup). Backup times are JD only.
$catchupTimes = @()
if ($Gateway -eq 'JD') { $catchupTimes = @('08:30', '10:30') }
# Equip quiet hours: IT blocks Equip ODBC from SPI00T4022W11 every night (about 23:00-04:00), so SPI ignores
# failed Equip tests then. The JD gateway's Equip test isn't blocked.
$quietHours = ''
if ($Gateway -eq 'SPI') { $quietHours = '22:45-04:30' }
$catchupDefaults = [ordered]@{
    CatchupEnabled     = $false
    CatchupWorkspaceId = '7836042d-adb1-4846-b70d-bd42980054c5'
    CatchupPipelineId  = '1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c'
    CatchupTimes       = $catchupTimes
    SourceQuietHours   = $quietHours
}
if ($ResetConfig -or -not (Test-Path $configPath)) {
    $config = [ordered]@{
        TenantId              = '8a02a2b8-0092-4de5-8f76-4700d099feb1'
        ClientId              = '9adca971-f328-4d79-9b48-713c298a238c'   # SPN-Fabric-Refresh-Automation
        GatewayName           = $p.GatewayName
        GatewayId             = $p.GatewayId
        DatasourceId          = $p.DatasourceId
        Runbook               = $p.Runbook
        ServiceName           = 'PBIEgwService'
        ProbeHost             = 'ncu.frontend.clouddatahub.net'
        Sender                = 'dp-refresh@spitractor.com'
        AlertTo               = @('bfox@spitractor.com')
        TeamsTo               = @('0e16f436.spitractor.com@amer.teams.ms')
        LogOnly               = $true
        FailuresBeforeRestart = 2
        MaxRestarts           = 3
        RestartWindowHours    = 6
        AlertRepeatHours      = 4
        VerifyWaitSeconds     = 300
    }
    foreach ($k in $catchupDefaults.Keys) { $config[$k] = $catchupDefaults[$k] }
    $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
    Write-Host 'Wrote config.json (log-only)'
}
else {
    # Existing config: add any catch-up / quiet-hours keys it lacks, never overwrite a value that is there.
    $c = Get-Content $configPath -Raw | ConvertFrom-Json
    $added = @()
    foreach ($k in $catchupDefaults.Keys) {
        if (-not ($c.PSObject.Properties.Name -contains $k)) {
            $c | Add-Member -NotePropertyName $k -NotePropertyValue $catchupDefaults[$k]
            $added += $k
        }
    }
    if ($added.Count -gt 0) {
        $c | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
        $note = "SourceQuietHours = '$($c.SourceQuietHours)'"
        if (-not $c.CatchupEnabled) { $note = "catch-up is log-only until CatchupEnabled is true; $note" }
        Write-Host "config.json: added $($added -join ', ') ($note)"
    }
}
if ($Live) {
    $c = Get-Content $configPath -Raw | ConvertFrom-Json
    $c.LogOnly = $false
    $c | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
    Write-Host 'config.json: LogOnly = false (the watchdog will now restart the service)'
}

# --- secret.bin --------------------------------------------------------------------------------
$secretPath = Join-Path $InstallDir 'secret.bin'
if ($NewSecret -or -not (Test-Path $secretPath)) {
    $s = Read-Host -AsSecureString "Client secret `"$($p.Secret)`" for SPN-Fabric-Refresh-Automation (Value, not ID)"
    Protect-WatchdogSecret -Secret $s -Path $secretPath
    Write-Host 'Stored the secret (DPAPI, LocalMachine)'
}

# --- lock the folder: SYSTEM + Administrators only -----------------------------------------------
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in 'S-1-5-18', 'S-1-5-32-544') {   # SYSTEM, BUILTIN\Administrators
    $id = (New-Object Security.Principal.SecurityIdentifier $sid)
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($id, 'FullControl',
        'ContainerInherit,ObjectInherit', 'None', 'Allow')))
}
Set-Acl -Path $InstallDir -AclObject $acl    # files inside inherit it
Write-Host 'Folder locked to SYSTEM + Administrators'

# --- scheduled tasks ---------------------------------------------------------------------------
$script = Join-Path $InstallDir 'Invoke-GatewayWatchdog.ps1'
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew `
    -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

function Register-WatchdogTask {
    param([string]$Name, [string]$Mode, $Trigger, [string]$Description)
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$script`" -Mode $Mode"
    Register-ScheduledTask -TaskName $Name -TaskPath '\SPI\' -Action $action -Trigger $Trigger -Principal $principal `
        -Settings $settings -Description $Description -Force | Out-Null
    Write-Host "Registered task \SPI\$Name"
}

$every10 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-WatchdogTask -Name "$($p.Tasks) - Check" -Mode 'Check' -Trigger $every10 `
    -Description "Checks $($p.GatewayName) every 10 min; starts/restarts PBIEgwService and emails. data-projects/projects/jd-bronze-pipelines/gateway-watchdog"
Register-WatchdogTask -Name "$($p.Tasks) - Nightly restart" -Mode 'NightlyRestart' `
    -Trigger (New-ScheduledTaskTrigger -Daily -At '23:30') `
    -Description "Planned nightly restart of PBIEgwService ($($p.GatewayName)). data-projects/projects/jd-bronze-pipelines/gateway-watchdog"

# --- one test pass -----------------------------------------------------------------------------
Write-Host ''
Write-Host 'Test pass (changes nothing):'
& $script -Mode Test
Write-Host ''
Write-Host "Done. Logs: $InstallDir\logs. Send a test email with:"
Write-Host "  & '$script' -Mode Test -SendTestEmail"
