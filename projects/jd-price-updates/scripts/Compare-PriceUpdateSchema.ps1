<#
.SYNOPSIS
    Compares the header row (column names) of two or more PRICEUPDATE files.
.DESCRIPTION
    Reads the first line of each given file, splits on tab, and reports
    whether all files share an identical column list. Use this to check
    whether the file layout has drifted across years before finalizing the
    Dataflow Gen2 parsing logic.
.PARAMETER FilePaths
    Two or more file paths to compare. The first path is treated as the
    baseline that the others are compared against.
.EXAMPLE
    .\Compare-PriceUpdateSchema.ps1 -FilePaths "C:\old\PRICEUPDATE_01_02_2018_1.TXT","C:\new\PRICEUPDATE_08_02_2026_1.TXT"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$FilePaths
)

$ErrorActionPreference = "Stop"

if ($FilePaths.Count -lt 2) {
    throw "Provide at least two file paths to compare."
}

$headers = foreach ($path in $FilePaths) {
    $firstLine = Get-Content -Path $path -TotalCount 1
    [PSCustomObject]@{
        FilePath = $path
        Columns  = $firstLine -split "`t"
    }
}

$baseline = $headers[0]
$allMatch = $true

Write-Host "=== PRICEUPDATE Schema Comparison ==="
Write-Host "Baseline: $($baseline.FilePath)"
Write-Host "Baseline columns ($($baseline.Columns.Count)): $($baseline.Columns -join ', ')"
Write-Host ""

foreach ($h in $headers[1..($headers.Count - 1)]) {
    $diff = Compare-Object -ReferenceObject $baseline.Columns -DifferenceObject $h.Columns
    if ($null -eq $diff) {
        Write-Host "MATCH:    $($h.FilePath)"
    } else {
        $allMatch = $false
        Write-Host "MISMATCH: $($h.FilePath)"
        Write-Host "  Columns ($($h.Columns.Count)): $($h.Columns -join ', ')"
        foreach ($d in $diff) {
            $side = if ($d.SideIndicator -eq "<=") { "only in baseline" } else { "only in this file" }
            Write-Host "  DIFF: '$($d.InputObject)' ($side)"
        }
    }
}

Write-Host ""
if ($allMatch) {
    Write-Host "RESULT: All files share an identical column layout."
} else {
    Write-Host "RESULT: Column layout differs across files -- parsing logic must handle this defensively."
}

return $allMatch
