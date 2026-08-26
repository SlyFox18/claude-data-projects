"""
PARTS LOOKUP REFRESH PIPELINE - ORCHESTRATOR
============================================================================
Runs extract.py -> partition.py -> upload.py in sequence and logs one line
per run (timestamp, success/failure, timing, row count) to refresh.log in
this folder. This is the script Windows Task Scheduler invokes directly.

Security note: extract.py's CREATE SECRET call builds a SQL string with
config.CLIENT_SECRET interpolated directly into it. If that call (or
anything in extract.py/upload.py) raises an exception whose message
happens to include that SQL string or the raw secret value, captured
subprocess stdout/stderr could otherwise land in refresh.log in plaintext.
Every piece of captured output is scrubbed via redact() - which replaces
the literal secret value with a placeholder - before it is ever printed or
written to the log.

Reliability notes (added after a real run stalled 40+ minutes with zero
log output, root-caused to a client-side network hang in upload.py):
- Every subprocess.run() call has a generous (60 min) timeout as
  defense-in-depth, in case something hangs for a reason other than the
  one already fixed at the requests-timeout level inside upload.py.
- main()'s body is wrapped in try/except so an unexpected exception (e.g.
  subprocess.run itself raising, or a step script crashing in a way that
  doesn't cleanly return a nonzero exit code) still produces a logged
  failure instead of silently looking like "never ran." The config import
  below is wrapped separately for the same reason - a misconfigured .env
  raises a KeyError before main() even exists to catch it.
- A lock file guards against overlapping runs if one cycle overruns the
  schedule interval (e.g. a slow upload still running when the next
  hourly trigger fires) - the newer invocation logs SKIPPED and exits
  cleanly rather than running two uploads of the same files concurrently.
  The lock is staleness-checked (see STALE_LOCK_THRESHOLD_SEC below): a
  normal exit (success, failure, or a per-step timeout caught inside
  run_pipeline) always removes it via the try/finally in main(), but a
  hard kill of this process itself (Task Scheduler force-stop past its
  own time limit, a forced TerminateProcess, an OS crash/reboot) skips
  Python's finally entirely and would otherwise leave the lock behind
  forever - silently turning every subsequent scheduled run into a
  logged-success SKIPPED no-op with no failure signal anywhere. The
  staleness check reclaims a lock older than the threshold instead of
  trusting it indefinitely. Lock creation itself is also inside main()'s
  own try/except, not just run_pipeline()'s, so a failure to write the
  lock file (permissions, disk full, path issue) still produces a logged
  failure rather than an uncaught exception with zero refresh.log output.
- upload.py's own real-time per-file stdout (~1,250 lines/run) stays in
  its own console/log when run standalone for live debugging, but only
  its final one-line summary is copied into refresh.log here - looping
  all of it in would add ~30,000 lines/day at hourly cadence.

Alerting (added 2026-08-26): every FAILED path also posts to the "Parts
Availability App Alerts" Teams channel via notify_teams_failure() - see
that function's docstring. Before this, a failed unattended run had no
signal beyond someone opening refresh.log by hand. Optional per
environment (config.TEAMS_WEBHOOK_URL can be unset).
============================================================================
"""

import datetime
import json
import os
import subprocess
import sys
import time

import requests

LOG_PATH = "refresh.log"
LOCK_PATH = "refresh.lock"
STEPS = ["extract.py", "partition.py", "upload.py"]
REDACTED_PLACEHOLDER = "***REDACTED***"
STEP_TIMEOUT_SEC = 60 * 60  # generous ceiling per step; normal runs finish in minutes
# A lock is considered abandoned (not a genuinely in-progress run) once it's
# older than this. Set to 3x STEP_TIMEOUT_SEC + a buffer: 3x because that's
# the true worst-case *legitimate* total run time under the current design
# (all three steps could in the most pathological case each run right up to
# their own STEP_TIMEOUT_SEC before failing and returning control - in
# practice a single hang stops the run at one step, but this stays a safe
# upper bound rather than an average-case guess), plus 5 minutes of buffer
# for filesystem/logging latency around that boundary. At hourly cadence
# this means a lock abandoned by a hard kill self-heals within at most 3
# skipped cycles instead of wedging the pipeline permanently.
STALE_LOCK_THRESHOLD_SEC = STEP_TIMEOUT_SEC * 3 + 5 * 60


