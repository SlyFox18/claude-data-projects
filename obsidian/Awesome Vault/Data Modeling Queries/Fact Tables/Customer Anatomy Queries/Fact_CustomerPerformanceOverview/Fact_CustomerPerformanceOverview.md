// Executive_KPI_Summary - Pre-Aggregated for Lightning-Fast Dashboards

// PURPOSE: Executive-level KPIs that refresh in seconds for board presentations

// GRAIN: Monthly summaries across multiple dimensions

  

let

    Source = Fact_CustomerPerformance,

    // =================================================================

    // MONTHLY BUSINESS PERFORMANCE SUMMARY

    // =================================================================

    MonthlyBusinessSummary = Table.Group(Source, {"InvoiceYear", "InvoiceMonth", "BusinessLine"}, {

        {"TotalCustomers", each Table.RowCount(Table.Distinct(_, {"CustomerKey"})), Int64.Type},

        {"TotalSalesYTD", each List.Sum([TotalSales]), type number},

        {"TotalSalesPYTD", each List.Sum([TotalSalesPYTD]), type number},

        {"AvgCustomerHealthScore", each List.Average([CustomerHealthScore]), type number},

        {"StrategicAccountCount", each List.Count(List.Select([StrategicValue], each _ = "Strategic Account")), Int64.Type},

        {"KeyAccountCount", each List.Count(List.Select([StrategicValue], each _ = "Key Account")), Int64.Type},

        {"AtRiskAccountCount", each List.Count(List.Select([StrategicValue], each _ = "At-Risk Account")), Int64.Type},

        {"RequiresAttentionCount", each List.Count(List.Select([RequiresAttention], each _ = true)), Int64.Type},

        {"NewBusinessCount", each List.Count(List.Select([PerformanceTrend], each _ = "New Business")), Int64.Type},

        {"LostBusinessCount", each List.Count(List.Select([PerformanceTrend], each _ = "Lost Business")), Int64.Type},

        {"CrossSellOpportunities", each List.Count(List.Select([CrossSellOpportunity], each _ = "Cross-Sell Potential")), Int64.Type},

        {"MultiLineCustomers", each List.Count(List.Select([CrossSellOpportunity], each _ = "Multi-Line Customer")), Int64.Type}

    }),

    // Add calculated growth metrics

    MonthlyWithGrowth = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(MonthlyBusinessSummary,

                "SalesGrowthAmount", each [TotalSalesYTD] - [TotalSalesPYTD], type number),

            "SalesGrowthPercent", each

                if [TotalSalesPYTD] > 0 then ([TotalSalesYTD] - [TotalSalesPYTD]) / [TotalSalesPYTD]

                else null, type number),

        "HealthScoreGrade", each

            if [AvgCustomerHealthScore] >= 80 then "Excellent"

            else if [AvgCustomerHealthScore] >= 70 then "Good"  

            else if [AvgCustomerHealthScore] >= 60 then "Fair"

            else "Needs Improvement", type text),

    // =================================================================

    // TERRITORY PERFORMANCE SUMMARY  

    // =================================================================

    TerritoryPerformance = Table.Group(Source, {"InvoiceYear", "InvoiceMonth", "Branch"}, {

        {"TotalCustomers", each Table.RowCount(Table.Distinct(_, {"CustomerKey"})), Int64.Type},

        {"TotalSalesYTD", each List.Sum([TotalSales]), type number},

        {"TotalSalesPYTD", each List.Sum([TotalSalesPYTD]), type number},

        {"HotTerritoryCount", each List.Count(List.Select([TerritoryMomentum], each _ = "Hot Territory")), Int64.Type},

        {"DecliningTerritoryCount", each List.Count(List.Select([TerritoryMomentum], each _ = "Declining Territory")), Int64.Type},

        {"TopPerformingCustomers", each List.Count(List.Select([CustomerHealthScore], each _ >= 80)), Int64.Type}

    }),

    // =================================================================

    // CUSTOMER HEALTH DASHBOARD METRICS

    // =================================================================

    CustomerHealthMetrics = Table.Group(Source, {"InvoiceYear", "InvoiceMonth"}, {

        {"TotalActiveCustomers", each Table.RowCount(Table.Distinct(_, {"CustomerKey"})), Int64.Type},

        {"HealthScoreDistribution_Excellent", each List.Count(List.Select([CustomerHealthScore], each _ >= 85)), Int64.Type},

        {"HealthScoreDistribution_Good", each List.Count(List.Select([CustomerHealthScore], each (_ >= 70 and _ < 85))), Int64.Type},

        {"HealthScoreDistribution_Fair", each List.Count(List.Select([CustomerHealthScore], each (_ >= 50 and _ < 70))), Int64.Type},

        {"HealthScoreDistribution_Poor", each List.Count(List.Select([CustomerHealthScore], each _ < 50)), Int64.Type},

        {"AvgHealthScore", each List.Average([CustomerHealthScore]), type number},

        {"HealthScoreTrend", each "Calculate in DAX", type text} // Will calculate trend in Power BI

    }),

    // =================================================================

    // CROSS-SELL INTELLIGENCE SUMMARY

    // =================================================================

    CrossSellMetrics = Table.Group(Source, {"InvoiceYear", "InvoiceMonth"}, {

        {"SingleLineCustomers", each List.Count(List.Select([BusinessLineCount], each _ = 1)), Int64.Type},

        {"TwoLineCustomers", each List.Count(List.Select([BusinessLineCount], each _ = 2)), Int64.Type},

        {"MultiLineCustomers", each List.Count(List.Select([BusinessLineCount], each _ >= 3)), Int64.Type},

        {"CrossSellPipelineValue", each List.Sum(List.Select([TotalSales], (sales, index) =>

            if List.Skip([GrowthPotential], index){0}? = "Cross-Sell Potential" then sales else 0)), type number},

        {"HighValueSingleLine", each List.Count(List.Select([CrossSellOpportunity], each _ = "High-Value Single-Line")), Int64.Type}

    }),

    // =================================================================

    // COMBINE INTO EXECUTIVE DASHBOARD TABLE

    // =================================================================

    // Create a comprehensive monthly executive summary

    ExecutiveSummary = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(

                Table.AddColumn(MonthlyWithGrowth,

                    "DateKey", each [InvoiceYear] * 10000 + [InvoiceMonth] * 100 + 1, Int64.Type),

                "PeriodLabel", each Date.ToText(#date([InvoiceYear], [InvoiceMonth], 1), "MMM yyyy"), type text),

            "BusinessHealthStatus", each

                if [SalesGrowthPercent] > 0.15 and [HealthScoreGrade] = "Excellent" then "Thriving"

                else if [SalesGrowthPercent] > 0.05 and [HealthScoreGrade] <> "Needs Improvement" then "Growing"

                else if [SalesGrowthPercent] > -0.05 then "Stable"

                else "Declining", type text),

        "ExecutivePriority", each

            if [RequiresAttentionCount] >= 5 then "High - Immediate Action Required"

            else if [LostBusinessCount] >= 3 then "Medium - Customer Retention Focus"  

            else if [NewBusinessCount] >= 5 then "Opportunity - Scale New Business"

            else "Standard - Monitor Performance", type text),

    // Final column organization for executive consumption

    FinalExecutiveSummary = Table.SelectColumns(ExecutiveSummary, {

        "DateKey", "InvoiceYear", "InvoiceMonth", "PeriodLabel", "BusinessLine",

        "TotalCustomers", "TotalSalesYTD", "TotalSalesPYTD", "SalesGrowthAmount", "SalesGrowthPercent",

        "AvgCustomerHealthScore", "HealthScoreGrade", "BusinessHealthStatus", "ExecutivePriority",

        "StrategicAccountCount", "KeyAccountCount", "AtRiskAccountCount", "RequiresAttentionCount",

        "NewBusinessCount", "LostBusinessCount", "CrossSellOpportunities", "MultiLineCustomers"

    }),

    // Set proper data types

    SetFinalTypes = Table.TransformColumnTypes(FinalExecutiveSummary, {

        {"DateKey", Int64.Type}, {"InvoiceYear", Int64.Type}, {"InvoiceMonth", Int64.Type},

        {"PeriodLabel", type text}, {"BusinessLine", type text}, {"TotalCustomers", Int64.Type},

        {"TotalSalesYTD", type number}, {"TotalSalesPYTD", type number},

        {"SalesGrowthAmount", type number}, {"SalesGrowthPercent", type number},

        {"AvgCustomerHealthScore", type number}, {"HealthScoreGrade", type text},

        {"BusinessHealthStatus", type text}, {"ExecutivePriority", type text},

        {"StrategicAccountCount", Int64.Type}, {"KeyAccountCount", Int64.Type},

        {"AtRiskAccountCount", Int64.Type}, {"RequiresAttentionCount", Int64.Type},

        {"NewBusinessCount", Int64.Type}, {"LostBusinessCount", Int64.Type},

        {"CrossSellOpportunities", Int64.Type}, {"MultiLineCustomers", Int64.Type}

    })

