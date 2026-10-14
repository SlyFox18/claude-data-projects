# JD Price Update Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Tasks 1–5 are marked `[AUTOMATABLE]` — pure file edits/script development in this repo, testable end-to-end against synthetic local fixtures, that a subagent can do entirely inside this workspace. Tasks 6–11 are marked `[MANUAL]` — they require the real network share, the real OneLake-mounted path, Windows Task Scheduler registration (elevation), or the Fabric portal UI, and must be done by Brian on his own machine/tenant. Do not attempt to script or automate a `[MANUAL]` task. `data-projects` is a local query-library/docs workspace, not Fabric-integrated — the `.pq` file this plan produces is a reference copy Brian pastes into the Fabric Dataflow Gen2 editor; editing it here does not change what's deployed.

**Goal:** Stand up a reliable, CU-light pipeline that harvests JD's daily `PRICEUPDATE_*.TXT` branch price-change files from a network folder and lands them, parsed and lineage-tagged, in a new `Raw_PriceUpdate_History` table in `LH_Master_Data` — with a full historical backfill (files go back to at least 2018) plus ongoing daily incremental capture.

**Architecture:** A PowerShell script (`Harvest-PriceUpdateFiles.ps1`), scheduled daily on Brian's machine (which already hosts the `SPI-Data-Gateway` and the existing `fabric-monitoring` scheduled tasks), copies new files into an OneLake `Files/PriceUpdate_Landing/New/` folder (rotated) and a permanent `Archive/` folder, quarantining anything with an unrecognized filename or header layout into `Quarantine/`. A Fabric Pipeline then runs a Dataflow Gen2 that parses whatever is in `New/` (by column name, not position, to tolerate possible historical schema drift) and appends it to the raw table, clearing `New/` only after a confirmed successful append. The expensive part (scanning years of small files) never touches Fabric CU — it's a plain OS file operation. See `docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md` for the full design rationale, including why branch does not affect pricing values (only assortment) and why Approach A (gateway folder-connector) and Approach C (notebook-only) were rejected.

**Tech Stack:** PowerShell (harvest + inventory + schema-check scripts, Windows Task Scheduler), OneLake File Explorer (local file copy into Lakehouse Files, no API calls needed), Fabric Dataflow Gen2 (Power Query M, folder/file parsing), Fabric Data Pipeline (Dataflow activity + Delete Data activity), DuckDB (`delta_scan` against the local OneLake mount, for verification queries — same pattern as the existing Kurt Sales ad-hoc analysis).

---

## Task 1 [AUTOMATABLE]: Project scaffold + folder inventory script

**Files:**
- Create: `projects/jd-price-updates/README.md`
- Create: `projects/jd-price-updates/scripts/Inventory-PriceUpdateFolder.ps1`

This is the first of the "open items" from the design spec: before deciding how to chunk the historical backfill, we need real numbers (file count, oldest date, total size) from the actual folder. This script produces those numbers; Task 6 is where it actually gets run against the real network path.

- [ ] **Step 1: Create the project folder and a stub README**

```markdown
# JD Price Updates

Ingests John Deere `PRICEUPDATE_*.TXT` branch price-change files from a
network folder into `LH_Master_Data.Raw_PriceUpdate_History`.

**Design spec:** `docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md`
**Implementation plan:** `docs/superpowers/plans/2026-08-06-jd-price-update-ingestion.md`

Full operational details (real paths, schedule, Fabric object names) are
filled in below once the pipeline is actually built — see the
implementation plan's later tasks.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/Inventory-PriceUpdateFolder.ps1` | One-off: counts files, finds oldest/newest date, total size in the source folder. Used to size the historical backfill. |
| `scripts/Compare-PriceUpdateSchema.ps1` | One-off: compares the header row of two or more files to check for column drift across years. |
| `scripts/Harvest-PriceUpdateFiles.ps1` | Daily scheduled: copies new files into the OneLake landing area. |
| `scripts/Register-HarvestPriceUpdateTask.ps1` | One-off setup: registers the daily Windows Scheduled Task for the harvest script. |

