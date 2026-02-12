let
  Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
  #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "TechnicianEfficiency", Kind = "View"]}[Data]
in
  #"Navigation 2"