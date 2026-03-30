# Transfer App — Project Summary

## Overview
Tracks inter-branch parts shipment and container delivery status in near-real-time. Shows which containers are in transit, which have been delivered, driver assignments, pickup and dropoff locations, and driver performance metrics. Unlike all other reports in this repo, this report reads from SharePoint rather than the Lakehouse.

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2)

## Report Pages

| Page | Purpose |
|------|---------|
| Home | Active shipments — in-transit and recently delivered containers with current status |
| Driver Performance | Driver-level delivery metrics |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Shipment Tracking` | Main | SharePoint list (SouthPlainsImplement-ReportSite) | One row per container/shipment — driver, pickup/dropoff locations, dates, status code |
| `dim_BranchLocation` | Shared Dimension | Lakehouse | Branch reference |
| `dim_DateTable` | Shared Dimension | Lakehouse | Date dimension |

### Key Columns (from `Shipment Tracking`)
| Column | Description |
|--------|-------------|
| ContainerID | Container/shipment identifier |
| DriverName | Assigned driver |
| PickupLocation | Origin branch/location |
| DropoffLocation | Destination branch/location |
| PickupDate | Date container was picked up |
| DropoffDate | Date container was delivered |
| Status | "In Transit", "Delivered", or "Unknown" |
| StatusCode | 1=In Transit, 2=Delivered |

## Source
| Source | Description |
|--------|-------------|
| SharePoint (SouthPlainsImplement-ReportSite) | Shipment Tracking list — manually updated by logistics/parts staff |

## Notes
- **SharePoint source:** This is the only report in the repo that reads from SharePoint. The connection uses a hardcoded list GUID — if the SharePoint list is recreated, the GUID changes and the connection breaks.
- **UTC offset:** The header time greeting uses a static -5h CDT offset with no DST handling. Times will show 1 hour off during Central Standard Time (November–March).
- **Live data:** Because SharePoint is queried directly at import time, this report reflects the most recently updated SharePoint list entries at the time of the last semantic model refresh.
