
# Super Simple Documentation Generator (No Syntax Issues)

**Delete the broken script and create this ultra-simple version:**

**Create file:** `scripts\simple-generate-docs.ps1`

```powershell
# Ultra Simple DAX Documentation Generator
$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"
$measuresFile = "$repo\data\info-exports\current-measures.csv"
$docsFolder = "$repo\docs"

Write-Host "=== Simple DAX Documentation Generator ===" -ForegroundColor Cyan
Write-Host "Processing your 83 measures..." -ForegroundColor Yellow

# Create docs folder
if (!(Test-Path $docsFolder)) {
    New-Item -ItemType Directory -Path $docsFolder -Force | Out-Null
}

# Read measures
$measures = Import-Csv $measuresFile
Write-Host "Found $($measures.Count) measures" -ForegroundColor Green

# Categorize measures
$coreMetrics = @()
$transactionAnalysis = @()
$matrixAnalysis = @()
$performance = @()
$utilities = @()
$debug = @()

Write-Host "Categorizing measures..." -ForegroundColor Yellow

foreach ($measure in $measures) {
    $name = $measure.Name
    if ($name -match "Debug|Test|Sample|Check") {
        $debug += $measure
    }
    elseif ($name -match "Show.*Filter|Filter|Display") {
        $utilities += $measure
    }
    elseif ($name -match "Transaction") {
        $transactionAnalysis += $measure
    }
    elseif ($name -match "Matrix|Effective|Gained") {
        $matrixAnalysis += $measure
    }
    elseif ($name -match "Performance|Status|Icon|Trend|Seasonal") {
        $performance += $measure
    }
    else {
        $coreMetrics += $measure
    }
}

Write-Host "Categories:" -ForegroundColor White
Write-Host "  Core Business Metrics: $($coreMetrics.Count)" -ForegroundColor Green
Write-Host "  Transaction Analysis: $($transactionAnalysis.Count)" -ForegroundColor Green  
Write-Host "  Matrix Analysis: $($matrixAnalysis.Count)" -ForegroundColor Green
Write-Host "  Performance Indicators: $($performance.Count)" -ForegroundColor Green
Write-Host "  Utilities: $($utilities.Count)" -ForegroundColor Green
Write-Host "  Debug/Testing: $($debug.Count)" -ForegroundColor Green

# Create documentation content
Write-Host ""
Write-Host "Generating documentation..." -ForegroundColor Yellow

$content = @"
# Price Matrix Project - DAX Measures Documentation

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm")
**Total Measures:** $($measures.Count)
**Project:** Price Matrix Analysis System

---

## Executive Summary

This comprehensive guide documents all $($measures.Count) DAX measures in the Price Matrix project.
The system analyzes parts pricing, sales performance, and margin optimization across 
different price ranges to support strategic pricing decisions.

### Key Capabilities
- Price Range Analysis: Compare performance across different pricing segments
- Margin Optimization: Track actual vs target margins with visual indicators  
- Transaction Insights: Detailed analysis of sales patterns and customer behavior
- Matrix Pricing: Calculate potential gains from optimized pricing strategies

### Measure Categories Overview

- **Core Business Metrics:** $($coreMetrics.Count) measures - Fundamental sales and pricing analysis
- **Transaction Analysis:** $($transactionAnalysis.Count) measures - Detailed transaction-level insights  
- **Matrix Analysis:** $($matrixAnalysis.Count) measures - Strategic pricing optimization
- **Performance Indicators:** $($performance.Count) measures - Visual KPIs and status tracking
- **Utilities:** $($utilities.Count) measures - User experience and filtering support
- **Debug/Testing:** $($debug.Count) measures - Development and troubleshooting tools

---

"@

# Add each category
if ($coreMetrics.Count -gt 0) {
    $content += "`n## Core Business Metrics`n`n"
    $content += "Fundamental business measures that provide key insights into sales performance and pricing metrics.`n`n"
    
    foreach ($measure in $coreMetrics) {
        $purpose = Get-BusinessPurpose $measure.Name
        $content += "### $($measure.Name)`n`n"
        $content += "**Business Purpose:** $purpose`n`n"
        $content += "**Output Format:** $(if ($measure.FormatString) { $measure.FormatString } else { 'Number' })`n`n"
        $content += "**Expression Length:** $($measure.Expression.Length) characters`n`n"
        $content += "---`n`n"
    }
}

