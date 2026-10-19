"""
Loads the service principal credentials and SharePoint identifiers needed
by the unattended refresh pipeline (extract.py, upload.py, run_refresh.py).

Values come from a local .env file (or the file named by PARTS_LOOKUP_ENV_FILE) (gitignored, never committed) - copy
.env.example to .env and fill in the real values from Task 2 before running
anything in this pipeline unattended.
"""

import os

from dotenv import load_dotenv

# PARTS_LOOKUP_ENV_FILE picks another env file, e.g. .env.test (the staging SharePoint library, no Teams
# webhook, PARTS_LOOKUP_SOURCE=dp-dev) for test runs from Brian's PC. Default: .env.
load_dotenv(os.environ.get("PARTS_LOOKUP_ENV_FILE", ".env"))

TENANT_ID = os.environ["TENANT_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ["CLIENT_SECRET"]
SITE_ID = os.environ["SITE_ID"]
DRIVE_ID = os.environ["DRIVE_ID"]
LIBRARY_BASE = os.environ["LIBRARY_BASE"]

# Optional - Teams webhook for refresh-failure alerts (added 2026-08-26).
# Unlike the values above, this one is allowed to be missing: run_refresh.py
# treats an unset webhook as "alerting not configured" and just skips it
# (logged, not fatal), rather than requiring every environment that runs
# this pipeline to have Teams alerting set up.
TEAMS_WEBHOOK_URL = os.environ.get("TEAMS_WEBHOOK_URL")

# Which table extract.py reads (see refresh_logic.SOURCES): "dp" since the cutover on 2026-10-19; "lh" to roll
# back (only while LH's df_InMaster_PartsLookup_Raw schedule is still on). An env file can override it per
# machine or per test run (PARTS_LOOKUP_SOURCE=dp-dev).
SOURCE = os.environ.get("PARTS_LOOKUP_SOURCE", "dp")
