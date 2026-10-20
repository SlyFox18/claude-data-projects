"""Upload files to the SharePoint library through Graph, as the publish SPN. Simple PUT (files must be <= 4 MB)."""
import os
import time

import msal
import requests

import config

GRAPH = "https://graph.microsoft.com/v1.0"
SIMPLE_LIMIT = 4 * 1024 * 1024
RETRY_STATUS = {409, 423, 429, 500, 502, 503, 504}
TIMEOUT = (10, 60)


class _TimeoutSession(requests.Session):
    """Session that enforces a default (connect, read) timeout; msal's token call has no timeout parameter,
    so without this a stalled connection hangs an unattended run."""

    def request(self, *args, **kwargs):
        kwargs.setdefault("timeout", TIMEOUT)
        return super().request(*args, **kwargs)


def token() -> str:
    if not config.CLIENT_SECRET:
        raise RuntimeError("CLIENT_SECRET is empty; uploads need the service principal")
    app = msal.ConfidentialClientApplication(config.CLIENT_ID, client_credential=config.CLIENT_SECRET,
                                             authority=f"https://login.microsoftonline.com/{config.TENANT_ID}",
                                             http_client=_TimeoutSession())
    result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    if "access_token" not in result:
        raise RuntimeError(f"Graph token failed: {result.get('error_description')}")
    return result["access_token"]


def put_file(path: str, access_token: str, attempts: int = 5) -> None:
    size = os.path.getsize(path)
    if size > SIMPLE_LIMIT:
        raise RuntimeError(f"{path} is {size:,} bytes; add a chunked upload session (see plan Task 11 Step 8)")
    name = os.path.basename(path)
    url = f"{GRAPH}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}/root:/{name}:/content"
    with open(path, "rb") as f:
        data = f.read()
    last, wait = None, 0
    for i in range(1, attempts + 1):
        try:
            r = requests.put(url, headers={"Authorization": f"Bearer {access_token}"}, data=data, timeout=TIMEOUT)
        except requests.exceptions.RequestException as ex:      # network-level only
            last, wait = ex, 3 * i
        else:
            if r.ok:
                return
            detail = f"HTTP {r.status_code} uploading {name} (attempt {i}/{attempts}): {r.text[:300]}"
            if r.status_code not in RETRY_STATUS:
                raise RuntimeError(detail)
            last = RuntimeError(detail)
            ra = r.headers.get("Retry-After", "")
            wait = min(int(ra), 120) if ra.isdigit() else 3 * i
        if i < attempts:
            time.sleep(wait)
    raise last
