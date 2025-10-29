let
	SQL = "SELECT TOP 1 * FROM InHist_PmManage",
	Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
	Source