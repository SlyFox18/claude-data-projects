"""
PARTS LOOKUP REFRESH PIPELINE - STALENESS CHECK
============================================================================
Complements run_refresh.py's failure alerting (added 2026-08-26), which
only fires when a run actively errors. That leaves a real blind spot: if
the "Parts Lookup Refresh" scheduled task itself gets disabled, the
machine loses power, or someone forgets to re-enable it after
maintenance, nothing *fails* - the pipeline just quietly stops running,
"Data as of" drifts further behind every hour, and nobody is told
anything, because "no run happened" isn't an event the failure-path
alerting can react to.

This script closes that gap: it reads output/2char/_meta.json's
generatedAt timestamp (written by run_refresh.py's write_meta_file(),
right before each upload) and alerts via the same Teams
webhook if it's older than STALE_THRESHOLD_MINUTES.

Runs on its own Task Scheduler task at :45 past each hour, 07:45-17:45 Mon-Fri (the refresh runs
07:00-17:00, the loads 06:50-16:50). Since 2026-10 generatedAt is the data's load time
(ExtractedAtUtc), so this also catches a failed or missing upstream load, not just a stopped task.
Staleness overnight and on weekends is expected, so the schedule (not this script) keeps it to
working hours.

Logs to the same refresh.log Brian already watches via VS Code Remote
Tunnels, so a staleness alert shows up in the same place as everything
else about this pipeline.
============================================================================
"""

import datetime
import json
import os

import run_refresh

META_PATH = os.path.join("output", "2char", "_meta.json")
STALE_THRESHOLD_MINUTES = 90


def check() -> None:
    if not os.path.exists(META_PATH):
        run_refresh.log_failure(
            f"STALE CHECK: {META_PATH} does not exist - the pipeline may "
            "have never run successfully on this machine, or output/ was cleared."
        )
        return

    with open(META_PATH, encoding="utf-8") as f:
        generated_at = datetime.datetime.fromisoformat(json.load(f)["generatedAt"])

    age = datetime.datetime.now(datetime.timezone.utc) - generated_at
    age_minutes = age.total_seconds() / 60

    if age_minutes > STALE_THRESHOLD_MINUTES:
        run_refresh.log_failure(
            f"STALE CHECK: data is {age_minutes:.0f} min old (threshold "
            f"{STALE_THRESHOLD_MINUTES} min) - newest published data is from "
            f"{generated_at.isoformat()}. Check Pipeline_PartsAvailability (DP - Presentation - Prod; "
            "it emails on a failed load) and the 'Parts Lookup Refresh' task on this PC."
        )
    else:
        run_refresh.log(f"STALE CHECK: OK - data is {age_minutes:.0f} min old")


if __name__ == "__main__":
    check()
