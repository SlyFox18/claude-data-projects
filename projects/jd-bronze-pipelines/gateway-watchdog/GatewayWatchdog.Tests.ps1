# Pester 3.4 syntax (what Windows PowerShell 5.1 ships). Run:
#   powershell -NoProfile -Command "Invoke-Pester .\projects\jd-bronze-pipelines\gateway-watchdog"
Import-Module (Join-Path $PSScriptRoot 'GatewayWatchdog.psm1') -Force

$config = @{ ServiceName = 'PBIEgwService'; ProbeHost = 'ncu.frontend.clouddatahub.net'; FailuresBeforeRestart = 2
             MaxRestarts = 3; RestartWindowHours = 6; AlertRepeatHours = 4; Runbook = 'the-runbook.md' }
$now = [datetime]::new(2026, 10, 15, 12, 0, 0, [DateTimeKind]::Utc)

function Obs {
    param([string]$Service = 'Running', [string]$Gateway = 'Live', [string]$Source = 'Ok', $Network = $null,
          [switch]$Installing)
    @{ Service = $Service; Gateway = $Gateway; GatewayError = 'err'; Source = $Source; SourceError = 'src err'; Network = $Network
       Installing = [bool]$Installing }
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

    It 'waits one check, then starts a stopped service and alerts' {
        $first = Decide (Obs -Service 'Stopped' -Gateway 'Unknown')
        $first.Action | Should Be 'None'
        $first.Alert | Should Be $false
        $first.State.ConsecutiveFailures | Should Be 1

        $d = Decide (Obs -Service 'Stopped' -Gateway 'Unknown') -State $first.State
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
        $state.ConsecutiveFailures = 1
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

    It 'does not alert on the first failed Equip test through a Live gateway' {
        $d = Decide (Obs -Source 'Failed')
        $d.Action | Should Be 'None'
        $d.Problem | Should Be $null
        $d.Alert | Should Be $false
        $d.State.SourceFailures | Should Be 1
        $d.Summary | Should Be 'Equip test through the gateway failed (check 1 of 2 before alerting)'
    }

    It 'alerts but never restarts on the second failed Equip test in a row' {
        $first = Decide (Obs -Source 'Failed')
        $d = Decide (Obs -Source 'Failed') -State $first.State -At $now.AddMinutes(10)
        $d.Action | Should Be 'None'
        $d.Problem | Should Be 'source-failed'
        $d.Alert | Should Be $true
        $d.State.SourceFailures | Should Be 2
    }

    It 'resets the Equip failure count after one failure followed by an Ok test, with no Recovered email' {
        $first = Decide (Obs -Source 'Failed')
        $d = Decide (Obs) -State $first.State -At $now.AddMinutes(10)
        $d.State.SourceFailures | Should Be 0
        $d.Problem | Should Be $null
        $d.Alert | Should Be $false
        $d.Recovered | Should Be $false
    }

    It 'treats a state without SourceFailures (older state.json) as zero' {
        $state = New-WatchdogState
        $state.Remove('SourceFailures')
        $d = Decide (Obs -Source 'Failed') -State $state
        $d.State.SourceFailures | Should Be 1
        $d.Problem | Should Be $null
        $ok = Decide (Obs) -State $state
        $ok.State.SourceFailures | Should Be 0
    }

    It 'alerts on the third Equip failure within 2 hours even when Ok checks come between them' {
        $a = Decide (Obs -Source 'Failed')
        $b = Decide (Obs) -State $a.State -At $now.AddMinutes(10)
        $c = Decide (Obs -Source 'Failed') -State $b.State -At $now.AddMinutes(20)
        $c.Problem | Should Be $null
        $d = Decide (Obs) -State $c.State -At $now.AddMinutes(30)
        $e = Decide (Obs -Source 'Failed') -State $d.State -At $now.AddMinutes(40)
        $e.Problem | Should Be 'source-failed'
        $e.Alert | Should Be $true
        $e.Summary | Should Be 'Equip test through the gateway keeps failing (3 times in the last 2 h)'
    }

    It 'does not count Equip failures older than the window' {
        $a = Decide (Obs -Source 'Failed')
        $b = Decide (Obs -Source 'Failed') -State $a.State -At $now.AddMinutes(5)   # alerts (two in a row)
        $ok = Decide (Obs) -State $b.State -At $now.AddMinutes(10)
        $c = Decide (Obs -Source 'Failed') -State $ok.State -At $now.AddHours(3)
        $c.Problem | Should Be $null
        $c.State.SourceFailureTimes.Count | Should Be 1
    }

    It 'honours SourceFailuresInWindow and SourceFailureWindowHours from the config' {
        $cfg = $config.Clone(); $cfg.SourceFailuresInWindow = 2; $cfg.SourceFailureWindowHours = 1
        $a = Get-WatchdogDecision -Observation (Obs -Source 'Failed') -State (New-WatchdogState) -Config $cfg -NowUtc $now
        $b = Get-WatchdogDecision -Observation (Obs) -State $a.State -Config $cfg -NowUtc $now.AddMinutes(10)
        $c = Get-WatchdogDecision -Observation (Obs -Source 'Failed') -State $b.State -Config $cfg -NowUtc $now.AddMinutes(20)
        $c.Problem | Should Be 'source-failed'
    }

    It 'treats a state without SourceFailureTimes as empty' {
        $state = New-WatchdogState
        $state.Remove('SourceFailureTimes')
        $d = Decide (Obs -Source 'Failed') -State $state
        $d.State.SourceFailureTimes.Count | Should Be 1
        $d.Problem | Should Be $null
    }

    It 'after a gateway restart: reports Recovered on the first Equip failure, alerts source-failed on the second' {
        $state = New-WatchdogState
        $state.OpenProblem = 'gateway-offline'; $state.LastAlertKey = 'gateway-offline'
        $state.LastAlertUtc = $now.AddMinutes(-10).ToString('o')
        $first = Decide (Obs -Source 'Failed') -State $state
        $first.Recovered | Should Be $true
        $first.Problem | Should Be $null
        $second = Decide (Obs -Source 'Failed') -State $first.State -At $now.AddMinutes(10)
        $second.Problem | Should Be 'source-failed'
        $second.Alert | Should Be $true
    }

    It 'resets the Equip failure count when the check is not a Live-gateway check' {
        $first = Decide (Obs -Source 'Failed')
        $off = Decide (Obs -Gateway 'Offline') -State $first.State -At $now.AddMinutes(10)
        $off.State.SourceFailures | Should Be 0
        $stopped = Decide (Obs -Service 'Stopped' -Gateway 'Unknown') -State $first.State -At $now.AddMinutes(10)
        $stopped.State.SourceFailures | Should Be 0
        $unknown = Decide (Obs -Gateway 'Unknown' -Network $true) -State $first.State -At $now.AddMinutes(10)
        $unknown.State.SourceFailures | Should Be 0
        $installing = Decide (Obs -Source 'Failed' -Installing) -State $first.State -At $now.AddMinutes(10)
        $installing.State.SourceFailures | Should Be 0
        $missing = Decide (Obs -Service 'Missing' -Gateway 'Unknown') -State $first.State -At $now.AddMinutes(10)
        $missing.State.SourceFailures | Should Be 0
        # so a failure after the interruption starts counting from 1 again
        $again = Decide (Obs -Source 'Failed') -State $off.State -At $now.AddMinutes(20)
        $again.Problem | Should Be $null
    }

    It 'does not repeat the same alert until AlertRepeatHours have passed' {
        $f1 = Decide (Obs -Source 'Failed')
        $first = Decide (Obs -Source 'Failed') -State $f1.State -At $now.AddMinutes(5)
        $first.Alert | Should Be $true
        $again = Decide (Obs -Source 'Failed') -State $first.State -At $now.AddMinutes(15)
        $again.Alert | Should Be $false
        $later = Decide (Obs -Source 'Failed') -State $again.State -At $now.AddMinutes(5).AddHours(4)
        $later.Alert | Should Be $true
    }

    It 'always alerts when it takes an action, even for an already alerted problem' {
        $state = New-WatchdogState
        $state.LastAlertKey = 'service-stopped'; $state.LastAlertUtc = $now.AddMinutes(-10).ToString('o')
        $state.OpenProblem = 'service-stopped'
        $state.ConsecutiveFailures = 1
        $d = Decide (Obs -Service 'Stopped') -State $state
        $d.Action | Should Be 'StartService'
        $d.Alert | Should Be $true
    }

    It 'reports recovery once and clears the open problem' {
        $bad1 = Decide (Obs -Source 'Failed')
        $bad = Decide (Obs -Source 'Failed') -State $bad1.State -At $now.AddMinutes(5)
        $bad.Alert | Should Be $true
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

    It 'leaves the service alone while the gateway installer runs, and starts counting afresh after' {
        $state = New-WatchdogState; $state.ConsecutiveFailures = 1
        $d = Decide (Obs -Service 'Stopped' -Gateway 'Unknown' -Installing) -State $state
        $d.Action | Should Be 'None'
        $d.Problem | Should Be $null
        $d.Alert | Should Be $false
        $d.State.ConsecutiveFailures | Should Be 0
        $after = Decide (Obs -Service 'Stopped' -Gateway 'Unknown') -State $d.State
        $after.Action | Should Be 'None'
    }

    It 'does not call a service missing while the installer has it removed' {
        $d = Decide (Obs -Service 'Missing' -Gateway 'Unknown' -Installing)
        $d.Problem | Should Be $null
        $d.Alert | Should Be $false
    }

    It 'points the gave-up alert at the configured runbook' {
        $state = New-WatchdogState
        $state.Restarts = @($now.AddMinutes(-10).ToString('o'), $now.AddMinutes(-20).ToString('o'), $now.AddMinutes(-30).ToString('o'))
        $state.ConsecutiveFailures = 1
        $d = Decide (Obs -Gateway 'Offline') -State $state
        $d.Detail | Should Match 'the-runbook\.md'
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
        $first = Decide (Obs -Service 'Stopped')
        $d = Decide (Obs -Service 'Stopped') -State $first.State
        Save-WatchdogState -Path $path -State $d.State
        $back = Read-WatchdogState -Path $path
        @($back.Restarts).Count | Should Be 1
        $back.LastAlertKey | Should Be 'service-stopped'
        $again = Decide (Obs -Service 'Stopped') -State $back -At $now.AddMinutes(10)
        $next = Decide (Obs -Service 'Stopped') -State $again.State -At $now.AddMinutes(20)
        $next.State.Restarts.Count | Should Be 2
    }

    It 'reads an older state.json that has no SourceFailures and decides from it' {
        $path = Join-Path $TestDrive 'old.json'
        Set-Content -Path $path -Value '{"ConsecutiveFailures":0,"Restarts":[],"OpenProblem":null,"LastAlertKey":null,"LastAlertUtc":null}'
        $back = Read-WatchdogState -Path $path
        $back.SourceFailures | Should Be 0
        (Decide (Obs -Source 'Failed') -State $back).State.SourceFailures | Should Be 1
    }

    It 'starts fresh from a missing or corrupt file' {
        $path = Join-Path $TestDrive 'bad.json'
        Set-Content -Path $path -Value '{not json'
        (Read-WatchdogState -Path $path).ConsecutiveFailures | Should Be 0
        (Read-WatchdogState -Path (Join-Path $TestDrive 'none.json')).ConsecutiveFailures | Should Be 0
    }
}
