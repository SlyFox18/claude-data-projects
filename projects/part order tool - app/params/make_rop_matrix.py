"""
Convert the corporate ROP matrix export ("Version 5 ROP-CSV.csv") to the clean CSV that
Build_Gold_NonJD_Reorder reads from DP_Presentation Files/config/nonjd/rop_matrix.csv.

- PascalCase headers (the original has spaces and "Spiking Warehouse<BR>Stocking Min").
- Thousands separators removed from numbers ("9,999,999" -> 9999999).
- Rows with a blank Month Count are dropped (1 row in Version 5; it can never match a part).

Run from anywhere:  python make_rop_matrix.py
"""
import csv
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "example excel sheet" / "Version 5 ROP-CSV.csv"
TARGET = HERE / "rop_matrix.csv"

HEADERS = {
    "Group": "StockingGroup", "Commodity Code": "CommodityCode", "SRC": "SRC", "SLC": "SLC",
    "Attachment": "Attachment", "Price L": "PriceL", "Price H": "PriceH", "Month Count": "MonthCount",
    "Demand L": "DemandL", "Demand H": "DemandH", "Sales L": "SalesL", "Sales H": "SalesH",
    "Modifier": "Modifier", "Trending Cap": "TrendingCap", "Warehouse Min": "WarehouseMin",
    "Stocking weeks": "StockingWeeks", "Spiking Modifier": "SpikingModifier",
    "Spiking Warehouse<BR>Stocking Min": "SpikingWarehouseStockingMin",
}
TEXT = {"StockingGroup", "CommodityCode", "SRC", "SLC", "Attachment"}


def main() -> None:
    with SOURCE.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    out = []
    for row in rows:
        clean = {HEADERS[k]: (v or "").strip() for k, v in row.items()}
        if not clean["MonthCount"]:
            continue
        for k, v in clean.items():
            if k not in TEXT:
                clean[k] = v.replace(",", "")
        out.append(clean)
    with TARGET.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(HEADERS.values()), lineterminator="\n")
        w.writeheader()
        w.writerows(out)
    print(f"Wrote {len(out)} rows to {TARGET}")


if __name__ == "__main__":
    main()
