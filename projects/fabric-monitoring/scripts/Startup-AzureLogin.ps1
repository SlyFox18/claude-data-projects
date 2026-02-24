<#
.SYNOPSIS
    Ensures Azure credentials are cached at Windows startup
.DESCRIPTION
    Runs at startup to cache Azure credentials for scheduled tasks
#>

Write-Host "Checking Azure connection..." -ForegroundColor Cyan

$context = Get-AzContext -ErrorAction SilentlyContinue

if (-not $context) {
    Write-Host "Not connected. Logging in..." -ForegroundColor Yellow
    Connect-AzAccount
} else {
    Write-Host "Already connected as: $($context.Account.Id)" -ForegroundColor Green
}

Write-Host "Azure credentials are ready for scheduled tasks!" -ForegroundColor Green