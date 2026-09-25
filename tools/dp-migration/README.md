# DP migration tools

Helpers for DP-backend report migrations (Inspections, Customer Anatomy, ...).

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

All need `fab` (authenticated) and, for DuckDB scripts, `az login`.

Exit codes: `wait_ci.py` uses 2 = timeout; `run_item.py` uses 2 = timeout, 3 = already running, 4 = ambiguous (multiple new job instances).
