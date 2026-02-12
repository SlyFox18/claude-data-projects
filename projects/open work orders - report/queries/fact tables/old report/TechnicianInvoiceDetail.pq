let
  Source = Odbc.Query("dsn=EquipRDB64", "SELECT#(lf)    Branch,#(lf)    RepairOrderNumber,#(lf)    InvoiceNumber,#(lf)    TechnicianCode,#(lf)    HoursPunched,#(lf)    InvoiceHours,#(lf)    ReworkHours,#(lf)    GainLossHours,#(lf)    LaborCost,#(lf)    LaborSale,#(lf)    JobCode,#(lf)    JobType#(lf)FROM#(lf)    TechnicianInvoiceDetail")
in
  Source