let
  Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
  #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "TechnicianPunchedTime", Kind = "View"]}[Data],
  #"Filtered rows" = Table.SelectRows(#"Navigation 2", each ([Year] = 2023 or [Year] = 2024 or [Year] = 2025 or [Year] = 2026))
in
  #"Filtered rows"