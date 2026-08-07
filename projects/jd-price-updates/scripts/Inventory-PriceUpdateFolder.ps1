<#
.SYNOPSIS
    Inventories PRICEUPDATE_*.TXT files in the JD price update source folder.
.DESCRIPTION
    Lists every file matching PRICEUPDATE_*.TXT in -SourcePath, parses the
    branch and date out of each filename, and reports summary stats: file
    count, oldest/newest date, total size, distinct branch count, and any
    filenames that don't match the expected naming pattern.
.PARAMETER SourcePath
    Path to scan. Pass the real network folder path when running against
    production; pass a local test folder path when developing/testing.
.EXAMPLE
    .\Inventory-PriceUpdateFolder.ps1 -SourcePath "\\<server>\...\Price_Update"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath
)

$ErrorActionPreference = "Stop"

$FilenamePattern = '^PRICEUPDATE_(\d{2})_(\d{2})_(\d{4})_(\d{1,3})\.TXT$'

$allFiles = Get-ChildItem -Path $SourcePath -Filter "PRICEUPDATE_*.TXT" -File

$parsed = foreach ($f in $allFiles) {
    if ($f.Name -match $FilenamePattern) {
        $mmddyyyy = "$($Matches[1])$($Matches[2])$($Matches[3])"
        $fileDate = [datetime]::MinValue
        $isValidDate = [datetime]::TryParseExact(
            $mmddyyyy, "MMddyyyy",
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$fileDate)

        if ($isValidDate) {
            [PSCustomObject]@{
                FileName  = $f.Name
                Branch    = [int]$Matches[4]
                FileDate  = $fileDate
                SizeBytes = $f.Length
                Matched   = $true
            }
        } else {
            [PSCustomObject]@{
                FileName  = $f.Name
                Branch    = $null
                FileDate  = $null
                SizeBytes = $f.Length
                Matched   = $false
            }
        }
    } else {
        [PSCustomObject]@{
            FileName  = $f.Name
            Branch    = $null
            FileDate  = $null
            SizeBytes = $f.Length
            Matched   = $false
        }
    }
}

$matched   = $parsed | Where-Object { $_.Matched }
$unmatched = $parsed | Where-Object { -not $_.Matched }

Write-Host "=== PRICEUPDATE Folder Inventory ==="
Write-Host "Source path:            $SourcePath"
Write-Host "Total files found:      $($allFiles.Count)"
Write-Host "Filename pattern OK:    $($matched.Count)"
Write-Host "Filename pattern FAIL:  $($unmatched.Count)"

$oldestDate = $null
$newestDate = $null
$totalSize  = 0
$branchCount = 0

if ($matched.Count -gt 0) {
    $oldestDate  = ($matched | Sort-Object FileDate | Select-Object -First 1).FileDate
    $newestDate  = ($matched | Sort-Object FileDate | Select-Object -Last 1).FileDate
    $totalSize   = ($matched | Measure-Object SizeBytes -Sum).Sum
    $branchCount = ($matched | Select-Object -ExpandProperty Branch -Unique).Count

    Write-Host "Oldest file date:       $($oldestDate.ToString('yyyy-MM-dd'))"
    Write-Host "Newest file date:       $($newestDate.ToString('yyyy-MM-dd'))"
    Write-Host "Total size (matched):   $([math]::Round($totalSize / 1MB, 2)) MB"
    Write-Host "Distinct branches seen: $branchCount"
}

if ($unmatched.Count -gt 0) {
    Write-Host ""
    Write-Host "Files that did NOT match the expected naming pattern:"
    $unmatched | ForEach-Object { Write-Host "  $($_.FileName)" }
}

[PSCustomObject]@{
    TotalFiles       = $allFiles.Count
    MatchedFiles     = $matched.Count
    UnmatchedFiles   = $unmatched.Count
    OldestDate       = $oldestDate
    NewestDate       = $newestDate
    TotalSizeBytes   = $totalSize
    DistinctBranches = $branchCount
}