_(Setup instructions, real paths, and Fabric object names to be added once built — see implementation plan Tasks 6–12.)_
```

- [ ] **Step 2: Write `Inventory-PriceUpdateFolder.ps1`**

```powershell
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
        [PSCustomObject]@{
            FileName  = $f.Name
            Branch    = [int]$Matches[4]
            FileDate  = Get-Date -Year $Matches[3] -Month $Matches[1] -Day $Matches[2]
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
```

- [ ] **Step 3: Test against a synthetic fixture folder**

```powershell
$testRoot = Join-Path $env:TEMP "priceupdate-inventory-test"
Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

# Two valid files, different branches and dates
"branch`tinmaster_franchise`tpart_no" | Set-Content (Join-Path $testRoot "PRICEUPDATE_08_02_2026_97.TXT")
"branch`tinmaster_franchise`tpart_no" | Set-Content (Join-Path $testRoot "PRICEUPDATE_01_15_2018_1.TXT")
# One file that doesn't match the naming pattern
"not a price update file" | Set-Content (Join-Path $testRoot "PRICEUPDATE_BADNAME.TXT")
# One unrelated file that should be ignored entirely
"irrelevant" | Set-Content (Join-Path $testRoot "SOMEOTHERFILE.TXT")

& "projects/jd-price-updates/scripts/Inventory-PriceUpdateFolder.ps1" -SourcePath $testRoot
```

Expected output includes:
```
Total files found:      3
Filename pattern OK:    2
Filename pattern FAIL:  1
Oldest file date:       2018-01-15
Newest file date:       2026-08-02
Distinct branches seen: 2
...
Files that did NOT match the expected naming pattern:
  PRICEUPDATE_BADNAME.TXT
```
`SOMEOTHERFILE.TXT` must not appear anywhere in the output — confirms the `-Filter "PRICEUPDATE_*.TXT"` is doing its job.

- [ ] **Step 4: Clean up the test fixture and commit**

```powershell
Remove-Item (Join-Path $env:TEMP "priceupdate-inventory-test") -Recurse -Force
```

```bash
git add "projects/jd-price-updates/README.md" "projects/jd-price-updates/scripts/Inventory-PriceUpdateFolder.ps1"
git commit -m "Add JD price update project scaffold + folder inventory script"
```

---

## Task 2 [AUTOMATABLE]: Schema comparison script

**Files:**
- Create: `projects/jd-price-updates/scripts/Compare-PriceUpdateSchema.ps1`

Resolves the design spec's other open item: whether the column layout has drifted since 2018. This script does the comparison; Task 6 runs it for real.

- [ ] **Step 1: Write `Compare-PriceUpdateSchema.ps1`**

```powershell
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
```

- [ ] **Step 2: Test with matching fixtures**

```powershell
$testRoot = Join-Path $env:TEMP "priceupdate-schema-test"
Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

"branch`tpart_no`teffective_date" | Set-Content (Join-Path $testRoot "file_a.txt")
"branch`tpart_no`teffective_date" | Set-Content (Join-Path $testRoot "file_b.txt")

& "projects/jd-price-updates/scripts/Compare-PriceUpdateSchema.ps1" -FilePaths (Join-Path $testRoot "file_a.txt"), (Join-Path $testRoot "file_b.txt")
```

Expected: `MATCH:` for `file_b.txt`, final line `RESULT: All files share an identical column layout.`, return value `$true`.

- [ ] **Step 3: Test with a mismatched fixture (extra column)**

```powershell
"branch`tpart_no`teffective_date`tupdate_code" | Set-Content (Join-Path $testRoot "file_c.txt")

& "projects/jd-price-updates/scripts/Compare-PriceUpdateSchema.ps1" -FilePaths (Join-Path $testRoot "file_a.txt"), (Join-Path $testRoot "file_c.txt")
```

Expected: `MISMATCH:` for `file_c.txt`, a `DIFF: 'update_code' (only in this file)` line, final `RESULT: Column layout differs...`, return value `$false`.

- [ ] **Step 4: Clean up and commit**

```powershell
Remove-Item (Join-Path $env:TEMP "priceupdate-schema-test") -Recurse -Force
```

```bash
git add "projects/jd-price-updates/scripts/Compare-PriceUpdateSchema.ps1"
git commit -m "Add PRICEUPDATE schema comparison script"
```

---

## Task 3 [AUTOMATABLE]: Harvest script

**Files:**
- Create: `projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1`

The core daily script. Copies new, valid files into `New/` and `Archive/`; routes anything with a bad filename or bad header into `Quarantine/`; never touches the source folder; supports an optional date-range filter so a large historical backfill can be chunked (e.g. one year at a time) if Task 6's inventory shows that's needed.

- [ ] **Step 1: Write `Harvest-PriceUpdateFiles.ps1`**

```powershell
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
    $diff = Compare-Object -ReferenceObject $ExpectedHeader -DifferenceObject $columns
    return ($null -eq $diff)
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
            if ($_.Name -match $FilenamePattern) {
                $fileDate = Get-Date -Year $Matches[3] -Month $Matches[1] -Day $Matches[2]
                (-not $DateFrom -or $fileDate -ge $DateFrom) -and (-not $DateTo -or $fileDate -le $DateTo)
            } else {
                # Can't determine a date for a badly-named file -- let it
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
```

- [ ] **Step 2: Build a synthetic test rig**

```powershell
$testRoot   = Join-Path $env:TEMP "priceupdate-harvest-test"
Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue

$sourceDir  = Join-Path $testRoot "Source"
$landingDir = Join-Path $testRoot "Landing"
New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $landingDir "New") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $landingDir "Archive") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $landingDir "Quarantine") -Force | Out-Null

