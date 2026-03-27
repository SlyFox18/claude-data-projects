let
  Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
  #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "jdis_Part_Information", Kind = "View"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 2", {"pi_Part_No", "pi_Commodity_Code"}),
  #"Filtered rows" = Table.SelectRows(#"Choose columns", each ([pi_Commodity_Code] = "310" or [pi_Commodity_Code] = "311" or [pi_Commodity_Code] = "312" or [pi_Commodity_Code] = "313" or [pi_Commodity_Code] = "314" or [pi_Commodity_Code] = "315" or [pi_Commodity_Code] = "316" or [pi_Commodity_Code] = "317" or [pi_Commodity_Code] = "318"))
in
  #"Filtered rows"