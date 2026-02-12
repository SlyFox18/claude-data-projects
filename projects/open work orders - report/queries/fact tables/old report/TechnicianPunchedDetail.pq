let
  Source = Odbc.Query("dsn=EquipRDB64", "SELECT#(lf)    Branch,#(lf)    RepairOrderNumber,#(lf)    TechnicianCode,#(lf)    Model,#(lf)    CustomerName,#(lf)    WorkDate,#(lf)    HoursWorked,#(lf)    HoursSold,#(lf)    HoursInternal,#(lf)    HoursWarranty,#(lf)    HoursRetail,#(lf)    HoursSundry,#(lf)    HoursOther,#(lf)    JobCode,#(lf)    JobType,#(lf)    ROBranch,#(lf)    CreationDate#(lf)FROM#(lf)    TechnicianPunchedDetail")
in
  Source