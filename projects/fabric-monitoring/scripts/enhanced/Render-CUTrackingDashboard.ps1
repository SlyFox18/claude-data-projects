<#
.SYNOPSIS
    Renders Item-CU-Tracking.csv into a self-contained HTML trend dashboard.
.DESCRIPTION
    Reads the running CU snapshot log built by Track-ItemCU.ps1 and generates a
    static HTML page (CU-Tracking.html) with a summary table (latest snapshot per
    item) and an inline SVG trend line per item over time. No external JS/CSS
    dependencies - opens directly in a browser, same pattern as todo.html.

    Each snapshot is a 14-day rolling total (matching the Capacity Metrics app's
    own "Items (14 days)" window - see Track-ItemCU.ps1). This script converts
    each item's CU(s) into a % of the total 14-day capacity budget, so a raw
    number can be read as "big" or "small" relative to what the capacity can
    actually sustain: budget = CapacitySKU_CU * 14 days * 86,400 seconds.
    Cross-checked against the app's own "Avg utilization %" figure - lines up.

    The size bands (negligible/moderate/high) below are this script's own
    reference points for relative-cost triage, not an official Microsoft
    threshold. The one number Microsoft actually treats as "bad" is overall
    capacity utilization approaching/exceeding 100% (throttling risk) - that's
    a capacity-wide figure, not a per-item one, and isn't computed here yet.

    Deliberately NOT wired into Reynard/personal-dashboard - see project memory
    project_personal_dashboard.md for why the "command center" integration is its
    own future brainstorming session, not folded in here.
.EXAMPLE
    .\Render-CUTrackingDashboard.ps1
    .\Render-CUTrackingDashboard.ps1 -CapacitySKU_CU 8   # if capacity is ever upgraded to F8
#>

param(
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation",
    [double]$CapacitySKU_CU = 4,   # F4 = 4 CU sustained
    [int]$WindowDays = 14          # matches Metrics By Item's rolling window
)

$capacityBudgetSeconds = $CapacitySKU_CU * $WindowDays * 86400

function Get-PctBand {
    param([double]$Pct)
    if ($Pct -ge 5)   { return @{ Label = "High";       Class = "band-high" } }
    if ($Pct -ge 1)   { return @{ Label = "Moderate";   Class = "band-moderate" } }
    return @{ Label = "Negligible"; Class = "band-low" }
}

function Format-Duration {
    # Display-only formatting - the underlying CSV keeps raw seconds for
    # precision/consistency with existing history; this just makes the
    # dashboard readable ("2h 34m" / "17m 36s" / "43s" instead of raw seconds).
    param([double]$Seconds)
    if ($Seconds -lt 60) { return "$([math]::Round($Seconds))s" }
    $ts = [TimeSpan]::FromSeconds($Seconds)
    if ($ts.TotalHours -ge 1) {
        return "{0}h {1}m" -f [math]::Floor($ts.TotalHours), $ts.Minutes
    }
    return "{0}m {1}s" -f $ts.Minutes, $ts.Seconds
}

function Format-SvgLine {
    param($Points, [double]$MaxCU)

    $width  = 640
    $height = 160
    $padL   = 40
    $padR   = 10
    $padT   = 10
    $padB   = 24
    $plotW  = $width - $padL - $padR
    $plotH  = $height - $padT - $padB

    $n = $Points.Count
    if ($n -eq 1) {
        $x = $padL + ($plotW / 2)
        $y = $padT + $plotH - ($plotH * ($Points[0].CU / [math]::Max($MaxCU, 0.01)))
        return "<circle cx='$x' cy='$y' r='4' class='dot' />"
    }

    $coords = @()
    for ($i = 0; $i -lt $n; $i++) {
        $x = $padL + ($plotW * $i / ($n - 1))
        $y = $padT + $plotH - ($plotH * ($Points[$i].CU / [math]::Max($MaxCU, 0.01)))
        $coords += "$([math]::Round($x,1)),$([math]::Round($y,1))"
    }
    $polyline = "<polyline points='$($coords -join ' ')' class='trendline' />"

    $dots = ""
    for ($i = 0; $i -lt $n; $i++) {
        $x = $padL + ($plotW * $i / ($n - 1))
        $y = $padT + $plotH - ($plotH * ($Points[$i].CU / [math]::Max($MaxCU, 0.01)))
        $dots += "<circle cx='$([math]::Round($x,1))' cy='$([math]::Round($y,1))' r='3' class='dot'><title>$($Points[$i].Date): $($Points[$i].CU) CU(s)</title></circle>"
    }

    return "$polyline$dots"
}