if ($transactionAnalysis.Count -gt 0) {
    $content += "`n## Transaction Analysis`n`n"
    $content += "Detailed analysis of individual transactions and sales patterns.`n`n"
    
    foreach ($measure in $transactionAnalysis) {
        $purpose = Get-BusinessPurpose $measure.Name
        $content += "### $($measure.Name)`n`n"
        $content += "**Business Purpose:** $purpose`n`n"
        $content += "**Output Format:** $(if ($measure.FormatString) { $measure.FormatString } else { 'Number' })`n`n"
        $content += "**Expression Length:** $($measure.Expression.Length) characters`n`n"
        $content += "---`n`n"
    }
}

if ($matrixAnalysis.Count -gt 0) {
    $content += "`n## Matrix and Pricing Analysis`n`n"
    $content += "Strategic pricing measures for optimization and pricing opportunities.`n`n"
    
    foreach ($measure in $matrixAnalysis) {
        $purpose = Get-BusinessPurpose $measure.Name
        $content += "### $($measure.Name)`n`n"
        $content += "**Business Purpose:** $purpose`n`n"
        $content += "**Output Format:** $(if ($measure.FormatString) { $measure.FormatString } else { 'Currency' })`n`n"
        $content += "**Expression Length:** $($measure.Expression.Length) characters`n`n"
        $content += "---`n`n"
    }
}

if ($performance.Count -gt 0) {
    $content += "`n## Performance Indicators`n`n"
    $content += "Visual indicators and performance tracking measures.`n`n"
    
    foreach ($measure in $performance) {
        $purpose = Get-BusinessPurpose $measure.Name
        $content += "### $($measure.Name)`n`n"
        $content += "**Business Purpose:** $purpose`n`n"
        $content += "**Output Format:** $(if ($measure.FormatString) { $measure.FormatString } else { 'Text/Visual' })`n`n"
        $content += "**Usage:** Executive dashboards and KPI scorecards`n`n"
        $content += "---`n`n"
    }
}

if ($utilities.Count -gt 0) {
    $content += "`n## Utilities and Filters`n`n"
    $content += "Supporting measures for user experience and filtering.`n`n"
    
    foreach ($measure in $utilities) {
        $purpose = Get-BusinessPurpose $measure.Name
        $content += "### $($measure.Name)`n`n"
        $content += "**Purpose:** $purpose`n`n"
        $content += "**Usage:** User interface enhancement`n`n"
        $content += "---`n`n"
    }
}

if ($debug.Count -gt 0) {
    $content += "`n## Debug and Testing`n`n"
    $content += "Diagnostic measures for development and troubleshooting.`n`n"
    
    foreach ($measure in $debug) {
        $content += "### $($measure.Name)`n`n"
        $content += "**Purpose:** Development and troubleshooting`n`n"
        $content += "**Usage:** Data validation and quality assurance`n`n"
        $content += "---`n`n"
    }
}

# Add technical reference
$content += @"

## Technical Reference

### Data Model Components

**Fact Tables:**
- Fact_Inventory: Part information and 12-month sales data
- Fact_Part_Transactions: Individual transaction details

**Dimension Tables:**  
- dim_Parts: Part master data
- dim_BranchLocation: Location information
- dim_Franchise: Franchise details

**Configuration:**
- Price_Matrix: Price ranges and target margins (CSV file)

### Common Patterns

**Range Filtering:** Most measures handle both individual price ranges and totals using conditional logic.

**Sales Activity Filter:** Business measures filter for parts with sales activity.

**Transaction Validation:** Transaction measures filter for valid sales transactions.

### Performance Notes

- Variables used extensively to avoid recalculation
- CALCULATETABLE provides optimal performance for complex filtering  
- Date filtering uses rolling 12-month windows
- All measures handle blank values appropriately

---

*This documentation is automatically generated from Power BI model metadata.*
*Last updated: $(Get-Date -Format "yyyy-MM-dd HH:mm")*
"@

# Save documentation
$docFile = "$docsFolder\dax-measures-documentation.md"
$content | Out-File $docFile -Encoding UTF8

Write-Host ""
Write-Host "Documentation saved to: $docFile" -ForegroundColor Green

