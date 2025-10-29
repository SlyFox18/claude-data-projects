/*
============================================================================
FACT_WORKORDERMASTER - SIMPLE WORKING VERSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Essential work order master data for cross-fact integration
Grain: One row per work order with core context
Performance: Based on proven 8-second preview foundation
Source Dependencies: Raw_wkrofile + Raw_wkrodesc

============================================================================
*/

let
    // ========================================================================
    // PROVEN FOUNDATION - KEEP IT SIMPLE
    // ========================================================================
    
    Source = Raw_wkrofile,
    
    // Essential date key
    AddDateKey = Table.AddColumn(Source, "CreationDateKey", each
        if [CreatedOn] <> null then
            Date.Year([CreatedOn]) * 10000 + Date.Month([CreatedOn]) * 100 + Date.Day([CreatedOn])
        else -1, Int64.Type),
    
    // Add job code context (proven to work)
    JobCodeJoin = Table.NestedJoin(
        AddDateKey, {"Branch", "WorkOrder"}, 
        Raw_wkrodesc, {"Branch", "WorkOrder"}, 
        "JobData", JoinKind.LeftOuter),
    
    ExpandJobCode = Table.ExpandTableColumn(
        JobCodeJoin, "JobData", 
        {"JobCode", "JobType", "JobValue"}, 
        {"JobCode", "JobType", "JobValue"}),
    
    // Essential work order key
    AddWorkOrderKey = Table.AddColumn(ExpandJobCode, "WorkOrderKey", each
        [Branch] & "-" & Text.From([WorkOrder] ?? 0), type text),
    
    // Essential dimension lookups only
    BranchLookup = Table.NestedJoin(
        AddWorkOrderKey, {"Branch"}, 
        dim_BranchLocation, {"BranchID"}, 
        "BranchDim", JoinKind.LeftOuter),
    
    WorkOrderLookup = Table.NestedJoin(
        BranchLookup, {"Branch", "WorkOrder"}, 
        dim_WorkOrderMaster, {"Branch", "WorkOrder"}, 
        "WODim", JoinKind.LeftOuter),
    
    ExpandDimensions = Table.ExpandTableColumn(
        Table.ExpandTableColumn(WorkOrderLookup,
            "BranchDim", {"BranchKey"}, {"BranchKey"}),
        "WODim", {"BranchWorkOrder"}, {"DimWorkOrderKey"}),
    
    // Clean dimension keys
    CleanKeys = Table.AddColumn(
        Table.AddColumn(ExpandDimensions,
            "CleanBranchKey", each [BranchKey] ?? -1, Int64.Type),
        "CleanWorkOrderKey", each [DimWorkOrderKey] ?? "UNKNOWN", type text),
    
    // Essential columns only
    EssentialColumns = Table.SelectColumns(CleanKeys, {
        "CleanBranchKey", "CleanWorkOrderKey", "CreationDateKey",
        "Branch", "WorkOrder", "Registration", "AccountNumber", "ROStatus",
        "JobCode", "JobType", "JobValue", "Franchise", "AccountClass", 
        "CreatedOn", "ClosedDate", "WorkOrderKey", "ModifiedDate"
    }),
    
    // Final data types
    FinalDataTypes = Table.TransformColumnTypes(EssentialColumns, {
        {"CleanBranchKey", Int64.Type}, {"CleanWorkOrderKey", type text}, {"CreationDateKey", Int64.Type},
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"Registration", type text}, 
        {"AccountNumber", type text}, {"ROStatus", type text}, {"JobCode", type text}, {"JobType", type text},
        {"JobValue", type number}, {"Franchise", type text}, {"AccountClass", type text},
        {"CreatedOn", type datetime}, {"ClosedDate", type datetime}, {"WorkOrderKey", type text},
        {"ModifiedDate", type datetime}
    })

in
    FinalDataTypes

/*
============================================================================
✅ SIMPLE WORKING VERSION - ESSENTIAL WORK ORDER CONTEXT
============================================================================

🔧 DESIGN PRINCIPLES:
• Keep It Simple: Based on proven 8-second preview foundation
• Essential Data Only: Core work order context without complex business logic
• Cross-Fact Integration: Text work order keys for fact table relationships
• Reliable Performance: No complex calculations that cause column reference errors

📊 WHAT IT PROVIDES:
• Work Order Master Data: Essential context from Raw_wkrofile
• Job Classification: JobCode, JobType, JobValue from Raw_wkrodesc  
• Cross-Fact Keys: WorkOrderKey and DimWorkOrderKey for integration
• Dimension Relationships: Branch and work order master lookups
• Timeline Context: Creation and completion dates

🚀 BUSINESS VALUE:
• Central work order context for cross-fact analysis
• Geographic analysis through branch dimension
• Service type context through job code data
• Customer and equipment context for analysis
• Foundation for detailed analytics in specialized fact tables

============================================================================
*/