def log(message: str) -> None:
    line = f"{datetime.datetime.now().isoformat()} {message}"
    print(line)
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")


try:
    import config
except Exception as exc:
    # No secret has been loaded into memory yet if this fails, so there is
    # nothing to redact - logging the raw exception is safe here.
    log("=== refresh run starting ===")
    log(f"FAILED at config import: {exc}")
    log("=== refresh run FAILED ===")
    sys.exit(1)


def notify_teams_failure(message: str) -> None:
    """Posts a failure alert to the "Parts Availability App Alerts" Teams
    channel - added 2026-08-26 because a failed unattended run previously
    had no signal beyond someone happening to open refresh.log by hand.

    Uses a Teams Workflow's "Send webhook alerts to a channel" trigger,
    the modern replacement for the old Office 365 Incoming Webhook
    connector - it accepts the same legacy MessageCard JSON schema
    already proven working by projects/fabric-monitoring's
    Run-PostPipeline-Monitoring.ps1, just posted here via requests
    instead of Invoke-RestMethod.

    Deliberately never raises: a Teams outage or a bad webhook URL must
    not crash the pipeline or mask the real failure this exists to
    report - both network errors and non-2xx responses are caught and
    just logged as a secondary note. Skips entirely if no webhook URL is
    configured (config.TEAMS_WEBHOOK_URL is None), so Teams alerting
    stays optional per-environment rather than a hard requirement to run
    this pipeline at all.

    `message` must already be redact()-ed by the caller - this function
    doesn't redact anything itself, since every call site already has an
    already-redacted string in hand for refresh.log.
    """
    if not config.TEAMS_WEBHOOK_URL:
        return
    card = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "FF0000",
        "summary": "Parts Lookup Refresh Failed",
        "sections": [
            {
                "activityTitle": "[FAIL] Parts Lookup Refresh",
                "activitySubtitle": datetime.datetime.now().isoformat(),
                "text": message,
            }
        ],
    }
    try:
        resp = requests.post(config.TEAMS_WEBHOOK_URL, json=card, timeout=(10, 15))
        if not resp.ok:
            log(f"  (Teams notification rejected: {resp.status_code} {resp.text[:200]})")
    except requests.exceptions.RequestException as exc:
        log(f"  (Teams notification also failed to send: {exc})")


def log_failure(message: str) -> None:
    """log() plus a Teams alert - the pairing used at every FAILED point in
    this file, so a real failure can't be logged without also being
    alerted (or vice versa)."""
    log(message)
    notify_teams_failure(message)


def redact(text: str) -> str:
    """Strip the literal CLIENT_SECRET value out of captured subprocess text.

    Must be applied to any subprocess stdout/stderr before it is printed or
    logged, since an exception message could echo the secret back (e.g. via
    the interpolated CREATE SECRET SQL string in extract.py).
    """
    if not text:
        return text
    secret = config.CLIENT_SECRET
    if not secret:
        return text
    return text.replace(secret, REDACTED_PLACEHOLDER)


