"""
PARTS LOOKUP REFRESH PIPELINE - UPLOAD
============================================================================
Pushes the partitioned JSON files (from partition.py's output/2char/) to
the SharePoint test library via Microsoft Graph API, using the service
principal's client-credentials token. Overwrites existing files by name -
no separate delete/cleanup step needed since partition filenames are
stable across runs.

Handles files over Graph's 4 MB simple-upload limit via a chunked upload
session (some partition files, e.g. the RE prefix, are ~18 MB).

Retries transient Graph/SharePoint errors (409/423/429/503/504) with
backoff - confirmed via a real 1,248-file run that SharePoint can return a
transient 409 Conflict under sustained sequential write load even with no
actual concurrent writer; an immediate retry of the identical request
succeeded, so this is not treated as a fatal error.

Every Graph call (session creation, chunk PUT, simple PUT) goes through
request_with_retry, which also retries network-level exceptions
(ConnectionError, Timeout, ChunkedEncodingError, etc.) and sets an
explicit (connect, read) timeout tuple - without one, requests waits
forever by default, which on an unattended schedule turns one stalled
connection into a hung process instead of a failed run the next
scheduled cycle can retry. A single scalar timeout only bounds the read
phase reliably; splitting it out bounds the connect phase specifically,
since a real run stalled for 40+ minutes on what was very likely a
connect/DNS-level hang that a single-value timeout did not catch (a
known Windows/urllib3 edge case - DNS resolution itself is not fully
covered by either value, so this tightens but does not eliminate that
risk).
============================================================================
"""

import glob
import os
import time

import msal
import requests

import config

GRAPH_BASE = "https://graph.microsoft.com/v1.0"
SIMPLE_UPLOAD_LIMIT = 4 * 1024 * 1024  # Graph API's simple-upload ceiling
CHUNK_SIZE = 4 * 1024 * 1024  # must be a multiple of 320 KiB per Graph docs
SOURCE_DIR = "output/2char"
RETRYABLE_STATUS_CODES = {409, 423, 429, 503, 504}
MAX_RETRIES = 5
RETRY_BACKOFF_SEC = 3
CONNECT_TIMEOUT_SEC = 10  # time to establish the TCP connection
READ_TIMEOUT_SEC = 30  # time between bytes once the connection is open


def get_access_token() -> str:
    app = msal.ConfidentialClientApplication(
        client_id=config.CLIENT_ID,
        client_credential=config.CLIENT_SECRET,
        authority=f"https://login.microsoftonline.com/{config.TENANT_ID}",
    )
    result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    if "access_token" not in result:
        raise RuntimeError(f"Failed to acquire Graph token: {result.get('error_description')}")
    return result["access_token"]


def request_with_retry(
    method: str, url: str, headers: dict, data: bytes | None = None, json: dict | None = None
) -> requests.Response:
    """PUT/POST with retry-and-backoff on transient Graph/SharePoint errors.

    Covers two distinct failure modes seen (or plausible) across a
    ~1,250-request, ~20-minute sequential run:

    1. Transient bad status codes - a real end-to-end run hit a 409
       Conflict on a single file near the end of a 1,248-file run with no
       concurrent writer involved; retrying the identical request
       immediately succeeded, confirming it was a transient SharePoint
       condition under sustained write load rather than a real naming or
       permission conflict.
    2. Network-level exceptions (ConnectionError, Timeout,
       ChunkedEncodingError, etc.) - plausible across that many sequential
       requests and previously propagated uncaught, killing the whole run
       with zero retry even though this retry machinery existed.

    Every call also sets an explicit timeout - without one, requests waits
    forever by default, which on an unattended schedule turns one stalled
    connection into a hung process instead of a failed run the next
    scheduled cycle can retry.
    """
    last_exc = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.request(
                method, url, headers=headers, data=data, json=json,
                timeout=(CONNECT_TIMEOUT_SEC, READ_TIMEOUT_SEC),
            )
        except requests.exceptions.RequestException as exc:
            last_exc = exc
        else:
            if resp.status_code not in RETRYABLE_STATUS_CODES:
                return resp
            last_exc = requests.exceptions.HTTPError(
                f"{resp.status_code} error (attempt {attempt}/{MAX_RETRIES}) for url: {url}",
                response=resp,
            )
        if attempt < MAX_RETRIES:
            time.sleep(RETRY_BACKOFF_SEC * attempt)
    raise last_exc


def upload_file(local_path: str, file_name: str, access_token: str) -> None:
    file_size = os.path.getsize(local_path)
    headers = {"Authorization": f"Bearer {access_token}"}

    if file_size <= SIMPLE_UPLOAD_LIMIT:
        url = f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}/root:/{file_name}:/content"
        with open(local_path, "rb") as f:
            resp = request_with_retry("PUT", url, headers, data=f.read())
        resp.raise_for_status()
        return

    session_url = (
        f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}"
        f"/root:/{file_name}:/createUploadSession"
    )
    session_resp = request_with_retry(
        "POST",
        session_url,
        headers,
        json={"item": {"@microsoft.graph.conflictBehavior": "replace"}},
    )
    session_resp.raise_for_status()
    upload_url = session_resp.json()["uploadUrl"]

    with open(local_path, "rb") as f:
        offset = 0
        while offset < file_size:
            chunk = f.read(CHUNK_SIZE)
            chunk_len = len(chunk)
            chunk_headers = {
                "Content-Length": str(chunk_len),
                "Content-Range": f"bytes {offset}-{offset + chunk_len - 1}/{file_size}",
            }
            # No Authorization header here - upload session URLs are pre-authenticated.
            chunk_resp = request_with_retry("PUT", upload_url, chunk_headers, data=chunk)
            chunk_resp.raise_for_status()
            offset += chunk_len


def main() -> None:
    access_token = get_access_token()
    files = sorted(glob.glob(os.path.join(SOURCE_DIR, "*.json")))
    if not files:
        raise RuntimeError(f"No files found in {SOURCE_DIR} - run partition.py first")

    start = time.time()
    for i, path in enumerate(files, 1):
        file_name = os.path.basename(path)
        print(f"  uploading {file_name}...", flush=True)
        upload_file(path, file_name, access_token)
        if i % 100 == 0:
            print(f"  uploaded {i}/{len(files)}")
    elapsed = time.time() - start

    print(f"Uploaded {len(files)} files in {elapsed:.1f} sec")


if __name__ == "__main__":
    main()
