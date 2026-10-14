# DP Refresh Notifications via Microsoft Graph — Implementation Plan

> **Status 2026-10-05: DONE.** Built, validated in Dev with 3 drills, deployed to Prod (PR #18, deploy run 37337445301). Changes from the plan as written:
> - **No Key Vault.** "Azure subscription 1" isn't Brian's, so the client secret lives in `Files/secrets/dp-refresh-notify.txt` in each DP_Presentation lakehouse (Dev and Prod). It isn't in Git, and the workspaces hold only Brian and the 2 service principals. Config uses `secretFile`; Key Vault stays supported (`keyVaultUri` + `secretName`) for later.
> - **The secret expires 10/5/2027** (Entra secret "dp-refresh-notify" on SPN-Fabric-Refresh-Automation). To rotate: create a new secret, then replace both files.
> - **The Teams channel's email setting must be "Only email sent from these domains: spitractor.com".** "Members only" makes Teams bounce mail from the shared mailbox ("Undeliverable: Email cannot be delivered to channel").
> - **Additions:**
>   - terminal Fail steps, so a crash shows as Failed in the Monitor;
>   - retry on 429/5xx;
>   - fail loudly when the tier or config is unknown;
>   - a "notifications could not be sent" crash message.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Pipeline_DP_Refresh` sends its summary email, alert email, Teams post and crash notices without personal Outlook/Teams connections, so CI can deploy it to Prod.

**Architecture:**
- **The Gold orchestrator notebook sends the notifications.** The orchestrator already builds the subject, HTML body and Teams text. Its Gold copy sends them through Microsoft Graph `sendMail` as the app **SPN-Fabric-Refresh-Automation**.
- **The app sends from a shared mailbox only.** It has no tenant-wide mail permission. Exchange "RBAC for Applications" scopes it to the shared mailbox `dp-refresh@spitractor.com`.
- **Teams posts go to the channel's email address.**
- **The app's client secret lives in a new Azure Key Vault.** Notebooks read it with `notebookutils.credentials.getSecret`, as the identity running the pipeline.
- **Crashes go through a new `Notify_DP_Refresh` notebook.** When an orchestrator notebook crashes before reporting, the pipeline runs this notebook on the failure path.
- **The pipeline is left with notebook activities only.**
- **Settings live in `dp_refresh_dag.json` → `orchestrator.notify`,** per environment.

**Tech Stack:** Python 3.12 (pytest), Fabric notebooks (`notebookutils`, `requests`), Microsoft Graph v1.0 `sendMail`, Exchange Online PowerShell (RBAC for Applications), Azure Key Vault (RBAC mode), fabric-cicd.

**Repos:**
- `F` = `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs` (branch `dev`).
- `D` = `C:\Users\bfox\Documents\Git-Projects\data-projects`.

**Context:**
- **Why this plan:** the first Prod deploy (2026-10-05, run 37320689475) published 106 of 107 items. `Pipeline_DP_Refresh` failed with *"User does not have access to the connection used in the Pipeline"*. Its Outlook and Teams connections (`MicrosoftOutlook bfox`, `MicrosoftTeams bfox`) are personal and can't be shared with a service principal.
- **Bug fixed along the way:** the crash subjects hard-code `[Dev]`.

**Known IDs:**
- Tenant `8a02a2b8-0092-4de5-8f76-4700d099feb1`.
- SPN-Fabric-Refresh-Automation: app (client) ID `9adca971-f328-4d79-9b48-713c298a238c`, service-principal object ID `8f71b80d-2698-42db-82cf-10ef0ffb8f12`.
- Azure subscription "Azure subscription 1".
- The Teams channel used today: team `75d69eaf-2d57-4c84-a71a-0d3822bb60c4`, channel `19:ldjrYoLypYQcH6H4pg4TGYTzQEfcN1xHXXXd6HDcHkc1@thread.tacv2`.

**Behaviour preserved from today's pipeline:**
- A summary email goes out on every run.
- An alert email (high importance) goes out when `alert_email` is set: status `error` or `bronze_failed`.
- A Teams post goes out when `teams` is set: `error`, `bronze_failed` or `partial`.
- A crash email and crash Teams post go out when a notebook activity fails.

---

## File Structure (repo F)

| File | Responsibility |
|---|---|
| `deploy/notify_core.py` (new, pure, unit-tested) | Message list for a run summary; crash summary; Graph `sendMail` body; config validation |
| `deploy/notify_send.py` (new, Fabric-only) | Read the secret from Key Vault, get a Graph token, send each message, return the errors |
| `deploy/notify_glue.py` (new, Fabric-only) | Body of the `Notify_DP_Refresh` notebook |
| `deploy/orchestrator_glue.py` (modify) | Gold tier: send the notifications; `simulate_crash` drill parameter |
| `deploy/render_orchestrator.py` (modify) | Render notify code into both orchestrators, and render `Notify_DP_Refresh`; exit cell fails the run when notification failed |
| `deploy/dag_config.py` (modify) | Validate `orchestrator.notify` |
| `deploy/dp_refresh_dag.json` (modify) | `orchestrator.notify` settings |
| `deploy/prod_scope.py` (modify) | Deploy `Notify_DP_Refresh` to Prod |
| `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json` (modify) | Notebook-only pipeline |
| Rendered: `workspaces/DP - Presentation - Dev/Orchestration/Notify_DP_Refresh.Notebook/` (new), both `Run_DP_Refresh.Notebook` (re-rendered) | Generated notebooks; never edit by hand |
| Tests: `deploy/test_notify_core.py` (new), `deploy/test_dag_config.py`, `deploy/test_prod_scope.py`, `deploy/test_render_orchestrator.py` (modify) | |

---

### Task 1: Tenant setup (Brian, guided step by step; agent verifies after each)

**Files:** none. **Never paste a client secret into chat or into any file.**

- [ ] **Step 1: Create the shared mailbox.** In the Exchange admin center (admin.exchange.microsoft.com) → Recipients → Mailboxes → **Add a shared mailbox**: display name `DP Refresh`, email `dp-refresh@spitractor.com`. If that address is taken, choose another and note it. Shared mailboxes need no license.
- [ ] **Step 2: Get the Teams channel's email address.** In Teams, open the channel the DP refresh posts to today → **…** → **Get email address** → copy the address. Under **Advanced settings**, allow **Only email sent from these domains**: `spitractor.com`. Paste the address into the chat; it isn't secret.
- [ ] **Step 3: Create the Key Vault (RBAC mode).** In the Azure portal → **Key vaults** → **Create**:
  - subscription "Azure subscription 1";
  - new resource group `rg-spi-dataplatform`;
  - name `kv-spi-dataplatform` (globally unique; if taken, use `kv-spi-dataplatform2` and note it);
  - region South Central US;
  - **Access configuration: Azure role-based access control**;
  - Networking left at the default (public).

  Create it.
- [ ] **Step 4: Grant Key Vault roles.** Key vault → **Access control (IAM)** → **Add role assignment**:
  - **Key Vault Secrets Officer** for yourself (to create the secret);
  - **Key Vault Secrets User** for yourself (the Dev and Prod pipelines run as you, and Fabric reads the secret as the pipeline identity);
  - **Key Vault Secrets User** for `SPN-Fabric-Refresh-Automation` (for the later service-principal-run refresh).
- [ ] **Step 5: Create the client secret straight into Key Vault.**
  1. Entra admin center → App registrations → **SPN-Fabric-Refresh-Automation** → Certificates & secrets → **New client secret**, description `dp-refresh-notify`, expiry 12 months. **Copy the Value** (not the ID).
  2. Immediately: Key vault → Secrets → **Generate/Import**, name `dp-refresh-notify-client-secret`, paste the value, set the expiration date to the same as the client secret's, Create.
  3. Close the Entra page. Don't paste the value anywhere else.
- [ ] **Step 6: Scope Mail.Send to the shared mailbox with Exchange RBAC for Applications.** Do **not** add the Graph `Mail.Send` application permission in Entra; that would allow sending as any mailbox. In PowerShell as an Exchange admin:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # if not installed
Connect-ExchangeOnline
New-ServicePrincipal -AppId 9adca971-f328-4d79-9b48-713c298a238c -ObjectId 8f71b80d-2698-42db-82cf-10ef0ffb8f12 -DisplayName "SPN-Fabric-Refresh-Automation"
New-ManagementScope -Name "DP Refresh sender" -RecipientRestrictionFilter "PrimarySmtpAddress -eq 'dp-refresh@spitractor.com'"
New-ManagementRoleAssignment -App 9adca971-f328-4d79-9b48-713c298a238c -Role "Application Mail.Send" -CustomResourceScope "DP Refresh sender"
Test-ServicePrincipalAuthorization -Identity 9adca971-f328-4d79-9b48-713c298a238c -Resource dp-refresh@spitractor.com
Test-ServicePrincipalAuthorization -Identity 9adca971-f328-4d79-9b48-713c298a238c -Resource bfox@spitractor.com
Disconnect-ExchangeOnline -Confirm:$false
```
  Expected: the first `Test-ServicePrincipalAuthorization` shows `Application Mail.Send` with **InScope True**; the second (your own mailbox) shows **InScope False**. Exchange permission changes can take up to about an hour to apply.
- [ ] **Step 7: Agent verification (read-only).** Run `az keyvault show -n kv-spi-dataplatform --query "{rbac:properties.enableRbacAuthorization, uri:properties.vaultUri}"` and `az keyvault secret show --vault-name kv-spi-dataplatform -n dp-refresh-notify-client-secret --query "{name:name, enabled:attributes.enabled, expires:attributes.expires}"`. **Never print the value.** Expected: rbac true; the secret exists and is enabled.
- [ ] **Step 8: Record the setup values** for Task 3: the vault URI (`https://kv-spi-dataplatform.vault.azure.net/` unless renamed), the sender address, and the Teams channel email.

---

### Task 2: notify_core — pure message logic

**Files:** Create `deploy/notify_core.py`, `deploy/test_notify_core.py`.

- [ ] **Step 1: Write the failing tests** (`deploy/test_notify_core.py`)

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from notify_core import check_notify, crash_summary, graph_mail, notify_messages  # noqa: E402

NOTIFY = {
    "tenantId": "t", "clientId": "c", "keyVaultUri": "https://kv.vault.azure.net/",
    "secretName": "s", "sender": "dp-refresh@x.com",
    "recipients": {"Dev": {"summary": ["a@x.com"], "alert": ["b@x.com"], "teams": ["chan@x.teams.ms"]}},
}


def _summary(**kw):
    s = {"subject": "S", "html": "<p>H</p>", "teams_text": "T <&>", "alert_email": False, "teams": False}
    s.update(kw)
    return s


def test_ok_run_sends_only_the_summary_email():
    msgs = notify_messages(_summary(), NOTIFY, "Dev")
    assert msgs == [{"to": ["a@x.com"], "subject": "S", "html": "<p>H</p>", "importance": "normal"}]


def test_error_run_sends_summary_alert_and_teams():
    msgs = notify_messages(_summary(alert_email=True, teams=True), NOTIFY, "Dev")
    assert [m["to"] for m in msgs] == [["a@x.com"], ["b@x.com"], ["chan@x.teams.ms"]]
    assert msgs[1]["importance"] == "high"
    assert msgs[2]["html"] == "<p>T &lt;&amp;&gt;</p>"


def test_empty_recipient_lists_are_dropped():
    cfg = {**NOTIFY, "recipients": {"Dev": {"summary": ["a@x.com"], "alert": [], "teams": []}}}
    assert len(notify_messages(_summary(alert_email=True, teams=True), cfg, "Dev")) == 1


def test_crash_summary_labels_env_and_tier():
    s = crash_summary("Prod", "Gold", "boom <x>", "run-1")
    assert s["subject"] == "🔴 [Prod] DP Refresh FAILED – Gold orchestrator crashed"
    assert "boom &lt;x&gt;" in s["html"] and "rerun_failed" in s["html"] and "run-1" in s["html"]
    assert s["alert_email"] is True and s["teams"] is True
    assert "Run Pipeline_DP_Refresh again" in crash_summary("Dev", "Silver", "e", "r")["html"]


def test_graph_mail_body():
    body = graph_mail({"to": ["a@x.com", "b@x.com"], "subject": "S", "html": "<p>H</p>", "importance": "high"})
    assert body == {"message": {"subject": "S", "importance": "high",
                                "body": {"contentType": "HTML", "content": "<p>H</p>"},
                                "toRecipients": [{"emailAddress": {"address": "a@x.com"}},
                                                 {"emailAddress": {"address": "b@x.com"}}]},
                    "saveToSentItems": True}


def test_check_notify_accepts_valid_config():
    assert check_notify(NOTIFY) == []


def test_check_notify_reports_missing_keys_and_bad_addresses():
    errors = check_notify({"sender": "nope", "recipients": {"Dev": {"summary": ["x"], "alert": "y"}}})
    joined = " | ".join(errors)
    for needle in ("tenantId", "clientId", "keyVaultUri", "secretName", "sender", "Dev.summary", "Dev.alert", "Dev.teams"):
        assert needle in joined, needle
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd F && python -m pytest deploy/test_notify_core.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'notify_core'`.

- [ ] **Step 3: Implement** (`deploy/notify_core.py`)

```python
"""Pure notification logic for Pipeline_DP_Refresh (rendered into Run_DP_Refresh and Notify_DP_Refresh).

The Gold orchestrator (and, on a crash, Notify_DP_Refresh) sends these through Microsoft Graph sendMail as
SPN-Fabric-Refresh-Automation from a shared mailbox; Teams gets a copy at the channel's email address.
"""
import html as _html

NOTIFY_KEYS = ("tenantId", "clientId", "keyVaultUri", "secretName", "sender")
RECIPIENT_LISTS = ("summary", "alert", "teams")


def notify_messages(summary: dict, notify: dict, env: str) -> list:
    """Messages for one run: summary email always; alert email (high) when alert_email; Teams copy when teams."""
    r = notify["recipients"][env]
    msgs = [{"to": list(r["summary"]), "subject": summary["subject"], "html": summary["html"], "importance": "normal"}]
    if summary.get("alert_email"):
        msgs.append({"to": list(r["alert"]), "subject": summary["subject"], "html": summary["html"],
                     "importance": "high"})
    if summary.get("teams"):
        msgs.append({"to": list(r["teams"]), "subject": summary["subject"],
                     "html": f"<p>{_html.escape(summary['teams_text'])}</p>", "importance": "normal"})
    return [m for m in msgs if m["to"]]


def crash_summary(env: str, tier: str, error: str, run_id: str) -> dict:
    """Summary for an orchestrator notebook that failed before it could report (tier: 'Silver' or 'Gold')."""
    subject = f"🔴 [{env}] DP Refresh FAILED – {tier} orchestrator crashed"
    next_step = ("Run Pipeline_DP_Refresh again." if tier == "Silver"
                 else "Silver finished; run Pipeline_DP_Refresh with mode = rerun_failed.")
    e = _html.escape
    body = (f"<p><b>{e(subject)}</b><br>Run {e(run_id)}</p>"
            f"<p>Run_DP_Refresh ({e(tier)}) failed before it could report. Error:</p><pre>{e(error[:3000])}</pre>"
            f"<p>Open the pipeline run in the Fabric Monitor for details, fix, then: {e(next_step)}</p>")
    return {"status": "error", "subject": subject, "html": body, "teams_text": f"{subject} | {error[:500]}",
            "alert_email": True, "teams": True}


def graph_mail(msg: dict) -> dict:
    """Request body for POST /users/{sender}/sendMail."""
    return {"message": {"subject": msg["subject"], "importance": msg["importance"],
                        "body": {"contentType": "HTML", "content": msg["html"]},
                        "toRecipients": [{"emailAddress": {"address": a}} for a in msg["to"]]},
            "saveToSentItems": True}


def check_notify(notify) -> list:
    """Config errors for orchestrator.notify (used by dag_config)."""
    if not isinstance(notify, dict):
        return ["orchestrator: notify must be an object"]
    errors = [f"orchestrator.notify: missing {k}" for k in NOTIFY_KEYS if not isinstance(notify.get(k), str) or not notify.get(k)]
    if "@" not in str(notify.get("sender", "")):
        errors.append("orchestrator.notify: sender must be an email address")
    recipients = notify.get("recipients")
    if not isinstance(recipients, dict) or not recipients:
        return errors + ["orchestrator.notify: recipients must map environment -> {summary, alert, teams}"]
    for env, lists in recipients.items():
        for key in RECIPIENT_LISTS:
            value = (lists or {}).get(key) if isinstance(lists, dict) else None
            if not isinstance(value, list) or not all(isinstance(a, str) and "@" in a for a in value):
                errors.append(f"orchestrator.notify.recipients: {env}.{key} must be a list of email addresses")
    return errors
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `cd F && python -m pytest deploy/test_notify_core.py -q`
Expected: 7 passed.

- [ ] **Step 5: Commit**

```bash
git add deploy/notify_core.py deploy/test_notify_core.py
git commit -m "notify_core: run/crash notification messages and Graph sendMail body"
```

---

### Task 3: Notify config in the DAG and its validation

**Files:** Modify `deploy/dag_config.py` (`_check_orchestrator`), `deploy/dp_refresh_dag.json` (`orchestrator`), `deploy/test_dag_config.py`.

- [ ] **Step 1: Write the failing test.** `deploy/test_dag_config.py` validates through `check(config, notebooks, reports)`, with fixtures `base()` and `GOOD_SETTINGS`.
  - First add a valid block to `GOOD_SETTINGS`, so the existing `test_orchestrator_settings_valid` keeps passing:
```python
    "notify": {"tenantId": "t", "clientId": "c", "keyVaultUri": "https://kv.vault.azure.net/", "secretName": "s",
               "sender": "dp-refresh@x.com",
               "recipients": {"Dev": {"summary": ["a@x.com"], "alert": ["a@x.com"], "teams": ["c@x.teams.ms"]}}},
```
  - Then append:
```python
def test_orchestrator_notify_is_validated():
    config, notebooks, reports = base()
    config["orchestrator"] = dict(GOOD_SETTINGS, notify=dict(GOOD_SETTINGS["notify"], sender="nope"))
    assert any("sender" in e for e in check(config, notebooks, reports))
    config["orchestrator"] = {k: v for k, v in GOOD_SETTINGS.items() if k != "notify"}
    assert any("notify" in e for e in check(config, notebooks, reports))
```

- [ ] **Step 2: Run it and confirm it fails.**
- [ ] **Step 3: Implement.** In `deploy/dag_config.py`, add `from notify_core import check_notify` beside the other imports, and at the end of `_check_orchestrator` before `return errors`:

```python
    errors += check_notify(settings.get("notify"))
```
In `deploy/dp_refresh_dag.json`, add under `orchestrator` (after `modelRefreshParallelism`, same 2-space JSON style). The values come from Task 1, Step 8; `<TEAMS_CHANNEL_EMAIL>` is the address Brian pasted:

```json
    "notify": {
      "tenantId": "8a02a2b8-0092-4de5-8f76-4700d099feb1",
      "clientId": "9adca971-f328-4d79-9b48-713c298a238c",
      "keyVaultUri": "https://kv-spi-dataplatform.vault.azure.net/",
      "secretName": "dp-refresh-notify-client-secret",
      "sender": "dp-refresh@spitractor.com",
      "recipients": {
        "Dev": {"summary": ["bfox@spitractor.com"], "alert": ["bfox@spitractor.com"], "teams": ["<TEAMS_CHANNEL_EMAIL>"]},
        "Prod": {"summary": ["bfox@spitractor.com"], "alert": ["bfox@spitractor.com"], "teams": ["<TEAMS_CHANNEL_EMAIL>"]}
      }
    }
```
- [ ] **Step 4: Run the tests and check.** Run: `cd F && python -m pytest deploy -q && python deploy/dag_check.py`. Expected: all pass; `OK`.
- [ ] **Step 5: Commit**

```bash
git add deploy/dag_config.py deploy/dp_refresh_dag.json deploy/test_dag_config.py
git commit -m "DAG config: per-environment refresh notification settings, validated"
```

---

### Task 4: Send from the notebooks (Gold orchestrator + Notify_DP_Refresh)

**Files:**
- Create `deploy/notify_send.py` and `deploy/notify_glue.py`.
- Modify `deploy/orchestrator_glue.py` (two places), `deploy/render_orchestrator.py` and `deploy/test_render_orchestrator.py`.
- Then render.

- [ ] **Step 1: `deploy/notify_send.py`** (Fabric-only; `notebookutils` and `requests` exist in the Fabric runtime)

```python
# deploy/notify_send.py
# Fabric-only: send notify_core messages through Microsoft Graph as SPN-Fabric-Refresh-Automation.
# The client secret is read from Key Vault as the identity running the pipeline.
import requests


def send_notifications(messages: list, notify: dict) -> list:
    """Send each message; return a list of error strings (empty when everything was accepted)."""
    if not messages:
        return []
    try:
        secret = notebookutils.credentials.getSecret(notify["keyVaultUri"], notify["secretName"])
        tok = requests.post(f"https://login.microsoftonline.com/{notify['tenantId']}/oauth2/v2.0/token",
                            data={"grant_type": "client_credentials", "client_id": notify["clientId"],
                                  "client_secret": secret, "scope": "https://graph.microsoft.com/.default"},
                            timeout=60)
        if not tok.ok:
            return [f"token request failed: HTTP {tok.status_code} {tok.text[:500]}"]
        headers = {"Authorization": f"Bearer {tok.json()['access_token']}"}
    except Exception as ex:
        return [f"could not get a Graph token: {type(ex).__name__}: {str(ex)[:500]}"]
    errors = []
    for m in messages:
        r = requests.post(f"https://graph.microsoft.com/v1.0/users/{notify['sender']}/sendMail",
                          json=graph_mail(m), headers=headers, timeout=60)
        if r.status_code != 202:
            errors.append(f"sendMail to {m['to']} failed: HTTP {r.status_code} {r.text[:500]}")
    return errors
```

- [ ] **Step 2: Gold sends, and add a crash drill.** In `deploy/orchestrator_glue.py`:

(a) In the `# ---- run ----` normalisation block (after `simulate_bronze_failure = simulate_bronze_failure or "false"`), add:
```python
simulate_crash = simulate_crash or "false"
if str(simulate_crash).lower() == "true":
    raise RuntimeError("simulate_crash drill: Run_DP_Refresh failed on purpose before reporting")
```
This sits **outside** the main `try`, so the notebook activity fails, which is the crash path.

(b) At the very end of the file (after the `if LOG_PATH and not DRY:` block), add:
```python
# ---------------------------------------------------------------- notify -----------------------------
# Gold sends the run's notifications (summary always; alert + Teams per compose_summary's flags).
# A failed send fails this notebook on purpose (exit cell), so the pipeline's crash path still tells someone.
summary["notify_errors"] = []
if TIER == "gold":
    try:
        notify = (SETTINGS or {}).get("notify")
        if not notify:
            raise RuntimeError("orchestrator.notify missing from Files/config/dp_refresh_dag.json")
        summary["notify_errors"] = send_notifications(notify_messages(summary, notify, ENV), notify)
    except Exception as ex:
        summary["notify_errors"] = [f"{type(ex).__name__}: {str(ex)[:500]}"]
```

- [ ] **Step 3: `deploy/notify_glue.py`** (the body of `Notify_DP_Refresh`; parameters `tier`, `error_message`, `run_id`)

```python
# deploy/notify_glue.py
# Fabric-only body of Notify_DP_Refresh: the pipeline runs it when Run_DP_Refresh (Silver or Gold) crashes
# before it could report. Reads orchestrator.notify from this lakehouse's Files/config/dp_refresh_dag.json.
import json

ENV = notebookutils.runtime.context.get("currentWorkspaceName").rsplit(" - ", 1)[1]
CONFIG = json.loads(notebookutils.fs.head("Files/config/dp_refresh_dag.json", 20_000_000))
NOTIFY = CONFIG["orchestrator"]["notify"]
crash = crash_summary(ENV, tier or "Unknown", error_message or "(no error message)", run_id or "")
errors = send_notifications(notify_messages(crash, NOTIFY, ENV), NOTIFY)
print(crash["subject"])
if errors:
    raise RuntimeError("Notify_DP_Refresh could not send: " + " | ".join(errors))
print("sent", len(notify_messages(crash, NOTIFY, ENV)), "message(s)")
```

- [ ] **Step 4: Renderer.** In `deploy/render_orchestrator.py`:
  1. Add `simulate_crash = "false"` to `PARAMETERS`.
  2. In `render(target)`, insert `notify_core.py` and `notify_send.py` between core and glue: `for code in (core, notify_core, notify_send, glue, exit_cell):`.
  3. Replace `EXIT_CELL` with:
```python
EXIT_CELL = '''import json

if summary.get("notify_errors"):
    # Nobody was told about this run: fail the activity so the pipeline's crash path (Notify_DP_Refresh) runs
    # and the run shows as Failed in the Fabric Monitor.
    raise RuntimeError("DP refresh notifications could not be sent: " + " | ".join(summary["notify_errors"]))
try:
    exit_value = json.dumps(summary, default=str)
except Exception as ex:
    exit_value = json.dumps({
        "status": "error", "subject": "DP Refresh FAILED - orchestrator could not serialise its summary",
        "html": f"<p>DP Refresh FAILED - orchestrator could not serialise its summary: {type(ex).__name__}</p>",
        "teams_text": "DP Refresh FAILED - orchestrator could not serialise its summary",
        "alert_email": True, "teams": True, "error": f"{type(ex).__name__}: {str(ex)[:300]}"})
notebookutils.notebook.exit(exit_value)
'''
```
  4. Add a second render target for `Notify_DP_Refresh`:
     - path `workspaces/DP - Presentation - Dev/Orchestration/Notify_DP_Refresh.Notebook`, with the DP_Presentation lakehouse and workspace IDs from the Presentation target;
     - its own `PARAMETERS` (`tier = ""`, `error_message = ""`, `run_id = ""`) and a `MARKDOWN` header saying it is GENERATED;
     - cells: `notify_core.py`, `notify_send.py`, `notify_glue.py`;
     - `.platform` displayName `Notify_DP_Refresh`, created with a new logicalId only if missing.

     Keep the change small: generalise `render()` to take a target dict that names its parameters, markdown and code files, so both notebook kinds share one code path.
  5. Update `deploy/test_render_orchestrator.py` so its staleness check covers all three rendered notebooks (read it first and follow its pattern).
- [ ] **Step 5: Render and test.** Run: `cd F && python deploy/render_orchestrator.py && python -m pytest deploy -q && python deploy/dag_check.py`.
  - Expected: three notebooks rendered; all tests pass; `OK`.
  - If `dag_check` reports `Notify_DP_Refresh` as unregistered, add it to `excluded` in `dp_refresh_dag.json` with `{"name": "Notify_DP_Refresh", "reason": "notifier", "workspace": "presentation"}`.
- [ ] **Step 6: Commit**

```bash
git add deploy/notify_send.py deploy/notify_glue.py deploy/orchestrator_glue.py deploy/render_orchestrator.py deploy/test_render_orchestrator.py deploy/dp_refresh_dag.json "workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook" "workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook" "workspaces/DP - Presentation - Dev/Orchestration/Notify_DP_Refresh.Notebook"
git commit -m "Refresh notifications sent from the notebooks via Graph; Notify_DP_Refresh crash notifier; simulate_crash drill"
```

---

### Task 5: Notebook-only pipeline + Prod scope

**Files:**
- Modify `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json`.
- Modify `deploy/prod_scope.py` and `deploy/test_prod_scope.py`.

- [ ] **Step 1: Rewrite the pipeline activities** with a small one-off Python script, so the JSON stays well-formed; don't commit the script. Read the file, then:
  1. **Delete** these activities: `Email_Summary`, `If_Alert_Email`, `If_Teams`, `Email_Silver_Crashed`, `Email_Gold_Crashed`, `Teams_Silver_Crashed`, `Teams_Gold_Crashed`.
  2. **Add the `simulate_crash` pipeline parameter** (`{"type": "string", "defaultValue": "false"}`) and pass it to **Run_Silver only**, in the same shape as the existing `simulate_bronze_failure` parameter.
  3. **Add two activities**, `Notify_Silver_Crashed` (dependsOn `Run_Silver` `Failed`) and `Notify_Gold_Crashed` (dependsOn `Run_Gold` `Failed`):
     - type `TridentNotebook`;
     - typeProperties `{"notebookId": "<logicalId from Notify_DP_Refresh.Notebook/.platform>", "workspaceId": "00000000-0000-0000-0000-000000000000", "parameters": {...}}`;
     - parameters `tier` = `"Silver"` / `"Gold"` (string), `error_message` = expression `@activity('Run_Silver').error.message` / `@activity('Run_Gold').error.message`, `run_id` = expression `@pipeline().RunId`, each in the same `{"value": {"value": ..., "type": "Expression"}, "type": "string"}` shape the Run_* activities use (a plain string value for `tier`);
     - policy `{"timeout": "0.00:15:00", "retry": 1, "retryIntervalInSeconds": 60, "secureInput": false, "secureOutput": false}`.

  Within one workspace, Fabric Git sync and fabric-cicd both resolve a notebook referenced by its **logicalId**; the existing `Run_Gold` reference works this way.
- [ ] **Step 2: Check the result.**
```bash
cd F && python - <<'EOF'
import json
p = "workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json"
d = json.load(open(p, encoding="utf-8"))
acts = d["properties"]["activities"]
print([(a["name"], a["type"]) for a in acts])
assert {a["type"] for a in acts} == {"TridentNotebook"}, "only notebook activities may remain"
assert "connection" not in json.dumps(d), "no connection references may remain"
print("params:", list(d["properties"]["parameters"]))
EOF
```
Expected: `Run_Silver`, `Run_Gold`, `Notify_Silver_Crashed`, `Notify_Gold_Crashed`, all `TridentNotebook`; the params include `simulate_crash`.
- [ ] **Step 3: Prod scope.** In `deploy/prod_scope.py`, add `("presentation", "Notebook", "Notify_DP_Refresh")` to `ALWAYS`. In `deploy/test_prod_scope.py`, create a `Notify_DP_Refresh` notebook folder in every test that builds the always-deployed items, and include it in the expected presentation list. Real-repo counts become `{'staging': 36, 'presentation': 72}`.
- [ ] **Step 4: Run the tests and the real-repo count.** `cd F && python -m pytest deploy -q && python deploy/dag_check.py`, plus the real-repo `prod_items` count. Expected: pass; `OK`; 36/72.
- [ ] **Step 5: Commit**

```bash
git add "workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json" deploy/prod_scope.py deploy/test_prod_scope.py
git commit -m "Pipeline_DP_Refresh: notebook activities only (notifications moved to notebooks); deploy Notify_DP_Refresh"
```

---

### Task 6: Dev deploy and drills (controller + Brian checks his inbox and Teams)

**Files:** none.

- [ ] **Step 1: Push, wait for CI, and sync both DP Dev workspaces.**
```bash
git push origin dev
python D/tools/dp-migration/wait_ci.py
python D/tools/dp-migration/git_sync.py ab15d64d-c7ba-415d-9bcf-7feb1ef9b201
python D/tools/dp-migration/git_sync.py 73fd5443-240e-410a-990a-98827f32c087
```
CI's `deploy-dev` job writes the new `dp_refresh_dag.json`, including `notify`, to both Dev lakehouses. Expected: CI succeeds; both syncs complete. If a sync refuses because of a both-sides conflict on DP_Presentation or a notebook, check the content as in earlier sessions; if it matches, resolve with PreferRemote.
- [ ] **Step 2: Check the Dev pipeline resolved the notifier.** Export the Dev `Pipeline_DP_Refresh` definition. The `Notify_*` activities' `notebookId` should equal the Dev `Notify_DP_Refresh` item's ID, or its logicalId, which Fabric resolves. Then run Step 3 to prove it end to end.
- [ ] **Step 3: Drill 1, the summary email.** Run Dev `Pipeline_DP_Refresh` with `mode=all, dry_run=true`. Expected: the run Completes, and Brian gets **one** email from **dp-refresh@spitractor.com**, subject `🧪 [Dev] DP Refresh dry run (all)`. No Teams post.
- [ ] **Step 4: Drill 2, alert plus Teams.** Run it with `mode=all, dry_run=true, simulate_bronze_failure=true`. Expected: a summary email, a **high-importance** alert email, and a Teams channel post, all with subject `🔴 [Dev] DP Refresh FAILED – JD Bronze problem, nothing refreshed`. If `dry_run` short-circuits the Bronze check, drop `dry_run` and use `mode=items` with `items=Build_Gold_DateTable` to keep the run tiny.
- [ ] **Step 5: Drill 3, crash.** Run it with `mode=all, dry_run=true, simulate_crash=true`. Expected:
  - the run shows **Failed** (Run_Silver failed);
  - `Notify_Silver_Crashed` succeeds;
  - Brian gets the alert email and a Teams post `🔴 [Dev] DP Refresh FAILED – Silver orchestrator crashed`, with the "simulate_crash drill" error text.
- [ ] **Step 6: If a drill sends nothing,** read the activity output.
  - **Gold notebook failed with "notifications could not be sent":** the error names the cause.
    - Key Vault 403 → Task 1, Step 4.
    - Token 401 → the secret value or client ID.
    - sendMail 403 → the Exchange RBAC scope (Task 1, Step 6; allow up to an hour to apply).
  - Fix the cause and re-run the drill.

---

### Task 7: Prod deploy, then continue the Prod-tier plan

**Files:** Modify `D/docs/superpowers/plans/2026-10-02-dp-prod-tier-buildout.md` (amend Task 10).

- [ ] **Step 1: Merge to main.** Open the PR `dev` → `main` with `deploy/merge_preview.py` output in the body; Brian merges it with **Create a merge commit**. Then fast-forward `dev` to `main` (`git merge --ff-only origin/main && git push origin dev`).
- [ ] **Step 2: Brian runs the Prod deploy.** GitHub → Actions → **Deploy DP backend** → Run workflow on `main`. Expected log:
  - "Deployed 36 items to the prod staging workspace";
  - "Deployed 72 items to the prod presentation workspace (Staging orchestrator f7e553a7-… -> a1ec85cb-…)";
  - the config written.
- [ ] **Step 3: Continue the Prod-tier plan at Task 9, Steps 3–4** (item counts and ID-swap checks; Presentation now shows 71 notebooks: 69 Gold, the orchestrator and Notify).
- [ ] **Step 4: Amend the Prod-tier plan's Task 10** to reflect what we learned on 2026-10-05: Fabric rejects a shortcut whose target doesn't exist yet. The first Prod run is therefore:
  1. `mode=items` with every Staging item (the 30 Silver notebooks and 5 dataflows);
  2. `python deploy/sync_shortcuts.py --apply` (creates the remaining 29 Presentation shortcuts);
  3. the snapshot-history copy;
  4. `mode=all`.

  Also note that the Prod run sends its notifications as `[Prod]` from dp-refresh@spitractor.com.
- [ ] **Step 5: Update the operations guide and memory.**
  - `F/OPERATIONS-GUIDE.md`: notifications now come from dp-refresh@ via Graph. The client secret expires in 12 months: rotate it by creating a new client secret and updating the Key Vault secret, setting a reminder. Recipients live in `dp_refresh_dag.json`.
  - Memory: `project_dp_refresh_redesign`.

---

## Out of scope
- Running the refresh as the service principal: the SPN plan. This plan already gives the SPN Key Vault read access and a Mail.Send scope, which that plan reuses.
- Adaptive-card formatting in Teams: channel email is plain HTML.