$validHeader = "branch`tinmaster_franchise`tpart_no`tinmanuf_list_price`tinmaster_list_price`tcc_price_decrease`tbin_location`tcategory`tinmaster_on_hand_qty`tinmanuf_replace_price`tinmaster_replace_price`tinmanuf_sell_price1`tinmaster_sell_price1`tcost_diff`tlist_diff`tsel1_diff`teffective_date`tupdate_code`tpart_desc`tsell_price_old"

# Two valid files
"$validHeader`n97`tD`t57M11134`t39.30`t15.82`t-59.75`tSV5D15`tTY`t0`t26.33`t10.60`t0`t42.57`t15.73`t23.48`t25.19`t8/3/2026`t`tELEC. CONN`t17.38" |
    Set-Content (Join-Path $sourceDir "PRICEUPDATE_08_02_2026_97.TXT")
"$validHeader`n1`tD`tRE51650`t81.87`t90.96`t11.10`tC13`tEN`t0`t54.85`t60.94`t0`t81.87`t-6.09`t-9.09`t-9.09`t8/3/2026`t`tSEDIMENT B`t90.96" |
    Set-Content (Join-Path $sourceDir "PRICEUPDATE_08_02_2026_1.TXT")

& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath $sourceDir -LandingRootPath $landingDir
```

Expected: `Harvested: 2   Quarantined: 0`. Confirm:
```powershell
(Get-ChildItem (Join-Path $landingDir "New")).Count        # expect 2
(Get-ChildItem (Join-Path $landingDir "Archive")).Count    # expect 2
(Get-ChildItem (Join-Path $landingDir "Quarantine")).Count # expect 0
```

- [ ] **Step 3: Verify idempotency (re-run with no new source files)**

```powershell
& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath $sourceDir -LandingRootPath $landingDir
```

Expected log line: `New candidates to harvest:    0` and `Harvested: 0   Quarantined: 0`. `New\` still has exactly 2 files (not cleared by the harvest script itself — that's the pipeline's job, tested separately in Task 9).

- [ ] **Step 4: Verify bad-filename quarantine**

```powershell
"$validHeader`n1`tD`tX`t1`t1`t1`tA1`tTY`t0`t1`t1`t0`t1`t1`t1`t1`t8/3/2026`t`tX`t1" |
    Set-Content (Join-Path $sourceDir "PRICEUPDATE_BADNAME.TXT")

& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath $sourceDir -LandingRootPath $landingDir
```

Expected log line: `QUARANTINED (bad filename): PRICEUPDATE_BADNAME.TXT`. Confirm:
```powershell
Test-Path (Join-Path $landingDir "Quarantine\PRICEUPDATE_BADNAME.TXT")   # expect True
Test-Path (Join-Path $landingDir "Archive\PRICEUPDATE_BADNAME.TXT")     # expect False
```

- [ ] **Step 5: Verify bad-header quarantine**

```powershell
"wrong`theader`tlayout`n1`t2`t3" | Set-Content (Join-Path $sourceDir "PRICEUPDATE_08_03_2026_5.TXT")

& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath $sourceDir -LandingRootPath $landingDir
```

Expected log line: `QUARANTINED (bad header): PRICEUPDATE_08_03_2026_5.TXT`. Confirm it landed in `Quarantine\` and not `Archive\`, same checks as Step 4.

- [ ] **Step 6: Verify the `-DateFrom`/`-DateTo` chunking filter**

```powershell
"$validHeader`n1`tD`tX`t1`t1`t1`tA1`tTY`t0`t1`t1`t0`t1`t1`t1`t1`t1/15/2018`t`tX`t1" |
    Set-Content (Join-Path $sourceDir "PRICEUPDATE_01_15_2018_1.TXT")

& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath $sourceDir -LandingRootPath $landingDir -DateFrom "2026-01-01" -DateTo "2026-12-31"
```

Expected: the 2018 file is excluded by the date filter (does NOT appear in the harvested or quarantined counts for this run — the log's "New candidates to harvest" count should not include it). Confirm:
```powershell
Test-Path (Join-Path $landingDir "Archive\PRICEUPDATE_01_15_2018_1.TXT")   # expect False (not yet harvested)
```
Then run again without the date filter and confirm it *does* get harvested:
```powershell
& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath $sourceDir -LandingRootPath $landingDir
Test-Path (Join-Path $landingDir "Archive\PRICEUPDATE_01_15_2018_1.TXT")   # expect True
```

- [ ] **Step 7: Confirm the log file was written correctly**

```powershell
Get-Content (Join-Path $PSScriptRoot "..\logs\harvest-$(Get-Date -Format 'yyyy-MM-dd').log") -ErrorAction SilentlyContinue
```
(Run from inside `projects/jd-price-updates/scripts/`, or adjust the path — the log lands at `projects/jd-price-updates/logs/harvest-<today>.log` relative to the script.) Expected: every `INFO`/`WARN` line from the steps above, in order, each prefixed with a timestamp.

- [ ] **Step 8: Clean up test fixtures and commit**

```powershell
Remove-Item (Join-Path $env:TEMP "priceupdate-harvest-test") -Recurse -Force
Remove-Item "projects/jd-price-updates/logs" -Recurse -Force -ErrorAction SilentlyContinue
```

```bash
git add "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1"
git commit -m "Add PRICEUPDATE harvest script with quarantine + date-range chunking"
```

---

## Task 4 [AUTOMATABLE]: Scheduled task registration script

**Files:**
- Create: `projects/jd-price-updates/scripts/Register-HarvestPriceUpdateTask.ps1`

Mirrors the existing `projects/fabric-monitoring/scripts/scheduled/Register-ScheduledTasks.ps1` pattern. The script itself is written and committed here; actually running it (it requires Administrator elevation and the real paths) is Task 8.

- [ ] **Step 1: Write `Register-HarvestPriceUpdateTask.ps1`**

```powershell
<#
.SYNOPSIS
    Registers the daily Windows Scheduled Task that runs
    Harvest-PriceUpdateFiles.ps1.
.DESCRIPTION
    Must be run as Administrator. Creates a task named
    "JD Price Update Harvest" under Task Scheduler Library \ Fabric,
    running daily. Fill in -SourceFolderPath and -LandingRootPath with the
    real values determined in the implementation plan's Task 6/7 before
    running this.
.PARAMETER SourceFolderPath
    The real network folder path (kept out of source control -- pass it at
    registration time, not hardcoded here).
.PARAMETER LandingRootPath
    The real local OneLake-mounted PriceUpdate_Landing path.
.PARAMETER TriggerTime
    Time of day to run, as "HH:mm". Defaults to 02:00 (well before the main
    Fabric pipeline's 4:15 AM start, so the day's harvest is sitting in
    New\ before the Fabric-side pipeline runs).
.EXAMPLE
    .\Register-HarvestPriceUpdateTask.ps1 -SourceFolderPath "\\<server>\...\Price_Update" -LandingRootPath "C:\Users\bfox\OneLake - Microsoft\LH_Master_Data.Lakehouse\Files\PriceUpdate_Landing"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolderPath,

    [Parameter(Mandatory = $true)]
    [string]$LandingRootPath,

    [string]$TriggerTime = "02:00"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Harvest-PriceUpdateFiles.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Harvest-PriceUpdateFiles.ps1 not found next to this script at $scriptPath"
}

$taskName = "JD Price Update Harvest"
$taskPath = "\Fabric\"

$argumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -SourceFolderPath `"$SourceFolderPath`" -LandingRootPath `"$LandingRootPath`""

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentList
$trigger = New-ScheduledTaskTrigger -Daily -At $TriggerTime
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force

Write-Host "Registered scheduled task '$taskPath$taskName' to run daily at $TriggerTime."
Write-Host "Verify in Task Scheduler: Task Scheduler Library -> Fabric -> $taskName"
```

- [ ] **Step 2: Commit** (execution/verification happens in Task 8, once real paths exist)

```bash
git add "projects/jd-price-updates/scripts/Register-HarvestPriceUpdateTask.ps1"
git commit -m "Add scheduled task registration script for PRICEUPDATE harvest"
```

---

## Task 5 [AUTOMATABLE]: Raw table parsing query (Power Query M reference)

**Files:**
- Create: `.claude/queries/raw-tables/Raw_PriceUpdate_History.pq`

Per repo convention, the actual Dataflow Gen2 is built in the Fabric portal (Task 9) — this file is the reference copy that gets pasted into its Advanced Editor.

- [ ] **Step 1: Write `Raw_PriceUpdate_History.pq`**

