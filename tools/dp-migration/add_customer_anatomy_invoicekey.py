"""Customer Anatomy model: add hidden InvoiceKey to the 3 service facts and relate on it.

Run only with Power BI Desktop CLOSED. Decision 7 (2026-09-28): service invoice numbers
are reused across years, so the model relates on InvoiceKey (Branch|InvoiceNumber).
"""
import re
import sys
import uuid
from pathlib import Path

SM = Path(r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Customer Anatomy.SemanticModel/definition")
TABLES = ["Fact_Service_Invoices", "Fact_Service_Detail", "Fact_Service_Parts_Details"]
RELS = {
    "fromColumn: Fact_Service_Detail.InvoiceNumber\n\ttoColumn: Fact_Service_Invoices.InvoiceNumber":
        "fromColumn: Fact_Service_Detail.InvoiceKey\n\ttoColumn: Fact_Service_Invoices.InvoiceKey",
    "fromColumn: Fact_Service_Parts_Details.InvoiceNumber\n\ttoColumn: Fact_Service_Invoices.InvoiceNumber":
        "fromColumn: Fact_Service_Parts_Details.InvoiceKey\n\ttoColumn: Fact_Service_Invoices.InvoiceKey",
}


def read(p):
    raw = p.read_bytes().decode("utf-8")
    return raw.replace("\r\n", "\n"), ("\r\n" if "\r\n" in raw else "\n")


def write(p, text, eol):
    p.write_bytes(text.replace("\n", eol).encode("utf-8"))


def main():
    updates = {}
    for t in TABLES:
        p = SM / "tables" / f"{t}.tmdl"
        text, eol = read(p)
        if re.search(r"^\tcolumn InvoiceKey$", text, re.M):
            sys.exit(f"{t}: InvoiceKey column already present - aborting")
        block = (f"\tcolumn InvoiceKey\n\t\tdataType: string\n\t\tisHidden\n\t\tlineageTag: {uuid.uuid4()}\n"
                 f"\t\tsummarizeBy: none\n\t\tsourceColumn: InvoiceKey\n\n\t\tannotation SummarizationSetBy = Automatic\n\n")
        assert text.count("\n\tpartition ") == 1, f"{t}: expected exactly one partition"
        text = text.replace("\n\tpartition ", "\n" + block + "\tpartition ", 1)
        if t == "Fact_Service_Invoices":
            old = 'Table.SelectColumns(dbo_Fact_Service_Invoices, {"InvoiceNumber",'
            assert text.count(old) == 1, "Service_Invoices SelectColumns not found"
            text = text.replace(old, 'Table.SelectColumns(dbo_Fact_Service_Invoices, {"InvoiceKey", "InvoiceNumber",')
        updates[p] = (text, eol)
    rp = SM / "relationships.tmdl"
    rtext, reol = read(rp)
    for old, new in RELS.items():
        assert rtext.count(old) == 1, f"relationship not found exactly once: {old.splitlines()[0]}"
        rtext = rtext.replace(old, new)
    updates[rp] = (rtext, reol)
    for p, (text, eol) in updates.items():
        write(p, text, eol)
        print("updated", p.name)
    print("done")


if __name__ == "__main__":
    main()
