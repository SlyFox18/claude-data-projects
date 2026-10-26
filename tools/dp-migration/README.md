# DP migration tools

Helpers for DP-backend report migrations (Inspections, Customer Anatomy, ...).

- `dp_refresh_status.py [prod|dev] [--runs N]`: read-only; recent Pipeline_DP_Refresh runs plus the latest run's summary (the Finish notebook's exit value, same as the email): failed/skipped items, warnings, Bronze problems. Exit 0 ok, 1 problems, 2 in progress/no summary. Used by `/check-refresh`.
- `run_item.py <wsId> <itemId> <RunNotebook|Refresh> [timeout]`: run a notebook or Dataflow Gen2 and wait; exit 0 only on Completed.
- `wait_ci.py [repoPath]`: wait for the GitHub Actions run of fabric-workspace-docs HEAD; exit 0 only on success.
- `git_sync.py <wsId> [timeout]`: Fabric updateFromGit for a Git-connected workspace (how notebook code reaches Dev); refuses if any item changed on both sides; exit 0 synced/current.
- `folder_check.py`: registered notebooks' Fabric folder vs repo path; exit 1 on any mismatch.
- `inspections_parity.py`: Inspections DP-vs-production parity (added in the Inspections plan, Task 9).
- `git_status.py [wsId ...]`: Fabric Git status (defaults: DP Presentation/Staging Dev + RP - Dev).
- `refresh_model.py <wsId> <datasetId>`: service refresh of a semantic model; exit 0 only on Completed.
- `dax_query.py <wsId> <datasetId> <file.dax>`: run a DAX query against a published model.
- `customer_anatomy_parity.py`: Customer Anatomy DP-vs-production parity (Customer Anatomy plan, Task 8).
- `edit_customer_anatomy_tmdl.py`: Customer Anatomy repoint/trim script (Customer Anatomy plan, Task 9).
- `parts_availability_check.py <dev|prod> [YYYY-MM-DD]`: read-only; pairs each LH `InMaster_PartsLookup_Raw` load with DP's `PartsAvailability` load from the same minute and compares them on the raw key (Parts Availability plan, Task 2). Exit 0 pass, 1 fail, 2 no pairs.

All need `fab` (authenticated) and, for DuckDB scripts, `az login`.

Exit codes: `wait_ci.py` uses 2 = timeout; `run_item.py` uses 2 = timeout, 3 = already running, 4 = ambiguous (multiple new job instances).
