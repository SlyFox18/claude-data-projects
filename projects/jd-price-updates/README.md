# JD Price Updates

Ingests John Deere `PRICEUPDATE_*.TXT` branch price-change files from a
network folder into `LH_Master_Data.Raw_PriceUpdate_History`.

**Design spec:** `docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md`
**Implementation plan:** `docs/superpowers/plans/2026-08-06-jd-price-update-ingestion.md`

Full operational details (real paths, schedule, Fabric object names) are
filled in below once the pipeline is actually built — see the
implementation plan's later tasks.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/Inventory-PriceUpdateFolder.ps1` | One-off: counts files, finds oldest/newest date, total size in the source folder. Used to size the historical backfill. |
| `scripts/Compare-PriceUpdateSchema.ps1` | One-off: compares the header row of two or more files to check for column drift across years. |
| `scripts/Harvest-PriceUpdateFiles.ps1` | Daily scheduled: copies new files into the OneLake landing area. |
| `scripts/Register-HarvestPriceUpdateTask.ps1` | One-off setup: registers the daily Windows Scheduled Task for the harvest script. |

_(Setup instructions, real paths, and Fabric object names to be added once built — see implementation plan Tasks 6–12.)_
