let
  Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
  #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "WKROFILE", Kind = "Table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 2", {"BRANCH", "RO_NUMBER", "RO_STATUS", "ro_closed_ind", "ro_progress_status", "Pay_Method", "Creation_Date", "contact"}),
  #"Filtered rows 1" = Table.SelectRows(#"Choose columns", each [Creation_Date] > #datetime(2023, 12, 1, 0, 0, 0)),
  #"Expanded contact" = Table.ExpandRecordColumn(#"Filtered rows 1", "contact", {"contact_code", "surname", "name", "company_name"}, {"contact_code", "surname", "name", "company_name"})
in
  #"Expanded contact"