$logFile  = Join-Path $DocumentationPath "Item-CU-Tracking.csv"
$htmlFile = Join-Path $DocumentationPath "CU-Tracking.html"

if (-not (Test-Path $logFile)) {
    Write-Host "[ERROR] No tracking data found at $logFile - run Track-ItemCU.ps1 first" -ForegroundColor Red
    exit 1
}

$data = Import-Csv $logFile
if (-not $data -or $data.Count -eq 0) {
    Write-Host "[ERROR] Tracking CSV is empty" -ForegroundColor Red
    exit 1
}

$itemGroups = $data | Group-Object -Property { "$($_.ItemName)|$($_.ItemKind)" } |
    Sort-Object -Property { [double](($_.Group | Sort-Object { [datetime]$_.SnapshotTimestamp } | Select-Object -Last 1).'CU(s)') } -Descending

# Days-of-data indicator - trust signal for how much the trend lines actually mean yet
$distinctDates = ($data.SnapshotDate | Select-Object -Unique).Count
$daysNote = if ($distinctDates -eq 1) { "1 day of data so far - trend lines will fill in as more snapshots accumulate" } else { "$distinctDates days of data" }

# Total of tracked items, as a % of the full capacity budget - how much of the
# whole picture these specific items actually represent
$latestPerItem = $data | Group-Object -Property { "$($_.ItemName)|$($_.ItemKind)" } | ForEach-Object {
    $_.Group | Sort-Object { [datetime]$_.SnapshotTimestamp } | Select-Object -Last 1
}
$totalTrackedCU = ($latestPerItem | Measure-Object -Property "CU(s)" -Sum).Sum

# Capacity-wide utilization banner (optional - degrades gracefully if not yet logged)
$utilFile = Join-Path $DocumentationPath "Capacity-Utilization-Tracking.csv"
$utilBanner = ""
$utilTrendSvg = ""
if (Test-Path $utilFile) {
    $utilData = Import-Csv $utilFile
    if ($utilData -and $utilData.Count -gt 0) {
        # Dedupe to one row per date, same reasoning as item tracking
        $utilRows = $utilData |
            Group-Object -Property SnapshotDate |
            ForEach-Object { $_.Group | Sort-Object { [datetime]$_.SnapshotTimestamp } | Select-Object -Last 1 } |
            Sort-Object { [datetime]$_.SnapshotDate }

        $latestUtil = $utilRows[-1]
        $avgUtil    = [double]$latestUtil.AvgUtilizationPct
        $peakUtil   = [double]$latestUtil.PeakUtilizationPct
        $utilBand   = if ($avgUtil -ge 80) { "band-high" } elseif ($avgUtil -ge 60) { "band-moderate" } else { "band-low" }
        $trackedPct = [math]::Round(($totalTrackedCU / $capacityBudgetSeconds) * 100, 2)

        $utilPoints = $utilRows | ForEach-Object { [PSCustomObject]@{ Date = $_.SnapshotDate; CU = [double]$_.AvgUtilizationPct } }
        $utilMax = [math]::Max((($utilPoints | Measure-Object -Property CU -Maximum).Maximum), 1)
        $utilTrendSvg = Format-SvgLine -Points $utilPoints -MaxCU $utilMax

        $utilBanner = @"
  <div class="capacity-banner $utilBand">
    <div class="cap-stat"><span class="cap-num">$avgUtil%</span><span class="cap-label">Avg capacity utilization (last $($latestUtil.WindowDays) days)</span></div>
    <div class="cap-stat"><span class="cap-num">$peakUtil%</span><span class="cap-label">Peak (single 30s window) &mdash; approximate, see note below</span></div>
    <div class="cap-stat"><span class="cap-num">$trackedPct%</span><span class="cap-label">Tracked items below as a share of total capacity</span></div>
    <div class="cap-note">This is the number that actually matters for throttling risk: Microsoft's hard threshold is <strong>overall</strong> utilization approaching/exceeding 100%, not any individual item's cost. As of $($latestUtil.SnapshotDate) &middot; $daysNote.</div>
    <svg viewBox="0 0 640 160" class="chart util-chart">$utilTrendSvg</svg>
  </div>
"@
    }
}

