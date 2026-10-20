"""Settings for the Non-JD order tool publish script, from .env (or the file named by NONJD_ENV_FILE)."""
import os

from dotenv import load_dotenv

load_dotenv(os.environ.get("NONJD_ENV_FILE", ".env"))

TENANT_ID = os.environ["TENANT_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "")
SITE_ID = os.environ["SITE_ID"]
DRIVE_ID = os.environ["DRIVE_ID"]
SOURCE = os.environ.get("NONJD_SOURCE", "dev")

PRESENTATION = {
    "dev": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91"),
    "prod": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f"),
}
if SOURCE not in PRESENTATION:
    raise ValueError(f"NONJD_SOURCE must be one of {sorted(PRESENTATION)}, not {SOURCE!r}")


def table_path(table: str) -> str:
    ws, lh = PRESENTATION[SOURCE]
    return f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"