```powerquery
/*
============================================================================
Query: Raw_PriceUpdate_History
Dataflow: df_Raw_PriceUpdate_History
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Parses JD PRICEUPDATE_*.TXT files landed by
Harvest-PriceUpdateFiles.ps1 into OneLake Files/PriceUpdate_Landing/New,
and appends parsed rows to Raw_PriceUpdate_History. Source data for future
parts-pricing trend/margin analysis. See
docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md.

GRAIN: One row per Branch + PartNumber + EffectiveDate + SourceFileName
(raw event log -- NOT deduplicated across branches or files. The same
part+date can legitimately appear in multiple branches' files -- that's an
assortment signal, not a duplicate. See design spec for why the natural key
for future price-trend analysis is PartNumber + EffectiveDate, not
Branch + PartNumber + EffectiveDate.)

SOURCE: OneLake Lakehouse Files -- LH_Master_Data / Files /
PriceUpdate_Landing / New (folder connector, configured via the Dataflow
Gen2 "Get Data > Lakehouse > Files" wizard -- the wizard-generated step
becomes `Source` below; replace the placeholder name with whatever the
wizard actually names it).

DESTINATION LOAD SETTING: APPEND, not Replace. New/ only ever contains
files not yet successfully ingested (a Fabric Pipeline step clears New/
after this dataflow succeeds -- see Task 9), so every refresh's rows are
genuinely new rows.

DO NOT filter/dedupe by PartNumber+EffectiveDate here -- that decision
belongs to the future analysis layer, not this raw ingestion layer.

`category` is passed through as-is; mapping it to dim_Parts'
CommodityCode/SLC classifications is an analysis-phase concern.
============================================================================
*/

let
    // Placeholder name -- replace with whatever the Dataflow Gen2 "Get Data
    // > Lakehouse > Files" wizard actually names this step when pointed at
    // PriceUpdate_Landing/New. It produces a table with columns including
    // [Content] (binary) and [Name] (text) plus other file-system metadata.
    Source = LakehouseFilesFolder_PriceUpdateLandingNew,

    // Defensive filter -- the harvest script only ever lands valid,
    // header-checked PRICEUPDATE_*.TXT files here, but this costs nothing.
    FilterToPriceUpdateFiles = Table.SelectRows(Source, each
        Text.StartsWith([Name], "PRICEUPDATE_") and Text.EndsWith(Text.Upper([Name]), ".TXT")
    ),

    // ------------------------------------------------------------------
    // Parse Branch + Date out of the filename: PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT
    // ------------------------------------------------------------------
    AddNameParts = Table.AddColumn(FilterToPriceUpdateFiles, "NameParts", each
        Text.Split(Text.BeforeDelimiter([Name], ".", {0, RelativePosition.FromEnd}), "_")),

    AddSourceFileBranch = Table.AddColumn(AddNameParts, "SourceFileBranch", each
        Text.From([NameParts]{4}), type text),

    AddSourceFileDate = Table.AddColumn(AddSourceFileBranch, "SourceFileDate", each
        #date(Number.FromText([NameParts]{3}), Number.FromText([NameParts]{1}), Number.FromText([NameParts]{2})),
        type date),

    // ------------------------------------------------------------------
    // Parse file content: tab-delimited, header row promoted (parses by
    // column NAME downstream via ExpandTableColumn, not position, so a
    // reordered-but-same-named header still works).
    // ------------------------------------------------------------------
    AddParsedContent = Table.AddColumn(AddSourceFileDate, "ParsedContent", each
        Table.PromoteHeaders(
            Csv.Document([Content], [Delimiter = "#(tab)", Encoding = 1252, QuoteStyle = QuoteStyle.None]),
            [PromoteAllScalars = true]
        )),

    SelectForExpand = Table.SelectColumns(AddParsedContent,
        {"Name", "SourceFileBranch", "SourceFileDate", "ParsedContent"}),

    ExpandedRows = Table.ExpandTableColumn(SelectForExpand, "ParsedContent",
        {"branch", "inmaster_franchise", "part_no", "inmanuf_list_price", "inmaster_list_price",
         "cc_price_decrease", "bin_location", "category", "inmaster_on_hand_qty",
         "inmanuf_replace_price", "inmaster_replace_price", "inmanuf_sell_price1",
         "inmaster_sell_price1", "cost_diff", "list_diff", "sel1_diff", "effective_date",
         "update_code", "part_desc", "sell_price_old"}),

    // ------------------------------------------------------------------
    // Rename to PascalCase per repo convention
    // ------------------------------------------------------------------
    RenameColumns = Table.RenameColumns(ExpandedRows, {
        {"Name", "SourceFileName"},
        {"branch", "Branch"},
        {"inmaster_franchise", "Franchise"},
        {"part_no", "PartNumber"},
        {"inmanuf_list_price", "ManufacturerListPrice"},
        {"inmaster_list_price", "DealerListPrice"},
        {"cc_price_decrease", "ListPriceChangePercent"},
        {"bin_location", "BinLocation"},
        {"category", "Category"},
        {"inmaster_on_hand_qty", "OnHandQty"},
        {"inmanuf_replace_price", "ManufacturerReplacePrice"},
        {"inmaster_replace_price", "DealerReplacePrice"},
        {"inmanuf_sell_price1", "ManufacturerSellPrice1"},
        {"inmaster_sell_price1", "DealerSellPrice1"},
        {"cost_diff", "CostDiff"},
        {"list_diff", "ListDiff"},
        {"sel1_diff", "SellPrice1Diff"},
        {"effective_date", "EffectiveDate"},
        {"update_code", "UpdateCode"},
        {"part_desc", "PartDescription"},
        {"sell_price_old", "SellPriceOld"}
    }),

    // ------------------------------------------------------------------
    // Data-quality tripwire: filename branch vs in-file branch
    // ------------------------------------------------------------------
    AddBranchMismatchFlag = Table.AddColumn(RenameColumns, "BranchMismatchFlag", each
        Text.Trim(Text.From([SourceFileBranch])) <> Text.Trim(Text.From([Branch])), type logical),

    // ------------------------------------------------------------------
    // IngestedAt -- DST-aware UTC -> Central, same pattern as
    // .claude/queries/DATA-REFRESH-TEMPLATE.pq
    // ------------------------------------------------------------------
    UtcNow    = DateTimeZone.UtcNow(),
    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
    CurYear   = Date.Year(DateTime.Date(UtcDT)),
    Mar1      = #date(CurYear, 3, 1),
    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
    Nov1      = #date(CurYear, 11, 1),
    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),

    AddIngestedAt = Table.AddColumn(AddBranchMismatchFlag, "IngestedAt", each LocalNow, type datetime),

    // ------------------------------------------------------------------
    // Types + final column order
    // ------------------------------------------------------------------
    ChangedTypes = Table.TransformColumnTypes(AddIngestedAt, {
        {"Branch", Int64.Type}, {"Franchise", type text}, {"PartNumber", type text},
        {"ManufacturerListPrice", type number}, {"DealerListPrice", type number},
        {"ListPriceChangePercent", type number}, {"BinLocation", type text}, {"Category", type text},
        {"OnHandQty", type number}, {"ManufacturerReplacePrice", type number},
        {"DealerReplacePrice", type number}, {"ManufacturerSellPrice1", type number},
        {"DealerSellPrice1", type number}, {"CostDiff", type number}, {"ListDiff", type number},
        {"SellPrice1Diff", type number}, {"EffectiveDate", type date}, {"UpdateCode", type text},
        {"PartDescription", type text}, {"SellPriceOld", type number},
        {"SourceFileName", type text}, {"SourceFileBranch", type text}, {"SourceFileDate", type date}
    }),

    FinalColumnOrder = Table.ReorderColumns(ChangedTypes, {
        "Branch", "PartNumber", "EffectiveDate", "Franchise", "PartDescription", "Category",
        "ManufacturerListPrice", "DealerListPrice", "ListPriceChangePercent",
        "ManufacturerReplacePrice", "DealerReplacePrice", "ManufacturerSellPrice1",
        "DealerSellPrice1", "SellPriceOld", "CostDiff", "ListDiff", "SellPrice1Diff",
        "BinLocation", "OnHandQty", "UpdateCode",
        "SourceFileName", "SourceFileBranch", "SourceFileDate", "BranchMismatchFlag", "IngestedAt"
    })
in
    FinalColumnOrder
```

