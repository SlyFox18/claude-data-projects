# Simple automation test - Price Matrix Project
Write-Host "=== Testing Automation Setup ===" -ForegroundColor Cyan

$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"

Write-Host "Checking folders..." -ForegroundColor Yellow

# Check required folders
if (Test-Path "$repo\data\info-exports") {
    Write-Host "  OK: data\info-exports exists" -ForegroundColor Green
} else {
    Write-Host "  Creating: data\info-exports" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "$repo\data\info-exports" -Force | Out-Null
    Write-Host "  Created: data\info-exports" -ForegroundColor Green
}

if (Test-Path "$repo\artifacts\exports") {
    Write-Host "  OK: artifacts\exports exists" -ForegroundColor Green  
} else {
    Write-Host "  Creating: artifacts\exports" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "$repo\artifacts\exports" -Force | Out-Null
    Write-Host "  Created: artifacts\exports" -ForegroundColor Green
}

if (Test-Path "$repo\scripts") {
    Write-Host "  OK: scripts folder exists" -ForegroundColor Green
} else {
    Write-Host "  Creating: scripts folder" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "$repo\scripts" -Force | Out-Null
    Write-Host "  Created: scripts folder" -ForegroundColor Green
}

Write-Host ""
Write-Host "Testing Git..." -ForegroundColor Yellow
Set-Location $repo

try {
    $branch = git branch --show-current 2>$null
    if ($branch) {
        Write-Host "  OK: Git is working, branch: $branch" -ForegroundColor Green
    } else {
        Write-Host "  Warning: Git might not be initialized" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Warning: Git not found or not working" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host "Your folder structure is ready!" -ForegroundColor Green

Write-Host ""
Write-Host "Press Enter to close..."
Read-Host