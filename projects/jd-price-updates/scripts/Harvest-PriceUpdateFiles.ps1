<#
.SYNOPSIS
    Harvests new PRICEUPDATE_*.TXT files from the JD price update network
    folder into the OneLake landing area for the Dataflow Gen2 to pick up.
.DESCRIPTION
    For each PRICEUPDATE_*.TXT file in -SourceFolderPath not already present
    in <LandingRootPath>\Archive:
      - Validates the filename matches PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT,
        where BRANCH is 1-3 digits optionally followed by a single letter
        sub-branch/department code (e.g. "97", "11S", "93C")
      - Validates the file's header row (first line, tab-delimited) matches
        the expected 20-column layout
      - If both checks pass: copies the file into both New\ and Archive\
      - If either check fails: copies the file into Quarantine\ only, and
        does NOT add it to Archive\ (so it will be retried -- and re-logged
        -- every run until someone fixes/renames it or manually clears it
        from Quarantine)
    A per-file error (e.g. a transient network glitch or a locked file) is
    logged and skipped -- it does not abort the run for the remaining files.
    Never deletes or modifies anything in -SourceFolderPath.

    ASSUMPTION -- NOT YET CONFIRMED: this script assumes source files are
    written atomically (temp-name + rename, or fully flushed to disk before
    becoming visible in -SourceFolderPath). If JD's export process instead
    writes a file in place (header first, body streamed in afterward), and
    a scheduled run happens to land mid-write, this script could harvest a
    truncated-but-valid-looking file (passes both filename and header
    checks) into New\/Archive\. Nobody has verified how JD's export writes
    these files -- confirm with whoever owns that export before relying on
    this script unattended in production. No file-stability heuristic
    (e.g. skip-if-modified-in-last-N-minutes) has been added here because
    guessing at one without knowing the actual write behavior could just as
    easily introduce a different bug (e.g. permanently skipping a
    legitimately slow but complete write).

    ASSUMPTION -- cross-component: once a file is copied into New\, this
    script does not track whether the (not-yet-built) Fabric-side process
    has consumed it. If this script is killed mid-loop after copying a file
    into New\ but before Archive\, the next run will safely re-detect and
    re-copy it into both (self-healing). But if the Fabric side already
    picked the file up out of New\ in the meantime, that re-copy re-
    introduces the file for reprocessing. Whether that causes a downstream
    duplicate depends entirely on the New\-clearing/append logic (built in
    a later task) being safe to reprocess an identical file -- it must not
    blindly append without considering this.
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
    Optional. If omitted, computed at the start of the script body as a
    logs\harvest-YYYY-MM-DD.log file next to this script. (Deliberately not
    a param default value -- $PSScriptRoot is not reliably populated during
    parameter-default evaluation when the script is launched via
    `-File "full\path"`, which is how Windows Task Scheduler invokes it --
    same bug already found and fixed in Send-JDChangeReportReminder.ps1.
    Left unfixed here, this crashes at parameter-binding time before a
    single log line is written, which is exactly what silently broke the
    daily harvest for 13 days starting 2026-08-07.)
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

    [string]$LogPath
)

$ErrorActionPreference = "Stop"

if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot "..\logs\harvest-$(Get-Date -Format 'yyyy-MM-dd').log"
}

# Branch group accepts an optional trailing single letter (e.g. "11S",
# "93C", "4B") -- confirmed against real data 2026-08-07: ~6% of all files
# across all 10 years of history use a sub-branch/department code (a
# physical branch's Service/Bulk/Inside-sales/etc. sub-location), not a
# bare branch number. These are real, in-scope price-change data -- NOT
# malformed filenames -- and must not be quarantined. The raw sub-branch
# code (e.g. "11S") is captured as-is by this regex's group 4; rolling it
# up to the main numeric branch (e.g. 11) for analysis happens downstream,
# in Raw_PriceUpdate_History.pq, not here. Only a SINGLE trailing letter is
# accepted -- every confirmed real example (11S, 93C, 4B) is one letter.
# A hypothetical multi-letter sub-branch code would be quarantined rather
# than silently mis-parsed, which is the safer failure mode if that ever
# turns out to be wrong.
$FilenamePattern = '^PRICEUPDATE_(\d{2})_(\d{2})_(\d{4})_(\d{1,3}[A-Za-z]?)\.TXT$'