def write_meta_file() -> None:
    """Write output/2char/_meta.json with the current UTC generation timestamp.

    Uploaded by upload.py alongside the partition files (it lives in the
    same output/2char/ directory upload.py already reads), so the frontend
    can fetch a single small file to display "Data as of ..." instead of
    relying on a per-row timestamp that no longer exists in the static
    files.
    """
    meta_path = os.path.join("output", "2char", "_meta.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(
            {"generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()},
            f,
        )


def run_pipeline() -> int:
    log("=== refresh run starting ===")
    for step in STEPS:
        if step == "upload.py":
            # Write the fresh generation timestamp just before upload.py
            # runs, so this cycle's own upload picks it up immediately -
            # writing it after the whole loop (including upload.py) would
            # leave it sitting locally until the *next* cycle's upload,
            # making "Data as of" lag a full hour behind the real refresh.
            try:
                write_meta_file()
            except OSError as exc:
                log_failure(f"FAILED at write_meta_file: {exc}")
                log("=== refresh run FAILED ===")
                return 1
        try:
            result = subprocess.run(
                [sys.executable, step],
                capture_output=True,
                text=True,
                timeout=STEP_TIMEOUT_SEC,
            )
        except subprocess.TimeoutExpired as exc:
            partial_stderr = redact((exc.stderr or "").strip())[-500:]
            log_failure(
                f"FAILED at {step}: exceeded {STEP_TIMEOUT_SEC}s timeout and was "
                f"killed. Partial stderr: {partial_stderr}"
            )
            log("=== refresh run FAILED ===")
            return 1

        if result.returncode != 0:
            safe_stderr = redact(result.stderr.strip())[-500:]
            log_failure(f"FAILED at {step}: {safe_stderr}")
            log("=== refresh run FAILED ===")
            return 1

        safe_stdout = redact(result.stdout.strip())
        lines = safe_stdout.splitlines()
        if step == "upload.py":
            # Real-time per-file progress (~1,250 lines/run) is useful when
            # upload.py is run standalone for live debugging, but copying
            # all of it into refresh.log would bloat it unboundedly at
            # hourly cadence - keep only the final summary line, matching
            # extract.py/partition.py's already-concise output.
            lines = lines[-1:] if lines else []
        for line in lines:
            log(f"  [{step}] {line}")
    log("=== refresh run completed successfully ===")
    return 0


def _acquire_lock() -> bool:
    """Atomically creates the lock file if no live lock currently exists.

    Uses exclusive-create ("x" mode) rather than a separate
    exists()-then-open() pair, closing the check-then-act race a plain
    os.path.exists() + open("w") would have between two invocations
    starting at nearly the same instant (a low-risk gap for a single
    hourly-triggered scheduler, but free to close here).

    Returns True if this call created the lock (safe to proceed). Returns
    False if a live lock already exists (a run is genuinely in progress).
    If an existing lock is older than STALE_LOCK_THRESHOLD_SEC, treats it
    as abandoned by a hard-killed prior process, removes it, and creates a
    fresh one instead of skipping.
    """
    try:
        with open(LOCK_PATH, "x", encoding="utf-8") as f:
            f.write(str(os.getpid()))
        return True
    except FileExistsError:
        pass

    lock_age_sec = time.time() - os.path.getmtime(LOCK_PATH)
    if lock_age_sec < STALE_LOCK_THRESHOLD_SEC:
        return False

    log(
        f"Found stale lock file (age {lock_age_sec:.0f}s > "
        f"{STALE_LOCK_THRESHOLD_SEC}s threshold) - removing and proceeding"
    )
    os.remove(LOCK_PATH)
    with open(LOCK_PATH, "x", encoding="utf-8") as f:
        f.write(str(os.getpid()))
    return True


def main() -> int:
    try:
        acquired = _acquire_lock()
    except OSError as exc:
        # Covers a failure to write/remove the lock file itself
        # (permissions, disk full, path issue) as well as the narrow race
        # where a stale lock is reclaimed by two invocations at once - both
        # must still produce a logged failure rather than an uncaught
        # exception with zero refresh.log output.
        log_failure(f"FAILED: could not acquire lock file - {exc}")
        return 1

    if not acquired:
        log("SKIPPED - previous run still in progress")
        return 0

    try:
        return run_pipeline()
    except Exception as exc:
        log_failure(f"FAILED: unexpected error - {redact(str(exc))}")
        log("=== refresh run FAILED ===")
        return 1
    finally:
        try:
            os.remove(LOCK_PATH)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