No automated test is possible for M code outside Fabric — verification happens in Task 9 when this is pasted into the Dataflow Gen2 Advanced Editor and previewed against real landed files.

- [ ] **Step 2: Commit**

```bash
git add ".claude/queries/raw-tables/Raw_PriceUpdate_History.pq"
git commit -m "Add Raw_PriceUpdate_History parsing query reference"
```

---

## Task 6 [MANUAL]: Run discovery scripts against the real folder

**Where:** Brian's machine, PowerShell.

- [ ] **Step 1: Run the inventory script against the real network folder**

```powershell
& "projects/jd-price-updates/scripts/Inventory-PriceUpdateFolder.ps1" -SourcePath "<REAL PRICE_UPDATE NETWORK PATH>"
```

Record the results (total files, oldest date, total size in MB) — they decide whether Task 10's backfill needs chunking. As a rule of thumb: if `TotalSizeBytes` is under ~2 GB or `MatchedFiles` is under ~20,000, run Task 10 as a single unchunked pass. Above that, chunk by year using the `-DateFrom`/`-DateTo` parameters already built into `Harvest-PriceUpdateFiles.ps1` (Task 3).

- [ ] **Step 2: Pick one old file and one recent file, run the schema comparison**

```powershell
& "projects/jd-price-updates/scripts/Compare-PriceUpdateSchema.ps1" -FilePaths "<PATH TO AN EARLY-2018 FILE>", "<PATH TO A RECENT 2026 FILE>"
```

