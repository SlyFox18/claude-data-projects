"""
Loads the service principal credentials and SharePoint identifiers needed
by the unattended refresh pipeline (extract.py, upload.py, run_refresh.py).

Values come from a local .env file (gitignored, never committed) - copy
.env.example to .env and fill in the real values from Task 2 before running
anything in this pipeline unattended.
"""

import os

from dotenv import load_dotenv

load_dotenv()

TENANT_ID = os.environ["TENANT_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ["CLIENT_SECRET"]
SITE_ID = os.environ["SITE_ID"]
DRIVE_ID = os.environ["DRIVE_ID"]
LIBRARY_BASE = os.environ["LIBRARY_BASE"]