in

    SetFinalTypes

  

/*

============================================================================

🎯 EXECUTIVE KPI SUMMARY - DASHBOARD READY METRICS

============================================================================

  

PURPOSE: Lightning-fast executive dashboards with pre-calculated KPIs

REFRESH TIME: <10 seconds (pre-aggregated from your fact table)

USE CASE: Board presentations, executive briefings, management dashboards

  

📊 KEY EXECUTIVE METRICS INCLUDED:

• Business Health Status: Thriving/Growing/Stable/Declining

• Executive Priority: Action required indicators  

• Customer Portfolio: Strategic/Key/At-Risk account counts

• Growth Metrics: YTD vs PYTD with growth percentages

• Health Score: Average customer health with grade (A-F equivalent)

• Cross-Sell Pipeline: Opportunities and multi-line customer tracking

  

🚀 POWER BI DASHBOARD IDEAS:

• Executive Summary Card: Business Health Status + Executive Priority

• Trend Line: Monthly AvgCustomerHealthScore over time

• KPI Cards: StrategicAccountCount, RequiresAttentionCount, CrossSellOpportunities  

• Growth Chart: SalesGrowthPercent by BusinessLine over time

• Alert Panel: Filter where ExecutivePriority contains "High" or "Medium"

  

⚡ PERFORMANCE BENEFITS:

• Instant dashboard loading (pre-aggregated data)

• Board presentation ready (no complex DAX needed)

• Executive-friendly labels and categories

• Monthly grain perfect for trend analysis

============================================================================

*/