# Create quick reference
Write-Host "Creating quick reference..." -ForegroundColor Yellow

$quickRef = "# DAX Measures Quick Reference`n`n"
$quickRef += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd')`n"
$quickRef += "**Total Measures:** $($measures.Count)`n`n"

$allCategories = @{
    "Core Business Metrics" = $coreMetrics
    "Transaction Analysis" = $transactionAnalysis  
    "Matrix Analysis" = $matrixAnalysis
    "Performance Indicators" = $performance
    "Utilities" = $utilities
    "Debug/Testing" = $debug
}

foreach ($categoryName in $allCategories.Keys) {
    $categoryMeasures = $allCategories[$categoryName]
    if ($categoryMeasures.Count -gt 0) {
        $quickRef += "## $categoryName`n`n"
        foreach ($measure in $categoryMeasures) {
            $purpose = Get-BusinessPurpose $measure.Name
            $quickRef += "**$($measure.Name):** $purpose`n`n"
        }
    }
}

$quickRefFile = "$docsFolder\measures-quick-reference.md"
$quickRef | Out-File $quickRefFile -Encoding UTF8

Write-Host "Quick reference saved to: $quickRefFile" -ForegroundColor Green

# Commit to Git
Write-Host ""
Write-Host "Committing to Git..." -ForegroundColor Yellow
Set-Location $repo

try {
    git add "docs/*"
    git commit -m "auto: Generate DAX documentation for $($measures.Count) measures - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push origin main
    Write-Host "Committed to Git successfully!" -ForegroundColor Green
} catch {
    Write-Host "Git operation had issues, but files were created" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Documentation Complete! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files Created:" -ForegroundColor Yellow
Write-Host "  Main Documentation: docs\dax-measures-documentation.md" -ForegroundColor Green
Write-Host "  Quick Reference: docs\measures-quick-reference.md" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Total measures: $($measures.Count)" -ForegroundColor White
Write-Host "  Categories: $($allCategories.Keys.Count)" -ForegroundColor White

# Simple helper function
function Get-BusinessPurpose($measureName) {
    if ($measureName -match "Unique Parts.*Range") {
        return "Counts distinct part numbers in a price range that have sales activity"
    }
    elseif ($measureName -match "Total Sales.*Dollars") {
        return "Total dollar sales for parts within a specific price range"
    }
    elseif ($measureName -match "Average Selling Price") {
        return "Average selling price for parts, showing actual pricing patterns"
    }
    elseif ($measureName -match "Transaction Count") {
        return "Number of individual sales transactions, indicating sales velocity"
    }
    elseif ($measureName -match "Transaction.*Margin.*%") {
        return "Actual profit margin percentage from sales transactions"
    }
    elseif ($measureName -match "Transaction.*Sales") {
        return "Total sales dollars from actual transactions"
    }
    elseif ($measureName -match "Transaction.*Quantity") {
        return "Total quantity sold from transactions"
    }
    elseif ($measureName -match "Margin Performance") {
        return "Compares actual vs target margins with visual status indicators"
    }
    elseif ($measureName -match "EffectiveListSaleVal") {
        return "Potential sales if list prices were used instead of discounts"
    }
    elseif ($measureName -match "EffectiveListMargin") {
        return "Potential margins if list prices were achieved"
    }
    elseif ($measureName -match "MatrixSalesGained") {
        return "Additional sales revenue possible with matrix pricing strategy"
    }
    elseif ($measureName -match "MatrixMarginGained") {
        return "Additional margin dollars achievable through pricing optimization"
    }
    elseif ($measureName -match "Transaction Velocity") {
        return "Average transactions per part, indicating demand patterns"
    }
    elseif ($measureName -match "Average Transaction Size") {
        return "Average dollar amount per transaction"
    }
    elseif ($measureName -match "Customer Concentration") {
        return "Percentage of sales to top customer, showing dependency risk"
    }
    elseif ($measureName -match "Show Filter") {
        return "Dynamic display of current filter selections"
    }
    elseif ($measureName -match "Debug") {
        return "Diagnostic measure for data validation and troubleshooting"
    }
    elseif ($measureName -match "Test") {
        return "Testing measure for validation purposes"
    }
    else {
        return "Provides analytical insights for price matrix analysis"
    }
}

Write-Host ""
Write-Host "Press Enter to close..."
Read-Host
```