$sections = ""
$summaryRows = ""

foreach ($group in $itemGroups) {
    # Dedupe to one row per calendar date (keep the latest timestamp if the
    # script ran more than once in a day) - otherwise same-day re-runs would
    # plot as fake sequential "days" on the trend line.
    $rows = $group.Group |
        Group-Object -Property SnapshotDate |
        ForEach-Object { $_.Group | Sort-Object { [datetime]$_.SnapshotTimestamp } | Select-Object -Last 1 } |
        Sort-Object { [datetime]$_.SnapshotDate }

    $itemName = $rows[-1].ItemName
    $kind = $rows[-1].ItemKind
    $workspace = $rows[-1].WorkspaceName
    $latestCU = [double]$rows[-1].'CU(s)'
    $latestDuration = [double]$rows[-1].'Duration(s)'
    $latestDate = $rows[-1].SnapshotDate

    $points = $rows | ForEach-Object {
        [PSCustomObject]@{ Date = $_.SnapshotDate; CU = [double]$_.'CU(s)' }
    }
    $maxCU = ($points | Measure-Object -Property CU -Maximum).Maximum
    if ($maxCU -le 0) { $maxCU = 1 }

    $svgBody = Format-SvgLine -Points $points -MaxCU $maxCU

    $trendDirection = ""
    if ($points.Count -ge 2) {
        $first = $points[0].CU
        $last  = $points[-1].CU
        if ($first -gt 0) {
            $pctChange = [math]::Round((($last - $first) / $first) * 100, 1)
            if ($pctChange -lt 0) {
                $trendDirection = "<span class='trend-down'>&#8595; $([math]::Abs($pctChange))% since $($points[0].Date)</span>"
            } elseif ($pctChange -gt 0) {
                $trendDirection = "<span class='trend-up'>&#8593; $pctChange% since $($points[0].Date)</span>"
            } else {
                $trendDirection = "<span class='trend-flat'>No change since $($points[0].Date)</span>"
            }
        }
    }

    $pctOfCapacity = [math]::Round(($latestCU / $capacityBudgetSeconds) * 100, 2)
    $band = Get-PctBand -Pct $pctOfCapacity

    $sections += @"
    <div class="card">
      <h2>$itemName</h2>
      <div class="meta">$kind &middot; $workspace</div>
      <div class="latest">$latestCU CU(s) <span class="asof">as of $latestDate</span></div>
      <div class="pct-badge $($band.Class)">$pctOfCapacity% of $WindowDays-day F$($CapacitySKU_CU.ToString('0')) budget &middot; $($band.Label)</div>
      <div class="trend-note">$trendDirection</div>
      <svg viewBox="0 0 640 160" class="chart">$svgBody</svg>
    </div>
"@

    $formattedDuration = Format-Duration -Seconds $latestDuration
    $summaryRows += "<tr><td>$itemName</td><td>$kind</td><td>$latestCU</td><td>$formattedDuration</td><td class='$($band.Class)'>$pctOfCapacity%</td><td>$latestDate</td></tr>`n"
}

