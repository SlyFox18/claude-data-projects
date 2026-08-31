"""
PARTS AVAILABILITY APP - UPTIME CHECK
============================================================================
Checks that https://go-parts.spitractor.com is actually up and serving
the real app - not just "the server responds," but genuinely serving the
correct content, not a generic default page or a broken file. Added
2026-08-31, closing a real gap: the refresh pipeline has Teams alerting
and a staleness check (see run_refresh.py / check_staleness.py), but
nothing at all was watching whether the app's own hosting was actually
up. Without this, the first sign of an outage would always be a parts
department employee reporting the app doesn't work, not a proactive
alert.

Deliberately runs on the Gateway PC - a different machine than the one
being checked (Windows Server 2016, 10.30.100.60). A monitor running ON
the machine it's watching can't alert about that machine being down.

Checks two things, both targeting real failure modes already hit once
in this project (see WINDOWS-SERVER-2016-DEPLOYMENT.md):
1. The root page loads and contains real app content - not IIS's
   generic default page, which is exactly what happened the moment
   go-parts.spitractor.com's DNS record went live and the site had no
   HTTP binding yet.
2. manifest.webmanifest is reachable and returns valid JSON - IIS had
   no default MIME type for this extension, so the file could (and
   did) 404 even though it genuinely existed on disk. A plain root-page
   check alone would not have caught this specific failure mode.

TLS verification is deliberately disabled for these requests: the
certificate is self-signed and trusted via a GPO Wes deployed to every
domain computer's Windows certificate store, but Python's requests
library uses its own bundled CA list (via certifi), not the OS store -
it has no way to know this certificate is trusted even though every
real browser on this network does. This is a monitoring script making
a plain content check, not something handling sensitive data, so
skipping verification here is a reasonable, deliberate tradeoff, not
an oversight.

Only alerts on a state CHANGE (healthy -> unhealthy, or unhealthy ->
healthy), not on every single check - a real outage lasting hours
shouldn't produce a new Teams message every 15 minutes. Last-known
state is tracked in uptime_state.json between runs.
============================================================================
"""

import datetime
import json
import os

import requests
import urllib3

import run_refresh

APP_URL = "https://go-parts.spitractor.com"
MANIFEST_URL = f"{APP_URL}/manifest.webmanifest"
EXPECTED_MARKER = "Parts Availability"
STATE_PATH = "uptime_state.json"
TIMEOUT_SEC = (10, 15)  # (connect, read)
ALERT_TITLE = "Parts Availability App Uptime"

# See "TLS verification" note above - deliberate, not an oversight.
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def check_root_page() -> tuple[bool, str]:
    try:
        resp = requests.get(APP_URL, timeout=TIMEOUT_SEC, verify=False)
    except requests.exceptions.RequestException as exc:
        return False, f"root page unreachable: {exc}"
    if resp.status_code != 200:
        return False, f"root page returned HTTP {resp.status_code}"
    if EXPECTED_MARKER not in resp.text:
        return False, "root page loaded but doesn't contain expected app content - wrong page being served?"
    return True, "ok"


def check_manifest() -> tuple[bool, str]:
    try:
        resp = requests.get(MANIFEST_URL, timeout=TIMEOUT_SEC, verify=False)
    except requests.exceptions.RequestException as exc:
        return False, f"manifest unreachable: {exc}"
    if resp.status_code != 200:
        return False, f"manifest returned HTTP {resp.status_code}"
    try:
        resp.json()
    except ValueError:
        return False, "manifest didn't return valid JSON"
    return True, "ok"


def load_last_healthy() -> bool | None:
    """Returns None if this is the first run (no prior state to compare)."""
    if not os.path.exists(STATE_PATH):
        return None
    with open(STATE_PATH, encoding="utf-8") as f:
        return json.load(f).get("healthy")


def save_state(healthy: bool) -> None:
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(
            {
                "healthy": healthy,
                "checkedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            },
            f,
        )


def check() -> None:
    root_ok, root_reason = check_root_page()
    manifest_ok, manifest_reason = check_manifest()
    healthy = root_ok and manifest_ok
    reasons = "; ".join(r for ok, r in [(root_ok, root_reason), (manifest_ok, manifest_reason)] if not ok)

    last_healthy = load_last_healthy()

    if healthy and last_healthy is False:
        # Recovery - worth knowing about even though it's not a failure,
        # so this uses log_failure() (which alerts) rather than plain log().
        run_refresh.log_failure(f"UPTIME CHECK: {APP_URL} is back up (was down)", title=ALERT_TITLE)
    elif not healthy and last_healthy is not False:
        # New outage (last_healthy was True or None/first-run) - alert.
        run_refresh.log_failure(f"UPTIME CHECK: {APP_URL} appears DOWN - {reasons}", title=ALERT_TITLE)
    elif healthy:
        run_refresh.log("UPTIME CHECK: OK")
    else:
        # Still down, already alerted on this outage - log only, don't re-alert.
        run_refresh.log(f"UPTIME CHECK: still down - {reasons}")

    save_state(healthy)


if __name__ == "__main__":
    check()
