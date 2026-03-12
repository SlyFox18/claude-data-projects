let
    Source = SharePoint.Tables(
        "https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite",
        [Implementation = "2.0", ViewMode = "All"]
    ),
    List = Source{[Id = "a3c1e818-ec80-4bf2-8ae3-6c8a3e10fdc4"]}[Items],

    // Keep only the columns that matter
    Selected = Table.SelectColumns(List, {
        "ID",
        "Title",
        "pd_drivername",
        "PickupLocation",
        "pd_deliveryrecord",
        "Pickup Date",
        "Dropoff Date",
        "statuscode",
        "Created"
    }),

    // Rename to clear, meaningful names
    Renamed = Table.RenameColumns(Selected, {
        {"ID",               "RecordID"},
        {"Title",            "ContainerID"},
        {"pd_drivername",    "DriverName"},
        {"PickupLocation",   "PickupLocation"},
        {"pd_deliveryrecord","DropoffLocation"},
        {"Pickup Date",      "PickupDate"},
        {"Dropoff Date",     "DropoffDate"},
        {"statuscode",       "StatusCode"},
        {"Created",          "RecordCreated"}
    }),

    // Add a readable status label
    AddStatusLabel = Table.AddColumn(Renamed, "Status", each
        if [StatusCode] = 1 then "In Transit"
        else if [StatusCode] = 2 then "Delivered"
        else "Unknown",
        type text
    ),

    // Set correct data types
    SetTypes = Table.TransformColumnTypes(AddStatusLabel, {
        {"RecordID",       Int64.Type},
        {"ContainerID",    type text},
        {"DriverName",     type text},
        {"PickupLocation", type text},
        {"DropoffLocation",type text},
        {"PickupDate",     type datetimezone},
        {"DropoffDate",    type datetimezone},
        {"StatusCode",     Int64.Type},
        {"Status",         type text},
        {"RecordCreated",  type datetimezone}
    }),

    // Convert UTC to Central time (DST-aware) — same fix as Data Refresh table
    ConvertToCentral = Table.TransformColumns(SetTypes, {
        {"PickupDate",    each DateTimeZone.SwitchZone(_, -6), type datetimezone},
        {"DropoffDate",   each if _ = null then null else DateTimeZone.SwitchZone(_, -6), type datetimezone},
        {"RecordCreated", each DateTimeZone.SwitchZone(_, -6), type datetimezone}
    })

in
    ConvertToCentral
