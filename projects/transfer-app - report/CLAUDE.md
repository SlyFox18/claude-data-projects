# Transfer App — Claude Context

## Report Overview
- **Business purpose:** Tracks inter-branch parts shipment/container delivery status in real-time — showing which containers are in transit, which have been delivered, driver assignments, and pickup/dropoff locations. Also includes a Driver Performance page. **Data source is SharePoint, not the Lakehouse.**
- **Primary users:** Parts coordinators, logistics staff, branch managers
- **Workspace:** RP - Parts Reports (confirm)
- **Refresh tier:** Tier 2 — Daily (confirm)
- **Status:** Production

## Semantic Model

### Primary Table
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Shipment Tracking` | One row per shipment/container record | ContainerID, DriverName, PickupLocation, DropoffLocation, PickupDate, DropoffDate, StatusCode, Status, RecordCreated, RecordID | **Source is a SharePoint list** — NOT the Lakehouse. Reads from `spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite`, list ID `a3c1e818-ec80-4bf2-8ae3-6c8a3e10fdc4`. Status: 1=In Transit, 2=Delivered. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse dimension | Presumably for pickup/dropoff location lookup |
| `dim_DateTable` | Shared Lakehouse dimension | Date filtering |
| `Data Refresh` | Calculated table | Refresh timestamp display |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Home | Active shipments — in-transit containers, current status | Visible |
| 4d469831776329c08a2e | Driver Performance | Driver-level performance metrics | Visible |

## Data Flow
```
SharePoint Online
  └─ spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite
       └─ Shipment Tracking list (containers, drivers, status, dates)
                │
                ▼ (direct SharePoint connector — not Lakehouse)
  Semantic Model import
                │
  dim_BranchLocation, dim_DateTable (shared dims from Lakehouse) ──┐
                                                                    ▼
                                                      Transfer App Report
```

## Known Issues & Gotchas

### SharePoint Data Source — Unique in This Repo
This is the **only report in the repo that reads from SharePoint** rather than the Lakehouse. The `Shipment Tracking` partition uses `SharePoint.Tables()` with the site URL and list GUID hardcoded. If the SharePoint site URL changes, the site is reorganized, or the list is moved, this connection will break.

### UTC Offset — Static -5h (No DST Handling)
The `Home - Header` measure uses `NOW() - TIME(5, 0, 0)` for CDT offset — a static 5-hour subtraction with no DST awareness. This will show times 1 hour off during CST (November–March) when Central Standard Time is UTC-6, not UTC-5. This is the same class of bug that was fixed in the Data Refresh table in February 2026 — but this measure was not updated at that time.

### `StatusCode` Values
Known status codes from the partition source:
- `1` = "In Transit"
- `2` = "Delivered"
- Other values → "Unknown"

If the SharePoint list adds new status codes, the `Status` column (computed in Power Query) will classify them as "Unknown" until the partition source is updated.

### SharePoint List GUID
The list is identified by GUID `a3c1e818-ec80-4bf2-8ae3-6c8a3e10fdc4`. If the list is deleted and recreated (even with the same name), the GUID changes and the connection breaks.

## Refresh Pipeline Position
- Refreshes independently of the Lakehouse pipeline — SharePoint connector queries live SharePoint data
- **No dependency on Phase 1-4 Lakehouse refreshes**
- Standard semantic model refresh schedule applies (Phase 5/6)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Transfer App.md`
