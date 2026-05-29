/*
============================================================================
Query: param_FranchiseScope
Dataflow: df_Param_FranchiseScope
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

PURPOSE: Franchise include/exclude list for the Non-JD Parts Order Tool.
Defines which franchises are in scope for ordering recommendations.

GRAIN: One row per Franchise code (40 rows)

SOURCE: CSV file in LH_Master_Data → Files → param_FranchiseScope.csv
        Excluded: D (JD PRISM), ZP (warehouse), S (inactive), TD/TM (T* pattern),
                  UD/UM (U* pattern), 95 (data error)
        DA franchise is INCLUDED — confirmed not a JD franchise.

REFRESH: Manual only — admin-managed, only when franchise scope changes

LAKEHOUSE IDs:
  Workspace: b48cdb35-7ce3-46de-96df-d70db77649cb
  Lakehouse: 3e74497b-8c51-4a1a-91a1-888c59118f48
============================================================================
*/

let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 4" = #"Navigation 3"{[Name = "param_FranchiseScope.csv"]}[Content],
  #"Imported CSV" = Csv.Document(#"Navigation 4", [Delimiter = ",", Columns = 3, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"Franchise", type text}, {"IsIncluded", type logical}, {"ExclusionReason", type text}})
in
  #"Changed column type"