$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Fabric CU Tracking</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
    margin: 0; padding: 24px;
    background: #f5f6f8; color: #1a1a1a;
  }
  @media (prefers-color-scheme: dark) {
    body { background: #14161a; color: #e6e6e6; }
    .card { background: #1e2126 !important; border-color: #2c3038 !important; }
    table { background: #1e2126 !important; }
    th { background: #23262c !important; }
    td, th { border-color: #2c3038 !important; }
    .meta, .asof { color: #9aa0a8 !important; }
  }
  h1 { font-size: 20px; margin-bottom: 4px; }
  .subtitle { color: #666; font-size: 13px; margin-bottom: 24px; }
  table { border-collapse: collapse; width: 100%; margin-bottom: 32px; background: #fff; }
  th, td { text-align: left; padding: 8px 12px; border: 1px solid #ddd; font-size: 13px; }
  th { background: #eee; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; }
  .card { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 16px; }
  .card h2 { font-size: 15px; margin: 0 0 4px 0; }
  .meta { font-size: 12px; color: #777; margin-bottom: 8px; }
  .latest { font-size: 22px; font-weight: 600; }
  .asof { font-size: 12px; font-weight: 400; color: #777; }
  .trend-note { font-size: 12px; margin: 4px 0 8px 0; }
  .trend-down { color: #1a8a3f; }
  .trend-up { color: #c0392b; }
  .trend-flat { color: #888; }
  .pct-badge { display: inline-block; font-size: 11px; font-weight: 600; padding: 3px 8px; border-radius: 12px; margin: 6px 0; }
  .band-low { background: #e4f3ea; color: #1a8a3f; }
  .band-moderate { background: #fdf1d6; color: #9a6a00; }
  .band-high { background: #fbe1de; color: #c0392b; }
  @media (prefers-color-scheme: dark) {
    .band-low { background: #123320; color: #4fd489; }
    .band-moderate { background: #3a2c05; color: #f0b429; }
    .band-high { background: #3a1512; color: #ff8a80; }
  }
  .chart { width: 100%; height: auto; }
  .trendline { fill: none; stroke: #4a7dd8; stroke-width: 2; }
  .dot { fill: #4a7dd8; }
  .capacity-banner { display: flex; flex-wrap: wrap; align-items: center; gap: 24px; border-radius: 8px; padding: 16px 20px; margin-bottom: 20px; }
  .capacity-banner.band-low { background: #e4f3ea; }
  .capacity-banner.band-moderate { background: #fdf1d6; }
  .capacity-banner.band-high { background: #fbe1de; }
  @media (prefers-color-scheme: dark) {
    .capacity-banner.band-low { background: #123320; }
    .capacity-banner.band-moderate { background: #3a2c05; }
    .capacity-banner.band-high { background: #3a1512; }
  }
  .cap-stat { display: flex; flex-direction: column; }
  .cap-num { font-size: 28px; font-weight: 700; }
  .cap-label { font-size: 12px; opacity: 0.8; }
  .cap-note { font-size: 12px; opacity: 0.85; flex-basis: 100%; }
  .util-chart { flex-basis: 100%; max-width: 480px; margin-top: 8px; }
</style>
</head>
<body>
  <h1>Fabric CU Tracking</h1>
$utilBanner
  <div class="subtitle">
    Generated $generatedAt &middot; source: Fabric Capacity Metrics semantic model (Metrics By Item)<br>
    "% of budget" = this item's 14-day CU(s) &divide; total 14-day capacity budget (F$($CapacitySKU_CU.ToString('0')) &times; $WindowDays days &times; 86,400s = $([math]::Round($capacityBudgetSeconds).ToString('N0')) CU-seconds).
    Bands (&lt;1% negligible, 1-5% moderate, &gt;5% high) are a relative-cost reference this dashboard defines, not an official Microsoft threshold &mdash;
    the number Microsoft actually treats as a hard problem is <em>overall</em> capacity utilization approaching/exceeding 100% (throttling risk), which is a separate, capacity-wide figure.
  </div>

  <table>
    <tr><th>Item</th><th>Kind</th><th>Latest CU (s)</th><th>Latest Duration</th><th>% of $WindowDays-day budget</th><th>As of</th></tr>
    $summaryRows
  </table>

  <div class="grid">
    $sections
  </div>
</body>
</html>
"@

$html | Out-File $htmlFile -Encoding UTF8

Write-Host "[SUCCESS] Dashboard rendered: $htmlFile" -ForegroundColor Green
exit 0
