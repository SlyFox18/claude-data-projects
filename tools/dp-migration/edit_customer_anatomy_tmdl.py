"""Repoint Customer Anatomy to DP_Presentation and trim unused columns. Run only with Desktop CLOSED."""
import re
import sys
from pathlib import Path

SM = Path(r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Customer Anatomy.SemanticModel/definition")
OLD_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")'
NEW_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")'

KEEP = {
    "Fact_CustomerPerformance": ["CustomerKey", "TotalSales", "PartsSales", "TotalCost", "PeriodDateKey", "PartsCost", "PartsMargin",
                                 "ServiceSales", "ServiceCost", "ServiceMargin", "EquipmentSales", "EquipmentCost",
                                 "EquipmentMargin", "TotalMargin", "TotalTransactionCount", "Territory"],
    "Fact_Equipment_Sales": ["StockNumber", "CustomerKey", "SaleDateKey", "Territory", "SaleDate", "Year", "SalesValue",
                             "TotalBaseCost", "TotalTradeAllowance"],
    "Fact_Parts_Detail": ["CustomerKey", "TransDateKey", "TransDatetime", "Branch", "Franchise", "PartNumber", "Description",
                          "Qty", "SaleValue", "CostValue", "LineMargin", "IsSundryPart", "InvoiceNumber"],
    "Fact_Parts_Invoices": ["InvoiceNumber", "CustomerKey", "InvoiceDateKey", "Territory", "InvoiceDate", "Branch",
                            "PartsCostValue", "PartsSaleValue", "PartsMargin"],
    "Fact_Service_Detail": ["CustomerKey", "InvoiceDateKey", "InvoiceDate", "Branch", "JobCode", "JobType", "WorkCategory",
                            "IsFieldRepair", "ActLabor", "InvLabor", "LaborMargin", "ActParts", "InvParts", "PartsMargin",
                            "TotalInvoiced", "TotalJobMargin", "InvoiceNumber", "IsWarrantyJob"],
    "Fact_Service_Invoices": ["InvoiceNumber", "CustomerKey", "InvoiceDateKey", "Territory", "InvoiceDate", "Branch",
                              "LabourCostValue", "LabourSaleValue", "LabourMargin", "PartsCostValue", "PartsSaleValue",
                              "TotalNetSales", "TotalCost", "TotalMargin"],
    "Fact_Service_Parts_Details": ["BranchCode", "InvoiceNumber", "PartNumber", "Description", "Franchise", "Quantity", "SaleValue"],
    "dim_BranchLocation": ["Branch", "BranchID", "LocationID"],
    "dim_CustomerList": ["CustomerKey", "AccountNumber", "CustomerNumber", "DisplayName", "CompanyName", "TradeType",
                         "AccountStatus", "Territory", "CreditLimit", "AccountBalance", "CreditTerm", "City", "State",
                         "PrimaryPhone", "BusinessPhone", "MobilePhone", "Aging30", "Aging60", "Aging90", "IsKeyCustomer",
                         "CreditUtilization", "FinancialRiskLevel", "HasOverdueBalance", "CustomerTier"],
    "dim_DateTable": ["DateKey", "Date", "Year", "Month", "SortableMonthYear"],
    "dim_EngagedAcres": ["CustomerNumber", "EngagementLevel", "EstimatedAcres", "EngagedAcreBreadth", "EngagedAcreDepth",
                         "HighlyEngagedAcres", "PrepareAcres", "PlantAcres", "ApplyAcres", "HarvestAcres"],
    "dim_Parts": ["PartNumber", "Description", "Franchise"],
    "lookup_UniqueCustomers_Invoice": ["CustomerNumber", "UniqueCustomerGroup"],
}
EXPECTED_REMOVED = {"Fact_CustomerPerformance": 2, "Fact_Equipment_Sales": 27, "Fact_Parts_Detail": 10,
                    "Fact_Parts_Invoices": 24, "Fact_Service_Detail": 18, "Fact_Service_Invoices": 21,
                    "Fact_Service_Parts_Details": 6, "dim_BranchLocation": 13, "dim_CustomerList": 31,
                    "dim_DateTable": 62, "dim_EngagedAcres": 0, "dim_Parts": 19, "lookup_UniqueCustomers_Invoice": 0}
# Gold returns more columns than the model keeps for these, so their query selects explicitly.
SELECT_COLUMNS = {"dim_BranchLocation", "dim_CustomerList", "dim_DateTable", "dim_Parts",
                  "Fact_Parts_Invoices", "Fact_Service_Invoices", "Fact_Equipment_Sales"}

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
        if is_calc or name in KEEP[table]:
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
        assert text.count(OLD_SRC) == 1, f"{table}: expected exactly 1 source string"
        text = text.replace(OLD_SRC, NEW_SRC)
        if table in SELECT_COLUMNS:
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
        path.write_bytes(eol.join(lines).encode("utf-8"))
    leftovers = [p.name for p in SM.rglob("*.tmdl") if "LH_Master_Data" in p.read_text(encoding="utf-8")]
    print("files still referencing LH_Master_Data:", leftovers)
    sys.exit(0 if ok and not leftovers else 1)


if __name__ == "__main__":
    main()