If `MISMATCH`, note exactly which columns differ — the parsing query in Task 5 already handles missing/extra columns gracefully by name, but a genuinely different naming scheme (not just missing/added columns) would need the `Test-PriceUpdateHeader` function in `Harvest-PriceUpdateFiles.ps1` (Task 3) extended to recognize a second valid header shape before running the full backfill, otherwise every older file will get quarantined instead of ingested.

---

## Task 7 [MANUAL]: Create the OneLake landing folder structure

**Where:** OneLake File Explorer, `C:\Users\bfox\OneLake - Microsoft\`.

- [ ] **Step 1: Locate the `LH_Master_Data` lakehouse's Files folder** under the mounted OneLake path and confirm the exact local path (record it — it's `-LandingRootPath` for every later task).

- [ ] **Step 2: Create the landing folder structure**

```powershell
$landingRoot = "<REAL LOCAL ONELAKE PATH>\Files\PriceUpdate_Landing"
New-Item -ItemType Directory -Path (Join-Path $landingRoot "New") -Force
New-Item -ItemType Directory -Path (Join-Path $landingRoot "Archive") -Force
New-Item -ItemType Directory -Path (Join-Path $landingRoot "Quarantine") -Force
```

- [ ] **Step 3: Verify**

```powershell
Test-Path (Join-Path $landingRoot "New")        # expect True
Test-Path (Join-Path $landingRoot "Archive")    # expect True
Test-Path (Join-Path $landingRoot "Quarantine") # expect True
```

---

## Task 8 [MANUAL]: Register and dry-run the scheduled harvest

**Where:** Brian's machine, PowerShell (as Administrator for Step 1).

- [ ] **Step 1: Register the scheduled task**

```powershell
& "projects/jd-price-updates/scripts/Register-HarvestPriceUpdateTask.ps1" -SourceFolderPath "<REAL NETWORK PATH>" -LandingRootPath "<REAL LOCAL ONELAKE PATH>\Files\PriceUpdate_Landing"
```

- [ ] **Step 2: Verify in Task Scheduler** — open Task Scheduler → Task Scheduler Library → Fabric → confirm "JD Price Update Harvest" exists, daily trigger at 02:00.

- [ ] **Step 3: Run it manually once** (right-click → Run, or re-invoke `Harvest-PriceUpdateFiles.ps1` directly with the real paths) against just a small recent date range first, to sanity-check against real data before the full backfill:

```powershell
& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath "<REAL NETWORK PATH>" -LandingRootPath "<REAL LOCAL ONELAKE PATH>\Files\PriceUpdate_Landing" -DateFrom (Get-Date).AddDays(-7) -DateTo (Get-Date)
```

Check the log file at `projects/jd-price-updates/logs/harvest-<today>.log` and confirm `Harvested:` count looks right (roughly `7 days × number of branches carrying at least one changed part that week`), `Quarantined:` is 0 or explainable, and files actually appear in `New\` and `Archive\`.

---

## Task 9 [MANUAL]: Build the Dataflow Gen2 and Fabric Pipeline

**Where:** Fabric, `LH_Master_Data` workspace.

- [ ] **Step 1: Create the Dataflow Gen2** — new Dataflow Gen2 in `01 - Raw Sources`, name it `df_Raw_PriceUpdate_History`. Get Data → Lakehouse → `LH_Master_Data` → navigate to `Files/PriceUpdate_Landing/New`.

- [ ] **Step 2: Paste the parsing logic** — open the Advanced Editor, paste the query from Task 5's `.pq` file, and rename the placeholder `Source = LakehouseFilesFolder_PriceUpdateLandingNew` line's right-hand side to whatever the wizard actually generated for the folder-connection step in Step 1.

- [ ] **Step 3: Preview** — confirm the preview shows the 25 expected output columns (`Branch`, `PartNumber`, `EffectiveDate`, ... `BranchMismatchFlag`, `IngestedAt`) with no errors, using the files Task 8 Step 3 already landed in `New/`.

- [ ] **Step 4: Set the destination** — Lakehouse → `LH_Master_Data` → new table `Raw_PriceUpdate_History` → Update method **Append**. Publish.

- [ ] **Step 5: Create the pipeline** — new Data Pipeline, name it `pl_Raw_PriceUpdate_History`. Add a **Dataflow** activity referencing `df_Raw_PriceUpdate_History`. Add a **Delete data** activity connected on **Success** from the Dataflow activity, targeting the Lakehouse Files path `PriceUpdate_Landing/New` with wildcard `*.TXT` (non-recursive) so it clears the files that were just ingested and nothing in `Archive/` or `Quarantine/`.

- [ ] **Step 6: Run the pipeline manually once** and verify:

```powershell
duckdb -c "SELECT COUNT(*) AS RowCount, COUNT(DISTINCT SourceFileName) AS FileCount FROM delta_scan('<REAL LOCAL ONELAKE PATH>/Tables/Raw_PriceUpdate_History');"
```

Expected: `RowCount` > 0, `FileCount` matches however many files were sitting in `New/` before the run.

```powershell
(Get-ChildItem "<REAL LOCAL ONELAKE PATH>\Files\PriceUpdate_Landing\New").Count
```

Expected: `0` — the Delete data activity cleared it.

---

## Task 10 [MANUAL]: Execute the historical backfill

**Where:** Brian's machine (harvest) + Fabric portal (pipeline runs).

- [ ] **Step 1: Decide chunking** based on Task 6's numbers. If unchunked:

```powershell
& "projects/jd-price-updates/scripts/Harvest-PriceUpdateFiles.ps1" -SourceFolderPath "<REAL NETWORK PATH>" -LandingRootPath "<REAL LOCAL ONELAKE PATH>\Files\PriceUpdate_Landing"
```

If chunking by year, repeat with `-DateFrom "YYYY-01-01" -DateTo "YYYY-12-31"` for each year, running the `pl_Raw_PriceUpdate_History` pipeline (Task 9) after each chunk lands so `New\` never grows unmanageably large between runs.

- [ ] **Step 2: Run `pl_Raw_PriceUpdate_History`** after each harvest chunk (or once, if unchunked).

- [ ] **Step 3: Verify final counts**

```powershell
duckdb -c "SELECT COUNT(*) AS TotalRows, COUNT(DISTINCT SourceFileName) AS TotalFiles, MIN(EffectiveDate) AS EarliestDate, MAX(EffectiveDate) AS LatestDate, SUM(CASE WHEN BranchMismatchFlag THEN 1 ELSE 0 END) AS MismatchCount FROM delta_scan('<REAL LOCAL ONELAKE PATH>/Tables/Raw_PriceUpdate_History');"
```

`TotalFiles` should match Task 6's `MatchedFiles` count. `MismatchCount` should be 0 or a small, explainable number.

- [ ] **Step 4: Review the Quarantine folder** — anything sitting in `PriceUpdate_Landing\Quarantine\` after the full backfill needs a manual look (bad filename typo, genuinely different historical header layout not yet handled, etc.).

---

## Task 11 [MANUAL]: Let daily operation run and confirm steady state

**Where:** Brian's machine + Fabric portal.

- [ ] **Step 1: Let the scheduled task and pipeline run unattended for 2-3 days.**

- [ ] **Step 2: Each morning, verify:**

```powershell
(Get-ChildItem "<REAL LOCAL ONELAKE PATH>\Files\PriceUpdate_Landing\New").Count   # expect 0 (cleared after prior day's successful pipeline run)
```

```powershell
duckdb -c "SELECT COUNT(*) FROM delta_scan('<REAL LOCAL ONELAKE PATH>/Tables/Raw_PriceUpdate_History') WHERE IngestedAt >= CURRENT_DATE;"
```

Expect a small non-zero row count each day (that day's branch files), confirming genuinely incremental, CU-light daily operation as designed.

---

## Task 12 [AUTOMATABLE]: Finalize documentation

**Files:**
- Modify: `projects/jd-price-updates/README.md`

- [ ] **Step 1: Fill in the real operational details** discovered during Tasks 6-11 — the real (redacted-in-git-if-preferred, but at minimum the pattern) source path, the real OneLake landing path, the Fabric object names (`df_Raw_PriceUpdate_History`, `pl_Raw_PriceUpdate_History`), the scheduled task name and trigger time, and the final historical date range actually loaded (from Task 10 Step 3's `EarliestDate`/`LatestDate`).

- [ ] **Step 2: Add a "Next Steps" section** pointing at the two deferred sub-projects from the design spec: JD website Change Report collection, and the margin/trend analysis layer (natural key note: `PartNumber + EffectiveDate`, not `Branch + PartNumber + EffectiveDate`).

- [ ] **Step 3: Commit**

```bash
git add "projects/jd-price-updates/README.md"
git commit -m "Finalize JD price update ingestion documentation with real operational details"
```
