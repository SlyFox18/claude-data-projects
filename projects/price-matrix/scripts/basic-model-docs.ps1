# Super Basic Model Documentation
$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"

Write-Host "Creating basic model documentation..." -ForegroundColor Yellow

# Check if we have the files
$tablesFile = "$repo\data\info-exports\current-tables.csv"
$columnsFile = "$repo\data\info-exports\current-columns.csv"

if (Test-Path $tablesFile) {
    $tables = Import-Csv $tablesFile
    Write-Host "Found $($tables.Count) tables" -ForegroundColor Green
} else {
    Write-Host "No tables file found" -ForegroundColor Red
    $tables = @()
}

if (Test-Path $columnsFile) {
    $columns = Import-Csv $columnsFile
    Write-Host "Found $($columns.Count) columns" -ForegroundColor Green
} else {
    Write-Host "No columns file found" -ForegroundColor Red
    $columns = @()
}

# Create simple documentation
$content = "# Data Model Documentation`n`n"
$content += "Generated: $(Get-Date)`n"
$content += "Tables: $($tables.Count)`n"
$content += "Columns: $($columns.Count)`n`n"

if ($tables.Count -gt 0) {
    $content += "## Tables`n`n"
    foreach ($table in $tables) {
        $tableColumns = $columns | Where-Object { $_.Table -eq $table.Name }
        $content += "### $($table.Name)`n"
        $content += "Columns: $($tableColumns.Count)`n`n"
    }
}

# Save documentation
$docsPath = "$repo\docs"
if (!(Test-Path $docsPath)) {
    New-Item -ItemType Directory -Path $docsPath -Force
}

$docFile = "$docsPath\basic-model-docs.md"
$content | Out-File $docFile -Encoding UTF8

Write-Host "Documentation saved to: $docFile" -ForegroundColor Green

# Try to commit to git
Set-Location $repo
git add docs/*
git commit -m "Basic model documentation"

Write-Host "Done!" -ForegroundColor Green
Read-Host "Press Enter to close"