"""Test settings: dummy values so config imports without a real .env (set before any test module imports it)."""
import os

os.environ["NONJD_ENV_FILE"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "no-such.env")
for _k, _v in {"TENANT_ID": "t", "CLIENT_ID": "c", "SITE_ID": "s", "DRIVE_ID": "d",
               "NONJD_SOURCE": "dev", "CLIENT_SECRET": "x"}.items():
    os.environ[_k] = _v
