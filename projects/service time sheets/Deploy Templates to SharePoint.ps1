
<#
.SYNOPSIS
    Uploads location templates to their _Template subfolders in SharePoint.
    Run this after regenerating templates with generate_templates.py.
#>

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes "Files.ReadWrite.All", "Sites.ReadWrite.All"

# Get site and drive
$site = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/spitractor.sharepoint.com:/sites/SouthPlainsImplement-ServicePayroll"
$drives = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/sites/$($site.id)/drives"
$driveId = ($drives.value | Where-Object { $_.name -eq "Service Time Sheets" }).id

if (-not $driveId) {
    Write-Host "ERROR: Could not find 'Service Time Sheets' drive. Check SharePoint connection." -ForegroundColor Red
    exit 1
}

Write-Host "Connected to SharePoint.`n" -ForegroundColor Green

$templateDir = Join-Path $PSScriptRoot "templates"

$locations = @(
    @{ Folder = "Abernathy";   Template = "ABERNATHY - Service Time Sheet Template.xlsm" },
    @{ Folder = "Big Spring";  Template = "BIG SPRING - Service Time Sheet Template.xlsm" },
    @{ Folder = "Brownfield";  Template = "BROWNFIELD - Service Time Sheet Template.xlsm" },
    @{ Folder = "Lamesa";      Template = "LAMESA - Service Time Sheet Template.xlsm" },
    @{ Folder = "Levelland";   Template = "LEVELLAND - Service Time Sheet Template.xlsm" },
    @{ Folder = "Littlefield"; Template = "LITTLEFIELD - Service Time Sheet Template.xlsm" },
    @{ Folder = "Lorenzo";     Template = "LORENZO - Service Time Sheet Template.xlsm" },
    @{ Folder = "Lubbock";     Template = "LUBBOCK - Service Time Sheet Template.xlsm" },
    @{ Folder = "Morton";      Template = "MORTON - Service Time Sheet Template.xlsm" },
    @{ Folder = "San Angelo";  Template = "SAN ANGELO - Service Time Sheet Template.xlsm" },
    @{ Folder = "Seminole";    Template = "SEMINOLE - Service Time Sheet Template.xlsm" },
    @{ Folder = "Slaton";      Template = "SLATON - Service Time Sheet Template.xlsm" },
    @{ Folder = "Snyder";      Template = "SNYDER - Service Time Sheet Template.xlsm" },
    @{ Folder = "Tahoka";      Template = "TAHOKA - Service Time Sheet Template.xlsm" }
    # Add Mesquite and Tornillo here once their tech lists are in config/TECH LEVELS.csv
)

$success = 0
$failed  = 0
$locked  = 0
$lockedFolders = [System.Collections.Generic.List[string]]::new()

foreach ($loc in $locations) {
    $filePath = Join-Path $templateDir $loc.Template
    if (-not (Test-Path $filePath)) {
        Write-Host "  SKIP $($loc.Folder) — template file not found" -ForegroundColor Yellow
        continue
    }

    Write-Host "Uploading: $($loc.Folder)..." -ForegroundColor Cyan
    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $folder    = [System.Uri]::EscapeDataString($loc.Folder)
        $file      = [System.Uri]::EscapeDataString($loc.Template)
        $uri       = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$folder/_Template/$file`:/content"
        Invoke-MgGraphRequest -Method PUT -Uri $uri -Body $fileBytes `
            -ContentType "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" | Out-Null
        Write-Host "  OK" -ForegroundColor Green
        $success++

        # Remove the old .xlsx if it still exists in the same folder
        $oldTemplateName = $loc.Template -replace '\.xlsm$', '.xlsx'
        $oldFile = [System.Uri]::EscapeDataString($oldTemplateName)
        $deleteUri = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$folder/_Template/$oldFile"
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri $deleteUri | Out-Null
            Write-Host "  Removed old .xlsx" -ForegroundColor DarkGray
        } catch {
            # 404 means it's already gone — that's fine
        }
    } catch {
        if ($_.ToString() -match '423|resourceLocked|resource.*locked') {
            Write-Host "  LOCKED — file is open by someone. Close it in SharePoint/Excel and re-run." -ForegroundColor Yellow
            $locked++
            $lockedFolders.Add($loc.Folder)
        } else {
            Write-Host "  FAILED: $_" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host "`n_Template folders: $success uploaded, $failed failed, $locked locked." -ForegroundColor Yellow

# ── Update the top-level Templates library ────────────────────────────────────
$templatesDriveId = ($drives.value | Where-Object { $_.name -eq "Templates" }).id

if (-not $templatesDriveId) {
    Write-Host "WARNING: Could not find 'Templates' library — skipping." -ForegroundColor Yellow
} else {
    Write-Host "`nUpdating Templates library..." -ForegroundColor Cyan
    $tSuccess = 0
    $tFailed  = 0

    foreach ($loc in $locations) {
        $filePath = Join-Path $templateDir $loc.Template
        if (-not (Test-Path $filePath)) { continue }

        $file = [System.Uri]::EscapeDataString($loc.Template)

        # Upload new .xlsm
        try {
            $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
            $uri = "https://graph.microsoft.com/v1.0/drives/$templatesDriveId/root:/$file`:/content"
            Invoke-MgGraphRequest -Method PUT -Uri $uri -Body $fileBytes `
                -ContentType "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" | Out-Null
            Write-Host "  $($loc.Folder) OK" -ForegroundColor Green
            $tSuccess++

            # Delete old .xlsx from Templates library
            $oldTemplateName = $loc.Template -replace '\.xlsm$', '.xlsx'
            $oldFile = [System.Uri]::EscapeDataString($oldTemplateName)
            $deleteUri = "https://graph.microsoft.com/v1.0/drives/$templatesDriveId/root:/$oldFile"
            try {
                Invoke-MgGraphRequest -Method DELETE -Uri $deleteUri | Out-Null
                Write-Host "    Removed old .xlsx" -ForegroundColor DarkGray
            } catch {
                # 404 = already gone
            }
        } catch {
            if ($_.ToString() -match '423|resourceLocked|resource.*locked') {
                Write-Host "  $($loc.Folder) LOCKED — file is open by someone. Close it and re-run." -ForegroundColor Yellow
                $locked++
                if (-not $lockedFolders.Contains($loc.Folder)) { $lockedFolders.Add($loc.Folder) }
            } else {
                Write-Host "  $($loc.Folder) FAILED: $_" -ForegroundColor Red
                $tFailed++
            }
        }
    }

    Write-Host "`nTemplates library: $tSuccess uploaded, $tFailed failed." -ForegroundColor Yellow
}

if ($lockedFolders.Count -gt 0) {
    Write-Host "`nLocked locations (re-run after files are closed):" -ForegroundColor Yellow
    foreach ($f in $lockedFolders) { Write-Host "  - $f" -ForegroundColor Yellow }
}

Write-Host "`nAll done." -ForegroundColor Green
