#=============================================================================
# Test Power BI Connection and Export
# Purpose: Verify we can connect and export data from your Power BI model
#=============================================================================

# UPDATE THESE WITH YOUR IDs:
$WorkspaceId = "ba9d8de4-ef13-44e6-9156-e23a2511f3ad"    # From Step 1
$DatasetId = "bdecebfa-be8a-4cb6-8fa0-554316c8a1c9"        # From Step 2

Write-Host "=== Testing Power BI Connection ===" -ForegroundColor Cyan
Write-Host "Workspace ID: $WorkspaceId"
Write-Host "Dataset ID: $DatasetId"
Write-Host ""

try {
    # Connect to Power BI
    Write-Host "1. Connecting to Power BI..." -ForegroundColor Yellow
    Connect-PowerBIServiceAccount
    Write-Host "   ✓ Connected successfully!" -ForegroundColor Green

    # Test basic dataset access
    Write-Host "2. Testing dataset access..." -ForegroundColor Yellow
    $dataset = Get-PowerBIDataset -WorkspaceId $WorkspaceId -DatasetId $DatasetId
    Write-Host "   ✓ Found dataset: $($dataset.Name)" -ForegroundColor Green

    # Test measure export
    Write-Host "3. Testing measure export..." -ForegroundColor Yellow
    
    $requestBody = @{
        queries = @(
            @{
                query = "EVALUATE INFO.MEASURES()"
            }
        )
        serializerSettings = @{
            includeNulls = $false
        }
    } | ConvertTo-Json -Depth 10

    $measures = Invoke-PowerBIRestMethod -Url "groups/$WorkspaceId/datasets/$DatasetId/executeQueries" -Method Post -Body $requestBody
    $measuresData = $measures | ConvertFrom-Json
    
    $measureCount = $measuresData.results[0].tables[0].rows.Count
    Write-Host "   ✓ Successfully exported $measureCount measures!" -ForegroundColor Green

    # Show sample of measures
    Write-Host "4. Sample of your measures:" -ForegroundColor Yellow
    $measuresData.results[0].tables[0].rows | Select-Object -First 5 | ForEach-Object {
        Write-Host "   - $($_.'[Name]')" -ForegroundColor White
    }

    # Test table export
    Write-Host "5. Testing table export..." -ForegroundColor Yellow
    
    $tableRequestBody = @{
        queries = @(
            @{
                query = "EVALUATE INFO.TABLES()"
            }
        )
        serializerSettings = @{
            includeNulls = $false
        }
    } | ConvertTo-Json -Depth 10

    $tables = Invoke-PowerBIRestMethod -Url "groups/$WorkspaceId/datasets/$DatasetId/executeQueries" -Method Post -Body $tableRequestBody
    $tablesData = $tables | ConvertFrom-Json
    
    $tableCount = $tablesData.results[0].tables[0].rows.Count
    Write-Host "   ✓ Successfully exported $tableCount tables!" -ForegroundColor Green

    # Show your tables
    Write-Host "6. Your tables:" -ForegroundColor Yellow
    $tablesData.results[0].tables[0].rows | ForEach-Object {
        Write-Host "   - $($_.'[Name]')" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "=== SUCCESS! Everything is working! ===" -ForegroundColor Green
    Write-Host "You're ready to set up full automation." -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "=== ERROR OCCURRED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "1. Check that your Workspace ID and Dataset ID are correct" -ForegroundColor White
    Write-Host "2. Make sure you have access to the workspace" -ForegroundColor White
    Write-Host "3. Verify the dataset is published and accessible" -ForegroundColor White
}

# Keep the window open so you can see the results
Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Cyan
Read-Host