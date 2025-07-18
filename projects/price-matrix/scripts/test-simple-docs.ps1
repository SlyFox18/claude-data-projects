# Test simple documentation
$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"
$measuresFile = "$repo\data\info-exports\current-measures.csv"

Write-Host "Testing documentation generation..." -ForegroundColor Yellow

if (Test-Path $measuresFile) {
    $measures = Import-Csv $measuresFile
    Write-Host "Found $($measures.Count) measures" -ForegroundColor Green
    
    # Show first 3 measure names
    Write-Host "First 3 measures:" -ForegroundColor Yellow
    for ($i = 0; $i -lt 3; $i++) {
        Write-Host "  - $($measures[$i].Name)" -ForegroundColor White
    }
} else {
    Write-Host "Measures file not found at: $measuresFile" -ForegroundColor Red
}

Read-Host "Press Enter to close"