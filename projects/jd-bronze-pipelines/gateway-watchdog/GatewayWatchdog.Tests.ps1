# Pester 3.4 syntax (what Windows PowerShell 5.1 ships). Run:
#   powershell -NoProfile -Command "Invoke-Pester .\projects\jd-bronze-pipelines\gateway-watchdog"
Import-Module (Join-Path $PSScriptRoot 'GatewayWatchdog.psm1') -Force

$config = @{ ServiceName = 'PBIEgwService'; ProbeHost = 'ncu.frontend.clouddatahub.net'; FailuresBeforeRestart = 2
             MaxRestarts = 3; RestartWindowHours = 6; AlertRepeatHours = 4 }
$now = [datetime]::new(2026, 10, 15, 12, 0, 0, [DateTimeKind]::Utc)

function Obs {
    param([string]$Service = 'Running', [string]$Gateway = 'Live', [string]$Source = 'Ok', $Network = $null)
    @{ Service = $Service; Gateway = $Gateway; GatewayError = 'err'; Source = $Source; SourceError = 'src err'; Network = $Network }
}
function Decide {
    param([hashtable]$Obs, [hashtable]$State = (New-WatchdogState), [datetime]$At = $now)
    Get-WatchdogDecision -Observation $Obs -State $State -Config $config -NowUtc $At
}

Describe 'Get-WatchdogDecision' {

    It 'does nothing and stays quiet when everything is healthy' {
        $d = Decide (Obs)
        $d.Action | Should Be 'None'
        $d.Problem | Should Be $null
        $d.Alert | Should Be $false
        $d.Recovered | Should Be $false
    }

    It 'starts a stopped service at once and alerts' {
        $d = Decide (Obs -Service 'Stopped' -Gateway 'Unknown')
        $d.Action | Should Be 'StartService'
        $d.Problem | Should Be 'service-stopped'
        $d.Alert | Should Be $true
        $d.State.Restarts.Count | Should Be 1
    }

    It 'waits for a second failed check before restarting a running-but-offline gateway' {
        $first = Decide (Obs -Gateway 'Offline')
        $first.Action | Should Be 'None'
        $first.Alert | Should Be $false
        $first.State.ConsecutiveFailures | Should Be 1

        $second = Decide (Obs -Gateway 'Offline') -State $first.State
        $second.Action | Should Be 'RestartService'
        $second.Problem | Should Be 'gateway-offline'
        $second.Alert | Should Be $true
        $second.State.ConsecutiveFailures | Should Be 0
        $second.State.Restarts.Count | Should Be 1
    }

    It 'resets the failure count when the gateway is Live again before a restart' {
        $first = Decide (Obs -Gateway 'Offline')
        $d = Decide (Obs) -State $first.State
        $d.State.ConsecutiveFailures | Should Be 0
        $d.Action | Should Be 'None'
    }

    It 'gives up after MaxRestarts within the window' {
        $state = New-WatchdogState
        $state.Restarts = @($now.AddHours(-1).ToString('o'), $now.AddHours(-2).ToString('o'), $now.AddHours(-3).ToString('o'))
        $state.ConsecutiveFailures = 1
        $d = Decide (Obs -Gateway 'Offline') -State $state
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'gave-up'
        $d.Alert | Should Be $true
    }

    It 'gives up on a stopped service too once the cap is reached' {
        $state = New-WatchdogState
        $state.Restarts = @($now.AddMinutes(-10).ToString('o'), $now.AddMinutes(-20).ToString('o'), $now.AddMinutes(-30).ToString('o'))
        $d = Decide (Obs -Service 'Stopped') -State $state
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'gave-up'
    }

    It 'forgets restarts older than the window' {
        $state = New-WatchdogState
        $state.Restarts = @($now.AddHours(-7).ToString('o'), $now.AddHours(-8).ToString('o'), $now.AddHours(-9).ToString('o'))
        $state.ConsecutiveFailures = 1
        $d = Decide (Obs -Gateway 'Offline') -State $state
        $d.Action | Should Be 'RestartService'
        $d.State.Restarts.Count | Should Be 1
    }

    It 'alerts but never restarts when Equip is unreachable through a Live gateway' {
        $d = Decide (Obs -Source 'Failed')
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'source-failed'
        $d.Alert | Should Be $true
    }

    It 'does not repeat the same alert until AlertRepeatHours have passed' {
        $first = Decide (Obs -Source 'Failed')
        $again = Decide (Obs -Source 'Failed') -State $first.State -At $now.AddMinutes(10)
        $again.Alert | Should Be $false
        $later = Decide (Obs -Source 'Failed') -State $again.State -At $now.AddHours(4)
        $later.Alert | Should Be $true
    }

    It 'always alerts when it takes an action, even for an already alerted problem' {
        $state = New-WatchdogState
        $state.LastAlertKey = 'service-stopped'; $state.LastAlertUtc = $now.AddMinutes(-10).ToString('o')
        $state.OpenProblem = 'service-stopped'
        $d = Decide (Obs -Service 'Stopped') -State $state
        $d.Action | Should Be 'StartService'
        $d.Alert | Should Be $true
    }

    It 'reports recovery once and clears the open problem' {
        $bad = Decide (Obs -Source 'Failed')
        $good = Decide (Obs) -State $bad.State -At $now.AddMinutes(10)
        $good.Recovered | Should Be $true
        $good.Alert | Should Be $false
        $good.State.OpenProblem | Should Be $null
        $quiet = Decide (Obs) -State $good.State -At $now.AddMinutes(20)
        $quiet.Recovered | Should Be $false
    }

    It 'blames the network, not the gateway, when Fabric is unreachable from this server' {
        $d = Decide (Obs -Gateway 'Unknown' -Network $false)
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'network'
    }

    It 'reports its own failure when it cannot ask Fabric but the network is fine' {
        $state = New-WatchdogState; $state.ConsecutiveFailures = 1
        $d = Decide (Obs -Gateway 'Unknown' -Network $true) -State $state
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'cannot-check'
        $d.State.ConsecutiveFailures | Should Be 1
    }

    It 'cannot fix a missing service' {
        $d = Decide (Obs -Service 'Missing' -Gateway 'Unknown')
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'service-missing'
        $d.Alert | Should Be $true
    }
}

Describe 'Read-WatchdogState / Save-WatchdogState' {

    It 'round-trips the state, including a single restart and alert time' {
        $path = Join-Path $TestDrive 'state.json'
        $d = Decide (Obs -Service 'Stopped')
        Save-WatchdogState -Path $path -State $d.State
        $back = Read-WatchdogState -Path $path
        @($back.Restarts).Count | Should Be 1
        $back.LastAlertKey | Should Be 'service-stopped'
        $next = Decide (Obs -Service 'Stopped') -State $back -At $now.AddMinutes(10)
        $next.State.Restarts.Count | Should Be 2
    }

    It 'starts fresh from a missing or corrupt file' {
        $path = Join-Path $TestDrive 'bad.json'
        Set-Content -Path $path -Value '{not json'
        (Read-WatchdogState -Path $path).ConsecutiveFailures | Should Be 0
        (Read-WatchdogState -Path (Join-Path $TestDrive 'none.json')).ConsecutiveFailures | Should Be 0
    }
}
