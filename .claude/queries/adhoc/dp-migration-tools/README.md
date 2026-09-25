# DP migration tools

Helpers for DP-backend report migrations (Inspections, Customer Anatomy, ...).

- `run_item.py <wsId> <itemId> <RunNotebook|Refresh> [timeout]`: run a notebook or Dataflow Gen2 and wait; exit 0 only on Completed.
- `wait_ci.py [repoPath]`: wait for the GitHub Actions run of fabric-workspace-docs HEAD; exit 0 only on success.
- `folder_check.py`: registered notebooks' Fabric folder vs repo path; exit 1 on any mismatch.
- `inspections_parity.py`: Inspections DP-vs-production parity (added in the Inspections plan, Task 9).

All need `fab` (authenticated) and, for DuckDB scripts, `az login`.

Exit codes: `wait_ci.py` uses 2 = timeout; `run_item.py` uses 2 = timeout, 3 = already running, 4 = ambiguous (multiple new job instances).
