# Enhanced Model Documentation Generator
$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"

Write-Host "=== Enhanced Model Documentation Generator ===" -ForegroundColor Cyan
Write-Host "Building comprehensive documentation..." -ForegroundColor Yellow

# Read all available files
$tablesFile = "$repo\data\info-exports\current-tables.csv"
$columnsFile = "$repo\data\info-exports\current-columns.csv"
$relationshipsFile = "$repo\data\info-exports\current-relationships.csv"
$measuresFile = "$repo\data\info-exports\current-measures.csv"

Write-Host "Reading data files..." -ForegroundColor Yellow

$tables = @()
$columns = @()
$relationships = @()
$measures = @()

if (Test-Path $tablesFile) {
    $tables = Import-Csv $tablesFile
    Write-Host "  Tables: $($tables.Count)" -ForegroundColor Green
}

if (Test-Path $columnsFile) {
    $columns = Import-Csv $columnsFile
    Write-Host "  Columns: $($columns.Count)" -ForegroundColor Green
}

if (Test-Path $relationshipsFile) {
    $relationships = Import-Csv $relationshipsFile
    Write-Host "  Relationships: $($relationships.Count)" -ForegroundColor Green
}

if (Test-Path $measuresFile) {
    $measures = Import-Csv $measuresFile
    Write-Host "  Measures: $($measures.Count)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Analyzing model structure..." -ForegroundColor Yellow

# Categorize tables
$factTables = $tables | Where-Object { $_.Name -match "Fact_" }
$dimTables = $tables | Where-Object { $_.Name -match "dim_" }
$configTables = $tables | Where-Object { $_.Name -match "Price_Matrix|MeasuresTable" }
$infoTables = $tables | Where-Object { $_.Name -match "Table|Info" }
$otherTables = $tables | Where-Object { $_.Name -notmatch "Fact_|dim_|Price_Matrix|MeasuresTable|Table|Info" }

Write-Host "Table Categories:" -ForegroundColor White
Write-Host "  Fact Tables: $($factTables.Count)" -ForegroundColor Green
Write-Host "  Dimension Tables: $($dimTables.Count)" -ForegroundColor Green
Write-Host "  Configuration Tables: $($configTables.Count)" -ForegroundColor Green
Write-Host "  Info/Metadata Tables: $($infoTables.Count)" -ForegroundColor Green
Write-Host "  Other Tables: $($otherTables.Count)" -ForegroundColor Green

# Build comprehensive documentation
$doc = @"
# Price Matrix Project - Enhanced Data Model Documentation

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm")
**Project:** Price Matrix Analysis System

## Executive Summary

This Power BI data model supports comprehensive price matrix analysis with $($tables.Count) tables, 
$($columns.Count) columns, $($relationships.Count) relationships, and $($measures.Count) DAX measures.

The model follows star schema design principles with clear separation between fact tables 
(transaction data) and dimension tables (master data).

## Model Statistics

| Component | Count | Details |
|-----------|-------|---------|
| **Tables** | $($tables.Count) | $($factTables.Count) fact, $($dimTables.Count) dimension, $($configTables.Count) configuration |
| **Columns** | $($columns.Count) | All attributes and calculated columns |
| **Relationships** | $($relationships.Count) | Star schema connections |
| **Measures** | $($measures.Count) | DAX calculations and KPIs |

---

## Data Model Architecture

### Star Schema Design

The model implements a star schema with centralized fact tables surrounded by dimension tables:

"@

# Add fact tables section
if ($factTables.Count -gt 0) {
    $doc += "`n#### Fact Tables ($($factTables.Count) tables)`n"
    $doc += "Core business data containing transactions and events:`n`n"
    
    foreach ($table in $factTables) {
        $tableColumns = $columns | Where-Object { $_.Table -eq $table.Name }
        $keyColumns = $tableColumns | Where-Object { $_.Name -match "Key" }
        $measureColumns = $tableColumns | Where-Object { $_.DataType -eq "Number" -and $_.Name -notmatch "Key|RowNumber" }
        $dateColumns = $tableColumns | Where-Object { $_.DataType -eq "Date" }
        
        $doc += "**$($table.Name)**`n"
        $doc += "- Purpose: $(Get-TableDescription $table.Name)`n"
        $doc += "- Total Columns: $($tableColumns.Count)`n"
        $doc += "- Key Columns: $($keyColumns.Count) (for relationships)`n"
        $doc += "- Measure Columns: $($measureColumns.Count) (numeric data)`n"
        $doc += "- Date Columns: $($dateColumns.Count) (time dimensions)`n`n"
    }
}

# Add dimension tables section
if ($dimTables.Count -gt 0) {
    $doc += "`n#### Dimension Tables ($($dimTables.Count) tables)`n"
    $doc += "Master data providing context and attributes for analysis:`n`n"
    
    foreach ($table in $dimTables) {
        $tableColumns = $columns | Where-Object { $_.Table -eq $table.Name }
        $keyColumns = $tableColumns | Where-Object { $_.Name -match "Key" }
        $businessColumns = $tableColumns | Where-Object { $_.Name -notmatch "Key|RowNumber" }
        
        $doc += "**$($table.Name)**`n"
        $doc += "- Purpose: $(Get-TableDescription $table.Name)`n"
        $doc += "- Total Columns: $($tableColumns.Count)`n"
        $doc += "- Primary Keys: $($keyColumns.Count)`n"
        $doc += "- Business Attributes: $($businessColumns.Count)`n`n"
    }
}

# Add configuration tables
if ($configTables.Count -gt 0) {
    $doc += "`n#### Configuration Tables ($($configTables.Count) tables)`n"
    $doc += "System configuration and calculated tables:`n`n"
    
    foreach ($table in $configTables) {
        $tableColumns = $columns | Where-Object { $_.Table -eq $table.Name }
        $doc += "**$($table.Name)**`n"
        $doc += "- Purpose: $(Get-TableDescription $table.Name)`n"
        $doc += "- Columns: $($tableColumns.Count)`n`n"
    }
}

# Add relationships section
if ($relationships.Count -gt 0) {
    $doc += "`n### Data Model Relationships`n`n"
    $doc += "The following relationships connect the tables in a star schema:`n`n"
    
    foreach ($rel in $relationships) {
        $doc += "- **$($rel.FromTable)** [$($rel.FromCardinality)] → **$($rel.ToTable)** [$($rel.ToCardinality)]`n"
        $doc += "  - Join: $($rel.FromColumn) = $($rel.ToColumn)`n"
        $doc += "  - Filter Direction: $($rel.CrossFilteringBehavior)`n"
        $doc += "  - Active: $($rel.IsActive)`n`n"
    }
}

# Add key columns analysis
$doc += "`n---`n`n## Key Column Analysis`n`n"

# Find most important columns
$keyColumns = $columns | Where-Object { $_.Name -match "Key|ID" }
$priceColumns = $columns | Where-Object { $_.Name -match "Price|Cost|Amount|Dollars" }
$quantityColumns = $columns | Where-Object { $_.Name -match "Quantity|Sales|Count" }
$dateColumns = $columns | Where-Object { $_.DataType -eq "Date" }

$doc += "### Critical Business Columns`n`n"
$doc += "**Relationship Keys ($($keyColumns.Count) columns)**`n"
$doc += "Essential for connecting tables in the star schema.`n`n"

$doc += "**Price/Financial Columns ($($priceColumns.Count) columns)**`n"
$doc += "Core metrics for pricing analysis and financial calculations.`n`n"

$doc += "**Quantity/Volume Columns ($($quantityColumns.Count) columns)**`n" 
$doc += "Sales volumes and transaction counts for business analysis.`n`n"

$doc += "**Date/Time Columns ($($dateColumns.Count) columns)**`n"
$doc += "Time dimensions for trend analysis and filtering.`n`n"

# Add data sources section
$doc += "`n## Data Sources and Lineage`n`n"
$doc += "### Source Systems`n`n"
$doc += "**Primary Sources:**`n"
$doc += "- SQL Anywhere Database (via ODBC → On-Premises Gateway → Fabric Lakehouse)`n"
$doc += "  - jdis_Part_Information → Fact_Inventory`n"
$doc += "  - InTrans → Fact_Part_Transactions`n"
$doc += "- OneDrive CSV Files`n"
$doc += "  - PRICE MATRIX 7-9-25.csv → Price_Matrix`n`n"

$doc += "**Data Flow:**`n"
$doc += "1. Raw data extracted from source systems`n"
$doc += "2. Loaded into Fabric Lakehouse for processing`n"
$doc += "3. Transformations applied to create clean dimension tables`n"
$doc += "4. Fact tables built with business logic and calculations`n"
$doc += "5. Relationships established to create star schema`n"
$doc += "6. DAX measures added for business calculations`n`n"

# Add usage guidelines
$doc += "`n## Usage Guidelines`n`n"
$doc += "### Performance Best Practices`n`n"
$doc += "**Optimal Filtering:**`n"
$doc += "- Start with Price_Matrix price ranges (value_from, value_to)`n"
$doc += "- Filter dates using Fact_Part_Transactions[TransactionDate]`n"
$doc += "- Use dimension tables for categorical filtering`n"
$doc += "- Filter for active sales: Current12MoSales > 0`n`n"

$doc += "**Common Analysis Patterns:**`n"
$doc += "- **Price Range Analysis:** Use Price_Matrix for segmentation`n"
$doc += "- **Time-Series Analysis:** Filter by TransactionDate ranges`n"
$doc += "- **Geographic Analysis:** Filter through dim_BranchLocation`n"
$doc += "- **Product Analysis:** Use dim_Parts for part-level insights`n`n"

# Add maintenance section
$doc += "`n## Model Maintenance`n`n"
$doc += "### Current Refresh Strategy`n"
$doc += "- **Refresh Method:** Manual (currently)`n"
$doc += "- **Fact Tables:** Refresh together to maintain consistency`n"
$doc += "- **Dimension Tables:** Refresh before fact tables`n"
$doc += "- **Price Matrix:** Update from OneDrive as needed`n`n"

$doc += "### Data Quality Monitoring`n"
$doc += "- Verify relationship integrity after refreshes`n"
$doc += "- Check for unexpected null values in key columns`n"
$doc += "- Validate measure calculations with known test cases`n"
$doc += "- Monitor query performance for complex calculations`n`n"

$doc += "### Model Evolution`n"
$doc += "- Document all schema changes in Git`n"
$doc += "- Test measure impacts before deployment`n"
$doc += "- Maintain backward compatibility when possible`n"
$doc += "- Update documentation automatically with each change`n`n"

$doc += "---`n`n"
$doc += "*This documentation is automatically generated from Power BI model metadata.*`n"
$doc += "*For detailed measure documentation, see dax-measures-complete-guide.md*`n"
$doc += "*Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')*"

# Save enhanced documentation
$docsPath = "$repo\docs"
if (!(Test-Path $docsPath)) {
    New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
}

$docFile = "$docsPath\enhanced-data-model-guide.md"
$doc | Out-File $docFile -Encoding UTF8

Write-Host ""
Write-Host "Enhanced documentation saved!" -ForegroundColor Green
Write-Host "File: enhanced-data-model-guide.md" -ForegroundColor White

# Create detailed table catalog
Write-Host ""
Write-Host "Creating detailed table catalog..." -ForegroundColor Yellow

$catalog = "# Complete Table Catalog`n`n"
$catalog += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"
$catalog += "Comprehensive reference for all $($tables.Count) tables in the data model.`n`n"

foreach ($table in $tables) {
    $tableColumns = $columns | Where-Object { $_.Table -eq $table.Name }
    
    $catalog += "## $($table.Name)`n`n"
    $catalog += "**Category:** $(Get-TableCategory $table.Name)`n"
    $catalog += "**Purpose:** $(Get-TableDescription $table.Name)`n"
    $catalog += "**Total Columns:** $($tableColumns.Count)`n`n"
    
    if ($tableColumns.Count -gt 0) {
        # Group columns by type
        $keyColumns = $tableColumns | Where-Object { $_.Name -match "Key" }
        $businessColumns = $tableColumns | Where-Object { $_.Name -notmatch "Key|RowNumber" -and $_.DataType -ne "Number" }
        $numericColumns = $tableColumns | Where-Object { $_.DataType -eq "Number" -and $_.Name -notmatch "Key" }
        $dateColumns = $tableColumns | Where-Object { $_.DataType -eq "Date" }
        
        if ($keyColumns.Count -gt 0) {
            $catalog += "**Key Columns:**`n"
            foreach ($col in $keyColumns) {
                $catalog += "- $($col.Name) ($($col.DataType))`n"
            }
            $catalog += "`n"
        }
        
        if ($numericColumns.Count -gt 0) {
            $catalog += "**Numeric Columns:**`n"
            foreach ($col in $numericColumns | Select-Object -First 10) {
                $catalog += "- $($col.Name) ($($col.DataType)) - $(Get-ColumnDescription $col.Name)`n"
            }
            if ($numericColumns.Count -gt 10) {
                $catalog += "- ...and $($numericColumns.Count - 10) more numeric columns`n"
            }
            $catalog += "`n"
        }
        
        if ($dateColumns.Count -gt 0) {
            $catalog += "**Date Columns:**`n"
            foreach ($col in $dateColumns) {
                $catalog += "- $($col.Name) ($($col.DataType))`n"
            }
            $catalog += "`n"
        }
        
        if ($businessColumns.Count -gt 0) {
            $catalog += "**Business Attributes:**`n"
            foreach ($col in $businessColumns | Select-Object -First 8) {
                $catalog += "- $($col.Name) ($($col.DataType)) - $(Get-ColumnDescription $col.Name)`n"
            }
            if ($businessColumns.Count -gt 8) {
                $catalog += "- ...and $($businessColumns.Count - 8) more attributes`n"
            }
            $catalog += "`n"
        }
    }
    
    $catalog += "---`n`n"
}

$catalogFile = "$docsPath\table-catalog.md"
$catalog | Out-File $catalogFile -Encoding UTF8

Write-Host "Table catalog saved: table-catalog.md" -ForegroundColor Green

# Commit to Git
Write-Host ""
Write-Host "Committing enhanced documentation..." -ForegroundColor Yellow
Set-Location $repo

try {
    git add "docs/*"
    git commit -m "auto: Generate enhanced data model documentation - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin main
    Write-Host "Successfully committed to Git!" -ForegroundColor Green
} catch {
    Write-Host "Git operation had issues, but files were created" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Enhanced Documentation Complete! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files Created:" -ForegroundColor Yellow
Write-Host "  📊 enhanced-data-model-guide.md - Comprehensive model documentation" -ForegroundColor Green
Write-Host "  📚 table-catalog.md - Detailed table and column reference" -ForegroundColor Green
Write-Host ""
Write-Host "Your Model Summary:" -ForegroundColor Yellow
Write-Host "  Total Tables: $($tables.Count)" -ForegroundColor White
Write-Host "  - Fact Tables: $($factTables.Count)" -ForegroundColor Cyan
Write-Host "  - Dimension Tables: $($dimTables.Count)" -ForegroundColor Cyan
Write-Host "  - Configuration: $($configTables.Count)" -ForegroundColor Cyan
Write-Host "  - Info/Metadata: $($infoTables.Count)" -ForegroundColor Cyan
Write-Host "  Total Columns: $($columns.Count)" -ForegroundColor White
Write-Host "  Total Relationships: $($relationships.Count)" -ForegroundColor White
Write-Host "  Total Measures: $($measures.Count)" -ForegroundColor White

# Helper functions
function Get-TableCategory($tableName) {
    if ($tableName -match "Fact_") { return "Fact Table" }
    elseif ($tableName -match "dim_") { return "Dimension Table" }
    elseif ($tableName -match "Price_Matrix") { return "Configuration Table" }
    elseif ($tableName -match "MeasuresTable") { return "Calculated Table" }
    elseif ($tableName -match "Table|Info") { return "Metadata Table" }
    else { return "Data Table" }
}

function Get-TableDescription($tableName) {
    switch -Regex ($tableName) {
        "Fact_Inventory" { return "Core inventory and sales data with 12-month rolling metrics" }
        "Fact_Part_Transactions" { return "Individual sales transactions with customer and margin details" }
        "dim_Parts" { return "Part master data with descriptions and franchise assignments" }
        "dim_BranchLocation" { return "Branch and location master data for geographic analysis" }
        "dim_Franchise" { return "Franchise master data for organizational reporting" }
        "Price_Matrix" { return "Price range configuration with target margin percentages" }
        "MeasuresTable" { return "Container table for DAX measures (Power BI calculated table)" }
        "Data Refresh" { return "System table tracking data refresh timestamps" }
        default { return "Supporting table for specialized analysis or system functions" }
    }
}

function Get-ColumnDescription($columnName) {
    switch -Regex ($columnName) {
        "PartNumber" { return "Unique part identifier" }
        "ListPrice" { return "Manufacturer list price" }
        "Current12MoSales" { return "Rolling 12-month sales quantity" }
        "Current12MoDollars" { return "Rolling 12-month sales revenue" }
        "SaleAmount" { return "Transaction sales value" }
        "Margin" { return "Transaction profit margin dollars" }
        "MarginPercent" { return "Transaction profit margin percentage" }
        "TransactionDate" { return "Date of sales transaction" }
        "CustomerNo" { return "Customer identifier" }
        "Quantity" { return "Transaction quantity" }
        "Description" { return "Descriptive text" }
        "Branch" { return "Branch identifier or name" }
        "City" { return "Geographic city" }
        "State" { return "Geographic state" }
        "franchise" { return "Franchise or brand identifier" }
        default { return "Business data attribute" }
    }
}

Write-Host ""
Write-Host "Press Enter to close..."
Read-Host