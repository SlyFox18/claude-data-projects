<#
.SYNOPSIS
    Harvests new PRICEUPDATE_*.TXT files from the JD price update network
    folder into the OneLake landing area for the Dataflow Gen2 to pick up.
.DESCRIPTION
    For each PRICEUPDATE_*.TXT file in -SourceFolderPath not already present
    in <LandingRootPath>\Archive:
      - Validates the filename matches PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT
      - Validates the file's header row (first line, tab-delimited) matches
        the expected 19-column layout
      - If both checks pass: copies the file into both New\ and Archive\
      - If either check fails: copies the file into Quarantine\ only, and
        does NOT add it to Archive\ (so it will be retried -- and re-logged
        -- every run until someone fixes/renames it or manually clears it
        from Quarantine)
    Never deletes or modifies anything in -SourceFolderPath.
.PARAMETER SourceFolderPath
    The network folder containing PRICEUPDATE_*.TXT files.
.PARAMETER LandingRootPath
    Local path to the OneLake-mounted PriceUpdate_Landing folder. Must
    already contain New\, Archive\, and Quarantine\ subfolders.
.PARAMETER DateFrom
    Optional. Only consider source files whose filename date is on or after
    this date. Use this to chunk a large historical backfill (e.g. one year
    at a time) instead of harvesting everything in a single run.
.PARAMETER DateTo
    Optional. Only consider source files whose filename date is on or before
    this date.
.PARAMETER LogPath
    Optional. Defaults to a logs\harvest-YYYY-MM-DD.log file next to this
    script.
.EXAMPLE
    .\Harvest-PriceUpdateFiles.ps1 -SourceFolderPath "\\<server>\...\Price_Update" -LandingRootPath "C:\Users\bfox\OneLake - Microsoft\LH_Master_Data.Lakehouse\Files\PriceUpdate_Landing"
.EXAMPLE
    # Backfill just 2018 as a first chunk
    .\Harvest-PriceUpdateFiles.ps1 -SourceFolderPath "\\<server>\...\Price_Update" -LandingRootPath "...\PriceUpdate_Landing" -DateFrom "2018-01-01" -DateTo "2018-12-31"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolderPath,

    [Parameter(Mandatory = $true)]
    [string]$LandingRootPath,

    [Nullable[datetime]]$DateFrom = $null,
    [Nullable[datetime]]$DateTo = $null,

    [string]$LogPath = (Join-Path $PSScriptRoot "..\logs\harvest-$(Get-Date -Format 'yyyy-MM-dd').log")
)

$ErrorActionPreference = "Stop"

$FilenamePattern = '^PRICEUPDATE_(\d{2})_(\d{2})_(\d{4})_(\d{1,3})\.TXT$'

$ExpectedHeader = @(
    "branch", "inmaster_franchise", "part_no", "inmanuf_list_price",
    "inmaster_list_price", "cc_price_decrease", "bin_location", "category",
    "inmaster_on_hand_qty", "inmanuf_replace_price", "inmaster_replace_price",
    "inmanuf_sell_price1", "inmaster_sell_price1", "cost_diff", "list_diff",
    "sel1_diff", "effective_date", "update_code", "part_desc", "sell_price_old"
)

