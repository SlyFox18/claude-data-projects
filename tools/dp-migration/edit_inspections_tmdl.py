"""Repoint Inspections to DP_Presentation, trim columns, restore IsRolling12Months.

Run only while the report is CLOSED in Power BI Desktop.
"""
import re
import sys
from pathlib import Path

SM = Path(r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Inspections.SemanticModel/definition")
OLD_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")'
NEW_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")'

KEEP = {
    "Fact_LaborJobSummary": ["JobCode", "JobType", "InvoiceNumber", "BranchCode", "WorkOrderNumber",
                             "InvoicedLaborAmount", "IsInspection", "ActualHoursWorked", "WorkOrderCreationDate"],
    "Fact_PendingInspections": ["BranchCode", "WorkOrderNumber", "JobCode", "CreationDate", "LastLaborPunch",
                                "DaysSinceCreation", "HoursWorked", "IsInspection"],
    "Fact_WorkOrderParts": ["TransactionDate", "PartNumber", "Quantity", "SaleValue", "Franchise", "BranchCode",
                            "Description", "CustomerNumber", "InvoiceNumber"],
    "ServiceRecommendations": ["InspectionJobCode", "JobCode", "JobType", "CompletedInspections", "TimesAdded", "TotalLabor"],
    "dim_BranchLocation": ["Branch", "BranchID", "BranchName", "LocationID"],
    "dim_CustomerList": ["CustomerNumber", "PrimaryName"],
    "dim_DateTable": ["DateKey", "Date", "MonthYear", "SortableMonthYear"],
    "dim_Parts": ["PartNumber", "Description", "Franchise", "SellPrice1"],
}
EXPECTED_REMOVED = {
    "Fact_LaborJobSummary": 22, "Fact_PendingInspections": 4, "Fact_WorkOrderParts": 5,
    "ServiceRecommendations": 0, "dim_BranchLocation": 12, "dim_CustomerList": 53,
    "dim_DateTable": 62, "dim_Parts": 18,
}
DIMS = {"dim_BranchLocation", "dim_CustomerList", "dim_DateTable", "dim_Parts"}

ROLLING = [
    "\tcolumn IsRolling12Months = ```",
    "",
    "\t\t\tVAR RefDate = MAX('Data Refresh'[Date])",
    "\t\t\tVAR StartOfRollingPeriod = EOMONTH(RefDate, -12) + 1",
    "\t\t\tVAR EndOfRollingPeriod = EOMONTH(RefDate, 0)",
    "\t\t\tRETURN",
    "\t\t\tdim_DateTable[Date] >= StartOfRollingPeriod && dim_DateTable[Date] <= EndOfRollingPeriod",
    "\t\t\t```",
    "\t\tdataType: boolean",
    '\t\tformatString: """TRUE"";""TRUE"";""FALSE"""',
    "\t\tlineageTag: a89fe68a-1123-4db4-bf32-6b8cb601951d",
    "\t\tsummarizeBy: none",
    "\t\tisDataTypeInferred",
    "",
    "\t\tannotation SummarizationSetBy = Automatic",
    "",
]

COL_RE = re.compile(r"^\tcolumn ('([^']+)'|(\S+))(\s*=.*)?$")
TOP_RE = re.compile(r"^\t[^\t]")


def rewrite_columns(lines, table):
    out, kept, removed = [], [], []
    i = 0
    while i < len(lines):
        m = COL_RE.match(lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        name, is_calc = m.group(2) or m.group(3), bool(m.group(4))
        j = i + 1
        while j < len(lines) and not TOP_RE.match(lines[j]):
            j += 1
        if table == "dim_DateTable" and name == "IsRolling12Months":
            out.extend(ROLLING)
            kept.append(name)
        elif is_calc or name in KEEP[table]:
            out.extend(lines[i:j])
            kept.append(name)
        else:
            while out and out[-1].startswith("\t///"):
                out.pop()
            removed.append(name)
        i = j
    return out, kept, removed


def main():
    ok = True
    for table, keep in KEEP.items():
        path = SM / "tables" / f"{table}.tmdl"
        raw = path.read_bytes().decode("utf-8")
        eol = "\r\n" if "\r\n" in raw else "\n"
        text = raw.replace("\r\n", "\n")

        n_src = text.count(OLD_SRC)
        assert n_src == (2 if table == "Fact_WorkOrderParts" else 1), f"{table}: {n_src} source strings"
        text = text.replace(OLD_SRC, NEW_SRC)

        if table in DIMS:
            old = (f'\t\t\t\t    dbo_{table} = Source{{[Schema="dbo",Item="{table}"]}}[Data]\n'
                   f'\t\t\t\tin\n\t\t\t\t    dbo_{table}')
            cols = ", ".join(f'"{c}"' for c in keep)
            new = (f'\t\t\t\t    dbo_{table} = Source{{[Schema="dbo",Item="{table}"]}}[Data],\n'
                   f'\t\t\t\t    #"Selected Columns" = Table.SelectColumns(dbo_{table}, {{{cols}}})\n'
                   f'\t\t\t\tin\n\t\t\t\t    #"Selected Columns"')
            assert text.count(old) == 1, f"{table}: partition tail not found exactly once"
            text = text.replace(old, new)

        lines, kept, removed = rewrite_columns(text.split("\n"), table)
        missing = [c for c in keep if c not in kept]
        print(f"{table}: removed {len(removed)} (expected {EXPECTED_REMOVED[table]}), missing keeps {missing}")
        if missing or len(removed) != EXPECTED_REMOVED[table]:
            ok = False
            print("   removed:", removed)
            continue
        path.write_bytes(eol.join(lines).encode("utf-8"))   # UTF-8, no BOM

    leftovers = [p.name for p in SM.rglob("*.tmdl") if "LH_Master_Data" in p.read_text(encoding="utf-8")]
    print("files still referencing LH_Master_Data:", leftovers)
    sys.exit(0 if ok and not leftovers else 1)


if __name__ == "__main__":
    main()
