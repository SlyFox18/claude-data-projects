let
  Source = Odbc.Query("dsn=EquipRDB64", "SELECT#(lf)    DaysSinceLastLabor,#(lf)    StatusDisplay,#(lf)    Branch,#(lf)    RONumber,#(lf)    JobCode,#(lf)    JobType,#(lf)    InvoiceNumber,#(lf)    ROProgressStatus,#(lf)    CreationDate,#(lf)    JobStartDate,#(lf)    DaysSinceROFinishDate,#(lf)    DaysSinceCreationDate,#(lf)    LaborSale,#(lf)    SubletSale,#(lf)    PartSale,#(lf)    OtherSale,#(lf)    TotalSale,#(lf)  LastLaborPunch,#(lf)    QuotationIndicator,#(lf)    FirstLaborPunch#(lf)FROM#(lf)    RepairOrderDetail#(lf)WHERE#(lf)    StatusDisplay <> 'Invoiced'")
in
  Source