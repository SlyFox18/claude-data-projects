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
- upload.py's own real-time per-file stdout (~1,250 lines/run) stays in
  its own console/log when run standalone for live debugging, but only
  its final one-line summary is copied into refresh.log here - looping
  all of it in would add ~30,000 lines/day at hourly cadence.
============================================================================
"""

import datetime
import os
import subprocess
import sys

LOG_PATH = "refresh.log"
LOCK_PATH = "refresh.lock"
STEPS = ["extract.py", "partition.py", "upload.py"]
REDACTED_PLACEHOLDER = "***REDACTED***"
STEP_TIMEOUT_SEC = 60 * 60  # generous ceiling per step; normal runs finish in minutes


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


def run_pipeline() -> int:
    log("=== refresh run starting ===")
    for step in STEPS:
        try:
            result = subprocess.run(
                [sys.executable, step],
                capture_output=True,
                text=True,
                timeout=STEP_TIMEOUT_SEC,
            )
        except subprocess.TimeoutExpired as exc:
            partial_stderr = redact((exc.stderr or "").strip())[-500:]
            log(
                f"FAILED at {step}: exceeded {STEP_TIMEOUT_SEC}s timeout and was "
                f"killed. Partial stderr: {partial_stderr}"
            )
            log("=== refresh run FAILED ===")
            return 1

        if result.returncode != 0:
            safe_stderr = redact(result.stderr.strip())[-500:]
            log(f"FAILED at {step}: {safe_stderr}")
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


def main() -> int:
    if os.path.exists(LOCK_PATH):
        log("SKIPPED - previous run still in progress")
        return 0

    with open(LOCK_PATH, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    try:
        return run_pipeline()
    except Exception as exc:
        log(f"FAILED: unexpected error - {redact(str(exc))}")
        log("=== refresh run FAILED ===")
        return 1
    finally:
        try:
            os.remove(LOCK_PATH)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
