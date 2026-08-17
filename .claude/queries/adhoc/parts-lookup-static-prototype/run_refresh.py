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
============================================================================
"""

import datetime
import subprocess
import sys

import config

LOG_PATH = "refresh.log"
STEPS = ["extract.py", "partition.py", "upload.py"]
REDACTED_PLACEHOLDER = "***REDACTED***"


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


def log(message: str) -> None:
    line = f"{datetime.datetime.now().isoformat()} {message}"
    print(line)
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main() -> int:
    log("=== refresh run starting ===")
    for step in STEPS:
        result = subprocess.run(
            [sys.executable, step], capture_output=True, text=True
        )
        if result.returncode != 0:
            safe_stderr = redact(result.stderr.strip())[-500:]
            log(f"FAILED at {step}: {safe_stderr}")
            log("=== refresh run FAILED ===")
            return 1
        safe_stdout = redact(result.stdout.strip())
        for line in safe_stdout.splitlines():
            log(f"  [{step}] {line}")
    log("=== refresh run completed successfully ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