$ExpectedHeader = @(
    "branch", "inmaster_franchise", "part_no", "inmanuf_list_price",
    "inmaster_list_price", "cc_price_decrease", "bin_location", "category",
    "inmaster_on_hand_qty", "inmanuf_replace_price", "inmaster_replace_price",
    "inmanuf_sell_price1", "inmaster_sell_price1", "cost_diff", "list_diff",
    "sel1_diff", "effective_date", "update_code", "part_desc", "sell_price_old"
)

# LEGACY header shape -- confirmed against real historical files 2026-08-07
# (full backfill run): every file from 2016-12-25 through 2018-02-25 uses
# this exact 19-column layout, missing only "sell_price_old" (added to the
# JD export sometime between Jan 2018 and Feb 2020 -- see Task 6's
# Compare-PriceUpdateSchema.ps1 findings in the design spec). Without this,
# Test-PriceUpdateHeader's exact-match check quarantines every one of these
# 141 legitimate historical files -- confirmed: a first full-backfill run
# quarantined exactly 141 files, all in this date range, all sharing this
# identical header. The downstream Fabric M query (Raw_PriceUpdate_History.pq)
# was already built to tolerate a missing column via MissingField.UseNull
# (SellPriceOld comes through as null for these rows) -- that tolerance was
# unreachable until this check was widened to actually let these files past
# the harvest gate.
$LegacyExpectedHeader = $ExpectedHeader | Where-Object { $_ -ne "sell_price_old" }

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
    # Accept EITHER the current 20-column header OR the confirmed legacy
    # 19-column header (missing sell_price_old) -- see $LegacyExpectedHeader
    # above for why. Any other shape (missing/extra/renamed columns beyond
    # this one known, confirmed historical variant) still quarantines.
    $currentDiff = Compare-Object -ReferenceObject $ExpectedHeader -DifferenceObject $columns -CaseSensitive
    $legacyDiff  = Compare-Object -ReferenceObject $LegacyExpectedHeader -DifferenceObject $columns -CaseSensitive
    return ($null -eq $currentDiff) -or ($null -eq $legacyDiff)
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
                # through the date filter unconditionally. The main harvest
                # loop below calls the same Get-FileNameDate helper and will
                # quarantine it as a bad filename, regardless of the date
                # filter in use.
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
    $errorCount       = 0

    foreach ($file in $toHarvest) {
        try {
            # Use the same date-aware helper as the -DateFrom/-DateTo filter
            # above (not a raw shape-only regex match) so a filename like
            # PRICEUPDATE_02_30_2026_1.TXT -- which matches the expected
            # shape but encodes an impossible calendar date -- is caught
            # and quarantined here too. This matters beyond cosmetics: the
            # downstream Fabric M query builds SourceFileDate via #date(),
            # which throws hard on an invalid date, unlike PowerShell's
            # forgiving Get-Date behavior.
            if ($null -eq (Get-FileNameDate -FileName $file.Name)) {
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
        catch {
            # Isolate per-file failures (network hiccup, AV file lock, JD's
            # export process still mid-write, permissions glitch, etc.) so
            # one bad file doesn't abort the run for every other file still
            # waiting in $toHarvest. Reserve the outer try/catch below for
            # genuine setup-level failures (source folder unreachable,
            # landing folders missing).
            Write-HarvestLog "ERROR" "FAILED processing $($file.Name): $($_.Exception.Message)"
            $errorCount++
            continue
        }
    }

    Write-HarvestLog "INFO" "Harvested: $harvestedCount   Quarantined: $quarantinedCount   Errors: $errorCount"
    Write-HarvestLog "INFO" "Harvest-PriceUpdateFiles - COMPLETED SUCCESSFULLY"
}
catch {
    Write-HarvestLog "ERROR" "Harvest-PriceUpdateFiles - FAILED: $($_.Exception.Message)"
    $exitCode = 1
}

exit $exitCode