function Write-HarvestLog {
    param([string]$Level, [string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $line
    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $LogPath -Value $line
}

function Test-PriceUpdateHeader {
    param([string]$FilePath)
    $firstLine = Get-Content -Path $FilePath -TotalCount 1
    $columns = $firstLine -split "`t"
    # -CaseSensitive: the downstream Power Query parser selects columns by
    # exact-match name (case-sensitive), so a header that differs only in
    # case (e.g. "Branch" vs "branch") must NOT be treated as a match here --
    # otherwise the file would be harvested and then fail (or silently
    # mis-map columns) in the Dataflow Gen2.
    $diff = Compare-Object -ReferenceObject $ExpectedHeader -DifferenceObject $columns -CaseSensitive
    return ($null -eq $diff)
}

function Get-FileNameDate {
    # Safely parses the MM/DD/YYYY embedded in a PRICEUPDATE filename.
    # Returns $null if the filename doesn't match the pattern at all, OR if
    # the digits match the shape but do not form a real calendar date (e.g.
    # PRICEUPDATE_02_30_2026_1.TXT). Deliberately uses TryParseExact instead
    # of `Get-Date -Year -Month -Day`, which silently rolls invalid dates
    # over to the next valid one (Feb 30 -> Mar 2) instead of rejecting them,
    # and throws on genuinely out-of-range values (e.g. month 13) -- which
    # would abort this entire run under $ErrorActionPreference = "Stop"
    # before a single file gets harvested, just because one file elsewhere
    # in the source folder has a malformed date in its name.
    param([string]$FileName)

    if ($FileName -notmatch $FilenamePattern) {
        return $null
    }

    $mmddyyyy = "$($Matches[1])$($Matches[2])$($Matches[3])"
    $parsed = [datetime]::MinValue
    $isValid = [datetime]::TryParseExact(
        $mmddyyyy, "MMddyyyy",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed)

    if ($isValid) { return $parsed }
    return $null
}

Write-HarvestLog "INFO" "Harvest-PriceUpdateFiles - Start"
Write-HarvestLog "INFO" "Source: $SourceFolderPath"
Write-HarvestLog "INFO" "Landing root: $LandingRootPath"

$newPath        = Join-Path $LandingRootPath "New"
$archivePath    = Join-Path $LandingRootPath "Archive"
$quarantinePath = Join-Path $LandingRootPath "Quarantine"

foreach ($p in @($newPath, $archivePath, $quarantinePath)) {
    if (-not (Test-Path $p)) {
        throw "Required landing folder not found: $p -- create New\, Archive\, and Quarantine\ under $LandingRootPath before running this script."
    }
}

$exitCode = 0

try {
    $sourceFiles = Get-ChildItem -Path $SourceFolderPath -Filter "PRICEUPDATE_*.TXT" -File

    if ($DateFrom -or $DateTo) {
        $sourceFiles = $sourceFiles | Where-Object {
            $fileDate = Get-FileNameDate -FileName $_.Name
            if ($null -ne $fileDate) {
                (-not $DateFrom -or $fileDate -ge $DateFrom) -and (-not $DateTo -or $fileDate -le $DateTo)
            } else {
                # Can't determine a real date for this file (either the
                # filename doesn't match the expected shape at all, or it
                # matches but encodes an impossible calendar date) -- let it
                # through so filename validation below still catches and
                # quarantines it, regardless of the date filter in use.
                $true
            }
        }
    }

    $alreadyArchived = (Get-ChildItem -Path $archivePath -Filter "*.TXT" -File).Name

    $toHarvest = $sourceFiles | Where-Object { $alreadyArchived -notcontains $_.Name }

    Write-HarvestLog "INFO" "Source files matching filter: $($sourceFiles.Count)"
    Write-HarvestLog "INFO" "Already archived (skipped):   $($sourceFiles.Count - $toHarvest.Count)"
    Write-HarvestLog "INFO" "New candidates to harvest:    $($toHarvest.Count)"

    $harvestedCount   = 0
    $quarantinedCount = 0

    foreach ($file in $toHarvest) {
        if ($file.Name -notmatch $FilenamePattern) {
            Copy-Item -Path $file.FullName -Destination (Join-Path $quarantinePath $file.Name) -Force
            Write-HarvestLog "WARN" "QUARANTINED (bad filename): $($file.Name)"
            $quarantinedCount++
            continue
        }

        if (-not (Test-PriceUpdateHeader -FilePath $file.FullName)) {
            Copy-Item -Path $file.FullName -Destination (Join-Path $quarantinePath $file.Name) -Force
            Write-HarvestLog "WARN" "QUARANTINED (bad header):   $($file.Name)"
            $quarantinedCount++
            continue
        }

        Copy-Item -Path $file.FullName -Destination (Join-Path $newPath $file.Name) -Force
        Copy-Item -Path $file.FullName -Destination (Join-Path $archivePath $file.Name) -Force
        Write-HarvestLog "INFO" "Harvested: $($file.Name)"
        $harvestedCount++
    }

    Write-HarvestLog "INFO" "Harvested: $harvestedCount   Quarantined: $quarantinedCount"
    Write-HarvestLog "INFO" "Harvest-PriceUpdateFiles - COMPLETED SUCCESSFULLY"
}
catch {
    Write-HarvestLog "ERROR" "Harvest-PriceUpdateFiles - FAILED: $($_.Exception.Message)"
    $exitCode = 1
}

exit $exitCode
