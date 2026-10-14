"""Act as SPITractor_Fabric_Integration_Admin to inspect (and optionally share) JD's ODBC connection.

Usage:
  python spn_grant_connection.py            # read-only: connection, its role assignments, its gateway
  python spn_grant_connection.py --grant    # also add Brian as Owner of the connection

The client secret is read from a hidden prompt (or env var SPN_CLIENT_SECRET) and never stored.
"""
import getpass, json, os, sys
import requests
from azure.identity import ClientSecretCredential

TENANT = "8a02a2b8-0092-4de5-8f76-4700d099feb1"
APP_ID = "2ce2664f-d2e7-4efb-aae9-f2244125de9b"           # SPITractor_Fabric_Integration_Admin
CONNECTION = "b062a489-87a3-4c63-9bfe-fdfe2c4732fb"       # JD's EquipRDB ODBC connection
BRIAN = "b9c4be2c-3707-4cdd-a7db-59751caa90d2"
API = "https://api.fabric.microsoft.com/v1"

secret = os.environ.get("SPN_CLIENT_SECRET") or getpass.getpass("SPN client secret (hidden): ")
token = ClientSecretCredential(TENANT, APP_ID, secret).get_token("https://api.fabric.microsoft.com/.default").token
H = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

def get(path):
    r = requests.get(f"{API}/{path}", headers=H)
    return r.status_code, (r.json() if r.content else {})

code, conn = get(f"connections/{CONNECTION}")
print("connection:", code)
if code != 200:
    sys.exit(json.dumps(conn, indent=1))
details = conn.get("connectionDetails", {})
creds = conn.get("credentialDetails", {})
print(f"  name={conn.get('displayName')}  type={details.get('type')}  path={details.get('path')}")
print(f"  connectivity={conn.get('connectivityType')}  gateway={conn.get('gatewayId')}  auth={creds.get('credentialType')}")

code, roles = get(f"connections/{CONNECTION}/roleAssignments")
print("connection roles:", code)
for r in roles.get("value", []):
    print("  ", r.get("role"), r.get("principal", {}).get("type"), r.get("principal", {}).get("id"))

gw = conn.get("gatewayId")
if gw:
    code, g = get(f"gateways/{gw}")
    print("gateway:", code, g.get("displayName"), g.get("type"))
    code, groles = get(f"gateways/{gw}/roleAssignments")
    print("gateway roles:", code)
    for r in groles.get("value", []):
        print("  ", r.get("role"), r.get("principal", {}).get("type"), r.get("principal", {}).get("id"))

if "--grant" in sys.argv:
    if any(r.get("principal", {}).get("id") == BRIAN for r in roles.get("value", [])):
        print("\nBrian already has a role on the connection.")
    else:
        r = requests.post(f"{API}/connections/{CONNECTION}/roleAssignments", headers=H,
                          json={"principal": {"id": BRIAN, "type": "User"}, "role": "Owner"})
        print("\ngrant Brian Owner:", r.status_code, r.text[:300])
