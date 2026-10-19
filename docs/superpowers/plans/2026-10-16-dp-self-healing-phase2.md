# DP self-healing, phase 2 (claim marker, skip unchanged pipelines, claim task on Brian's PC) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spec rollout steps 3–4 (`docs/superpowers/specs/2026-10-16-dp-self-healing-refresh-design.md`, 0b + 2a).
After a Prod backend deploy, nobody has to remember the claim:
- the deploy only re-publishes a pipeline whose content changed, and marks it `claimed:no`;
- a scheduled task on Brian's PC claims marked pipelines within 15 minutes, as Brian, and re-runs anything that
  failed in between;
- if a run still starts unclaimed, its summary email says so.

**Decisions already made:**
- **Workspace Identity is not available** on the Dataflow activity (0c, Brian, 2026-10-16), so dataflows keep
  running as the pipeline's last modifier.
- **The fixer is a scheduled task on Brian's PC** (Brian, 2026-10-16), not a Power Automate flow.

**Architecture:**
- **Marker module:** a pure `deploy/pipeline_marker.py` builds and parses a marker at the end of each Prod
  pipeline's description: `… | deploy:<utc> run:<id> hash:<sha12> | claimed:no|<utc>`.
- **Deploy:** `deploy_backend.py` hashes each pipeline's source plus its Dev→Prod ID swaps. It publishes only the
  pipelines whose hash differs from the Prod marker, then writes `claimed:no`.
- **Claim script:** `claim_prod_pipeline.py` keeps the marker and sets `claimed:<utc>`.
- **Claim task:** a new `deploy/claim_task.py`, run every 15 min by Task Scheduler as Brian, claims what's
  unclaimed and re-runs work that ran unclaimed. Its decisions are pure functions; the REST calls go through
  `fab api`, as Brian.
- **Finish warning:** `Run_DP_Refresh`'s Finish phase reads the marker and adds a warning when it says
  `claimed:no`.

**Tech Stack:** Python 3, pytest, fabric-cicd 1.3.0 (CI), `fab` CLI (Brian's PC), Windows Task Scheduler
(PowerShell 7 `Register-ScheduledTask`), Fabric REST (items, job instances).

**Repo:** all code tasks are in **fabric-workspace-docs** (`C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`,
branch `dev`). Stage only named files. Task 8 updates the spec in data-projects.

**Later (phase 3, its own plan):**
- 2b `catchup` mode, started by the watchdogs when a gateway comes back;
- 2c retry for `capacity`;
- 2d the planned-maintenance helper.

---

## File map

| File | Change |
|---|---|
| `deploy/pipeline_marker.py` | **new.** `BASE_DESCRIPTIONS`, `pipeline_hash`, `marker_description`, `parse_marker`, `claimed_description`, `UNCLAIMED` |
| `deploy/test_pipeline_marker.py` | **new** |
| `deploy/deploy_backend.py` | hash + skip unchanged pipelines; write the marker after publishing; step-summary line |
| `deploy/test_deploy_backend.py` | tests for the skip decision |
| `deploy/claim_prod_pipeline.py` | keep the marker; `claim(names)` reusable; descriptions from `pipeline_marker` |
| `deploy/test_claim_prod_pipeline.py` | marker kept, claimed set |
| `deploy/claim_task.py` | **new.** Decisions (pure) + `main()` (fab api) |
| `deploy/test_claim_task.py` | **new** |
| `deploy/install_claim_task.ps1` | **new.** Registers "DP Claim Prod Pipelines" |
| `deploy/orchestrator_core.py` / `deploy/test_orchestrator_core.py` | `claim_warning(description)` |
| `deploy/orchestrator_glue.py` | Finish (Prod only): read own pipeline's description → warning |
| `.github/workflows/deploy.yml` | reminder text: the claim task does it; manual fallback |
| `OPERATIONS-GUIDE.md`, `docs/TROUBLESHOOTING.md` | release step + Identity + claim task section; row update |
| rendered `Run_DP_Refresh` notebooks (both) | `python deploy/render_orchestrator.py` |

---

### Task 1: `pipeline_marker.py`

**Files:** Create `deploy/pipeline_marker.py`, `deploy/test_pipeline_marker.py`.

- [ ] **Step 1: Failing tests**

```python
# deploy/test_pipeline_marker.py
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from pipeline_marker import (BASE_DESCRIPTIONS, UNCLAIMED, claimed_description, marker_description,  # noqa: E402
                             parse_marker, pipeline_hash)

T = datetime(2026, 10, 16, 18, 21, 13, tzinfo=timezone.utc)


def test_hash_changes_with_content_rules_and_parameters():
    h = pipeline_hash('{"a": 1}', [("dev1", "prod1")], "param")
    assert len(h) == 12
    assert h == pipeline_hash('{ "a" : 1 }', [("dev1", "prod1")], "param")    # JSON formatting doesn't matter
    assert h != pipeline_hash('{"a": 2}', [("dev1", "prod1")], "param")
    assert h != pipeline_hash('{"a": 1}', [("dev1", "prod2")], "param")
    assert h != pipeline_hash('{"a": 1}', [("dev1", "prod1")], "param2")
    assert h == pipeline_hash('{"a": 1}', [("dev1", "prod1")], "param".replace("\n", "\r\n"))


def test_marker_round_trip_and_claim():
    d = marker_description("Pipeline_DP_Refresh", T, "389466", "abc123def456")
    assert d.startswith(BASE_DESCRIPTIONS["Pipeline_DP_Refresh"]) and d.endswith(UNCLAIMED)
    m = parse_marker(d)
    assert m == {"deploy": "2026-10-16T18:21Z", "run": "389466", "hash": "abc123def456", "claimed": "no"}
    c = claimed_description(d, datetime(2026, 10, 16, 18, 25, tzinfo=timezone.utc))
    assert parse_marker(c) == {**m, "claimed": "2026-10-16T18:25Z"}
    assert c.startswith(BASE_DESCRIPTIONS["Pipeline_DP_Refresh"])


def test_parse_marker_of_old_or_empty_description():
    assert parse_marker("") == {}
    assert parse_marker(None) == {}
    assert parse_marker("DP refresh orchestrator (Prod). Its dataflows run as the last modifier") == {}


def test_claimed_description_without_marker_keeps_text_and_adds_claim():
    c = claimed_description("Old text", T)
    assert c.startswith("Old text") and parse_marker(c) == {"claimed": "2026-10-16T18:21Z"}


def test_descriptions_fit_fabric_limit():
    # Fabric item descriptions are limited to 256 characters
    for name in BASE_DESCRIPTIONS:
        d = claimed_description(marker_description(name, T, "38946677081", "abc123def456"), T)
        assert len(d) <= 256, (name, len(d))
```

- [ ] **Step 2:** `python -m pytest deploy/test_pipeline_marker.py -q` → ModuleNotFoundError.

- [ ] **Step 3: Implement**

```python
# deploy/pipeline_marker.py
"""The claim marker on the Prod pipelines' descriptions.

A pipeline's Dataflow activities run as its LAST MODIFIER, and Dataflow Gen2 refuses service principals, so after
the CI deploy saves a pipeline it must be re-saved as Brian ("claimed"). The deploy writes
"<base> | deploy:<utc> run:<github run id> hash:<sha12> | claimed:no"; claim_prod_pipeline.py rewrites the last
part to "claimed:<utc>". The hash lets the next deploy skip a pipeline whose content hasn't changed, so it stays
claimed. Spec: data-projects/docs/superpowers/specs/2026-10-16-dp-self-healing-refresh-design.md (0b, 2a)
"""
import hashlib
import json
import re

BASE_DESCRIPTIONS = {
    "Pipeline_DP_Refresh": "DP refresh orchestrator (Prod). Dataflows run as the last modifier; "
                           "deploy/claim_task.py claims it after a deploy.",
    "Pipeline_PartsAvailability": "Hourly Parts Availability load (Prod). Its dataflow runs as the last "
                                  "modifier; deploy/claim_task.py claims it after a deploy.",
}
UNCLAIMED = "claimed:no"
_MARK = re.compile(r"\| deploy:(?P<deploy>\S+) run:(?P<run>\S+) hash:(?P<hash>[0-9a-f]+)")
_CLAIM = re.compile(r"\| claimed:(?P<claimed>\S+)\s*$")


def _utc(t) -> str:
    return t.strftime("%Y-%m-%dT%H:%MZ")


def pipeline_hash(content_text: str, swap_rules, parameter_text: str) -> str:
    """12 hex chars over the pipeline JSON (parsed, so formatting doesn't count), the Dev->Prod ID swaps and
    parameter.yml (line endings normalised)."""
    payload = json.dumps({"content": json.loads(content_text), "swaps": sorted(map(list, swap_rules)),
                          "parameters": parameter_text.replace("\r\n", "\n")}, sort_keys=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:12]


def marker_description(name: str, deployed_utc, run_id: str, h: str) -> str:
    """Description the deploy writes after publishing pipeline `name` (aware UTC datetime)."""
    return f"{BASE_DESCRIPTIONS[name]} | deploy:{_utc(deployed_utc)} run:{run_id or 'local'} hash:{h} | {UNCLAIMED}"


def parse_marker(description) -> dict:
    """{"deploy", "run", "hash", "claimed"} parts found in a description ({} when there's no marker)."""
    out = {}
    m = _MARK.search(description or "")
    if m:
        out.update(m.groupdict())
    c = _CLAIM.search(description or "")
    if c:
        out.update(c.groupdict())
    return out


def claimed_description(description, claimed_utc) -> str:
    """The description with its claim part set to claimed_utc (added when missing); everything else kept."""
    text = _CLAIM.sub("", description or "").rstrip()
    return f"{text} | claimed:{_utc(claimed_utc)}"
```

- [ ] **Step 4:** run → 5 passed. If `test_descriptions_fit_fabric_limit` fails, shorten the base texts (keep
  "last modifier" and "claim_task.py" in them).
- [ ] **Step 5: Commit**: `git add deploy/pipeline_marker.py deploy/test_pipeline_marker.py` → "pipeline_marker:
  claim marker on the Prod pipelines' descriptions".

---

### Task 2: `claim_prod_pipeline.py` keeps the marker

**Files:** Modify `deploy/claim_prod_pipeline.py`, `deploy/test_claim_prod_pipeline.py`.

Current behaviour: PATCHes a fixed description (`DESCRIPTIONS[name]`) onto both pipelines. New behaviour: read each
pipeline's current description, write `claimed_description(current, now)`. The manual command still claims both.

- [ ] **Step 1: Failing test** (replace `test_claims_both_dataflow_pipelines`; keep the `pipeline_ids` test)

```python
from datetime import datetime, timezone

from claim_prod_pipeline import PIPELINES, new_description, pipeline_ids  # noqa: E402
from pipeline_marker import marker_description, parse_marker  # noqa: E402


def test_claims_both_dataflow_pipelines():
    assert set(PIPELINES) == {"Pipeline_DP_Refresh", "Pipeline_PartsAvailability"}


def test_new_description_keeps_the_deploy_marker():
    t = datetime(2026, 10, 16, 18, 21, tzinfo=timezone.utc)
    current = marker_description("Pipeline_DP_Refresh", t, "1", "abc123def456")
    m = parse_marker(new_description("Pipeline_DP_Refresh", current, datetime(2026, 10, 16, 18, 30, tzinfo=timezone.utc)))
    assert m["hash"] == "abc123def456" and m["claimed"] == "2026-10-16T18:30Z"


def test_new_description_for_a_pipeline_without_marker_uses_the_base_text():
    d = new_description("Pipeline_PartsAvailability", "", datetime(2026, 10, 16, 18, 30, tzinfo=timezone.utc))
    assert d.startswith("Hourly Parts Availability load (Prod).") and parse_marker(d)["claimed"] == "2026-10-16T18:30Z"
```

- [ ] **Step 2:** run `python -m pytest deploy/test_claim_prod_pipeline.py -q` → ImportError.
- [ ] **Step 3: Implement.** Replace the module body below the docstring (update the docstring's last paragraph to
  "Re-claiming = PATCHing each pipeline's description as yourself, keeping the deploy's marker
  (pipeline_marker.py) and setting claimed:<utc>. deploy/claim_task.py runs this automatically on Brian's PC."):

```python
import sys
from datetime import datetime, timezone

from pipeline_marker import BASE_DESCRIPTIONS, claimed_description
from sync_shortcuts import fab_api

PROD_PRESENTATION_WS = "7836042d-adb1-4846-b70d-bd42980054c5"
PIPELINES = tuple(BASE_DESCRIPTIONS)


def pipeline_ids(items: list, names) -> tuple:
    """({name: id} for names found exactly once, [problems]) from a workspace's DataPipeline items."""
    found, problems = {}, []
    for name in names:
        ids = [i["id"] for i in items if i.get("displayName") == name]
        if len(ids) == 1:
            found[name] = ids[0]
        else:
            problems.append(f"expected one {name} in the Prod Presentation workspace, found {len(ids)}")
    return found, problems


def new_description(name: str, current: str, now_utc) -> str:
    """current with its claim set to now; a pipeline with no description yet gets its base text."""
    return claimed_description(current or BASE_DESCRIPTIONS[name], now_utc)


def list_pipelines() -> list:
    return fab_api(f"workspaces/{PROD_PRESENTATION_WS}/items?type=DataPipeline")["text"].get("value", [])


def claim(names) -> list:
    """Claim the named Prod pipelines as the signed-in fab user. Returns [problems] (empty = all claimed)."""
    items = list_pipelines()
    found, problems = pipeline_ids(items, names)
    current = {i["id"]: i.get("description") or "" for i in items}
    now = datetime.now(timezone.utc)
    for name, pid in found.items():
        res = fab_api(f"workspaces/{PROD_PRESENTATION_WS}/dataPipelines/{pid}", "patch",
                      {"description": new_description(name, current[pid], now)})
        if 200 <= res.get("status_code", 0) < 300:
            print(f"{name} ({pid}): claimed - its dataflows now run as you.")
        else:
            problems.append(f"{name}: PATCH failed: {res}")
    return problems


def main() -> int:
    problems = claim(PIPELINES)
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
```

  Check `fab api … items?type=DataPipeline` returns `description` in each item (it does today; the 10/16 listing
  showed it). `git grep -n "DESCRIPTIONS" deploy` must show no remaining users of the old name.
- [ ] **Step 4:** run → passes; then `python -m pytest deploy -q`.
- [ ] **Step 5: Commit** `deploy/claim_prod_pipeline.py deploy/test_claim_prod_pipeline.py` → "claim_prod_pipeline:
  keep the deploy marker, set claimed:<utc>; reusable claim()".

---

### Task 3: Deploy skips unchanged pipelines and writes the marker

**Files:** Modify `deploy/deploy_backend.py` (the prod branch of `main`, the pipeline part), `deploy/test_deploy_backend.py`.

Today (`deploy_backend.py` prod branch): `pipeline_stage = stage_items(REPO_ROOT, items["presentation"])`, append the
swap `rules` to its parameter.yml, `unmatched_swaps(pipeline_stage, rules)`, then
`deploy(..., item_type_in_scope=["DataPipeline"])`.

- [ ] **Step 1: Read** `deploy/test_deploy_backend.py` (it monkeypatches `deploy`, `find_item_id`, `stage_items`… —
  follow its existing fakes) and `lib.stage_items`/`params.append_rules`.
- [ ] **Step 2: Failing tests** for a pure helper:

```python
from deploy_backend import pipelines_to_publish  # noqa: E402


def test_pipelines_to_publish_skips_matching_hash():
    hashes = {"Pipeline_DP_Refresh": "aaa", "Pipeline_PartsAvailability": "bbb"}
    descriptions = {"Pipeline_DP_Refresh": "x | deploy:2026-10-16T18:21Z run:1 hash:aaa | claimed:2026-10-16T18:25Z",
                    "Pipeline_PartsAvailability": "old text without marker"}
    assert pipelines_to_publish(hashes, descriptions) == ["Pipeline_PartsAvailability"]


def test_pipelines_to_publish_new_pipeline_and_changed_hash():
    assert pipelines_to_publish({"P": "abc123"}, {}) == ["P"]
    # a real (hex) hash that differs, so the test exercises the comparison, not a failed parse
    assert pipelines_to_publish({"P": "abc123"}, {"P": "x | deploy:t run:1 hash:def456 | claimed:no"}) == ["P"]
    assert pipelines_to_publish({"P": "abc123"}, {"P": "x | deploy:t run:1 hash:abc123 | claimed:no"}) == []
```

  Plus one integration-style test in the file's existing style: with both hashes matching, the `DataPipeline`
  `deploy(...)` call is **not** made and no description PATCH happens; with one changed, `deploy` is called with a
  stage containing only that pipeline and the PATCH writes `marker_description(...)` for it.

- [ ] **Step 3: Implement.**
  - `pipelines_to_publish(hashes: dict, descriptions: dict) -> list`: sorted names whose
    `parse_marker(descriptions.get(name)).get("hash") != hashes[name]`.
  - **Hash input** per pipeline: its source `pipeline-content.json` text (from `REPO_ROOT`), **all** swap `rules`
    as `(dev_id, prod_id)`, and the repo's `parameter.yml` text.
  - **Descriptions:** a small helper `prod_pipeline_descriptions(ws) -> {name: description}` that lists
    `v1/workspaces/{ws}/items?type=DataPipeline` with the SPN token. Reuse the `requests` +
    `get_credential().get_token("https://api.fabric.microsoft.com/.default")` pattern from `fabric_ids.py`,
    including its continuationToken loop.
  - **Order matters:** run `unmatched_swaps` against the **full** pipeline stage (both pipelines) **before**
    filtering. Each pipeline only contains its own IDs, so checking a filtered stage would falsely report the other
    pipeline's IDs as unmatched.
  - **Stage only what changed:** stage only `items["presentation"]` entries that are not `.DataPipeline` folders, or
    are pipelines in `pipelines_to_publish`. If none changed, print "Pipelines unchanged (hash match): …; not
    re-published, they stay claimed." and skip the DataPipeline `deploy` call.
  - **After publishing:** PATCH `v1/workspaces/{ws}/items/{id}` with
    `{"description": marker_description(name, now_utc, os.environ.get("GITHUB_RUN_ID", ""), h)}` for each
    published pipeline. Use the `find_item_id` result for the id. Fail the deploy (raise) if a PATCH fails: an
    unmarked pipeline would never be claimed automatically.
  - **Step summary:** when `GITHUB_STEP_SUMMARY` is set, append one line per pipeline, "re-published → claim
    pending" or "unchanged → still claimed".
- [ ] **Step 4:** `python -m pytest deploy -q` → all pass.
- [ ] **Step 5: Commit** `deploy/deploy_backend.py deploy/test_deploy_backend.py` → "Prod deploy: re-publish only
  changed pipelines (hash in the description marker); mark published ones claimed:no".

---

### Task 4: Claim task decisions (pure) and `main()`

**Files:** Create `deploy/claim_task.py`, `deploy/test_claim_task.py`.

Runs every 15 min on Brian's PC as Brian. For each Prod pipeline whose marker says `claimed:no`:
1. claim it (`claim_prod_pipeline.claim`);
2. if the pipeline ran between the deploy and now, re-run what that run missed:
   - `Pipeline_DP_Refresh`: start `mode=rerun_failed`. That mode reruns the previous run's Failed/Skipped items;
     with nothing to rerun it says so. Skip if a run is InProgress or NotStarted.
   - `Pipeline_PartsAvailability`: if an instance since the deploy **Failed**, start one run, but only inside load
     hours (weekdays 06:50–16:50 Central) and only if none is running. Outside those hours the next scheduled load
     covers it.

- [ ] **Step 1: Failing tests**

```python
# deploy/test_claim_task.py
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from claim_task import rerun_action, unclaimed  # noqa: E402

DEPLOY = "2026-10-16T18:21Z"


def inst(start, status):
    return {"startTimeUtc": start, "status": status}


def test_unclaimed_reads_markers():
    descs = {"Pipeline_DP_Refresh": f"x | deploy:{DEPLOY} run:1 hash:aaa | claimed:no",
             "Pipeline_PartsAvailability": f"y | deploy:{DEPLOY} run:1 hash:bbb | claimed:2026-10-16T18:25Z"}
    assert unclaimed(descs) == {"Pipeline_DP_Refresh": DEPLOY}
    assert unclaimed({"Pipeline_DP_Refresh": "no marker"}) == {}


def test_dp_rerun_only_when_it_ran_after_the_deploy():
    now = datetime(2026, 10, 17, 11, 30, tzinfo=timezone.utc)   # 06:30 Central, Friday
    ran = [inst("2026-10-17T11:15:00.12Z", "Completed")]
    assert rerun_action("Pipeline_DP_Refresh", DEPLOY, ran, now) == {"mode": "rerun_failed"}
    assert rerun_action("Pipeline_DP_Refresh", DEPLOY, [inst("2026-10-16T11:15:00Z", "Completed")], now) is None
    assert rerun_action("Pipeline_DP_Refresh", DEPLOY, [], now) is None
    running = ran + [inst("2026-10-17T11:20:00Z", "InProgress")]
    assert rerun_action("Pipeline_DP_Refresh", DEPLOY, running, now) is None


def test_parts_rerun_only_failed_and_inside_load_hours():
    failed = [inst("2026-10-16T18:50:00Z", "Failed")]
    inside = datetime(2026, 10, 16, 19, 5, tzinfo=timezone.utc)    # 14:05 Central, Friday
    after = datetime(2026, 10, 16, 22, 5, tzinfo=timezone.utc)     # 17:05 Central
    saturday = datetime(2026, 10, 17, 15, 0, tzinfo=timezone.utc)
    assert rerun_action("Pipeline_PartsAvailability", DEPLOY, failed, inside) == {}
    assert rerun_action("Pipeline_PartsAvailability", DEPLOY, failed, after) is None
    assert rerun_action("Pipeline_PartsAvailability", DEPLOY, failed, saturday) is None
    ok = [inst("2026-10-16T18:50:00Z", "Completed")]
    assert rerun_action("Pipeline_PartsAvailability", DEPLOY, ok, inside) is None
```

- [ ] **Step 2:** run → ModuleNotFoundError.
- [ ] **Step 3: Implement**

```python
# deploy/claim_task.py
"""Claim the Prod pipelines after a deploy, as Brian, and re-run what ran unclaimed (scheduled task on Brian's PC).

Task Scheduler runs this every 15 minutes (deploy/install_claim_task.ps1) under Brian's Windows account, so `fab api`
calls are made as Brian - the identity Dataflow Gen2 accepts. A pipeline needs claiming when its description marker
(pipeline_marker.py) says claimed:no, which the Prod deploy writes on every pipeline it re-publishes.
Log: %LOCALAPPDATA%\\DPClaimTask\\claim-YYYY-MM-DD.log. If Brian's fab sign-in has expired this logs and exits 1;
Run_DP_Refresh's Finish then warns in the summary email that the run started unclaimed.
Spec: data-projects/docs/superpowers/specs/2026-10-16-dp-self-healing-refresh-design.md (2a)
"""
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).parent))
from claim_prod_pipeline import PROD_PRESENTATION_WS, claim, list_pipelines  # noqa: E402
from pipeline_marker import UNCLAIMED, parse_marker  # noqa: E402
from sync_shortcuts import fab_api  # noqa: E402

CENTRAL = ZoneInfo("America/Chicago")
RUNNING = {"InProgress", "NotStarted"}


def _t(s: str) -> datetime:
    """'2026-10-16T18:21Z' or '2026-10-16T18:21:00.123Z' as aware UTC."""
    s = s.rstrip("Z")
    s = s.split(".")[0]
    fmt = "%Y-%m-%dT%H:%M:%S" if s.count(":") == 2 else "%Y-%m-%dT%H:%M"
    return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)


def unclaimed(descriptions: dict) -> dict:
    """{name: deploy time} for pipelines whose marker says claimed:no."""
    out = {}
    for name, d in descriptions.items():
        m = parse_marker(d)
        if m.get("claimed") == UNCLAIMED.split(":", 1)[1] and m.get("deploy"):
            out[name] = m["deploy"]
    return out


def in_parts_hours(now_utc: datetime) -> bool:
    local = now_utc.astimezone(CENTRAL)
    minutes = local.hour * 60 + local.minute
    return local.weekday() < 5 and 6 * 60 + 50 <= minutes <= 16 * 60 + 50


def rerun_action(name: str, deploy_utc: str, instances: list, now_utc: datetime):
    """Pipeline parameters for the one re-run to start ({} = no parameters), or None."""
    since = _t(deploy_utc)
    after = [i for i in instances if i.get("startTimeUtc") and _t(i["startTimeUtc"]) >= since]
    if not after or any(i.get("status") in RUNNING for i in instances):
        return None
    if name == "Pipeline_DP_Refresh":
        return {"mode": "rerun_failed"}
    if name == "Pipeline_PartsAvailability":
        return {} if any(i.get("status") == "Failed" for i in after) and in_parts_hours(now_utc) else None
    return None


def log(msg: str) -> None:
    folder = Path(os.environ.get("LOCALAPPDATA", ".")) / "DPClaimTask"
    folder.mkdir(parents=True, exist_ok=True)
    line = f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} {msg}"
    print(line)
    with open(folder / f"claim-{datetime.now():%Y-%m-%d}.log", "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main() -> int:
    try:
        items = list_pipelines()
    except Exception as ex:   # expired sign-in, network
        log(f"ERROR listing Prod pipelines (fab sign-in expired? run 'fab auth login'): {type(ex).__name__}: {ex}")
        return 1
    todo = unclaimed({i["displayName"]: i.get("description") for i in items})
    if not todo:
        log("nothing to claim")
        return 0
    problems = claim(list(todo))
    if problems:
        log("ERROR claiming: " + " | ".join(problems))
        return 1
    log("claimed: " + ", ".join(f"{n} (deployed {t})" for n, t in todo.items()))
    ids = {i["displayName"]: i["id"] for i in items}
    now = datetime.now(timezone.utc)
    for name, deployed in todo.items():
        res = fab_api(f"workspaces/{PROD_PRESENTATION_WS}/items/{ids[name]}/jobs/instances")
        action = rerun_action(name, deployed, res["text"].get("value", []), now)
        if action is None:
            continue
        body = {"executionData": {"parameters": action}} if action else None
        r = fab_api(f"workspaces/{PROD_PRESENTATION_WS}/items/{ids[name]}/jobs/instances?jobType=Pipeline",
                    "post", body)
        log(f"started {name} {action or ''}: HTTP {r.get('status_code')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

  Check `sync_shortcuts.fab_api`'s signature and return shape (`{"status_code", "text"}`; does it accept
  `body=None` for a POST?). Adapt the calls, not the decision functions. Check the job-instances list field names
  against one real response:
  `fab api "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items/aa2387ff-8689-4a63-a2eb-091eda148190/jobs/instances"`
  (expect `startTimeUtc`, `status`). Fix the test fixture if they differ.
- [ ] **Step 4:** run tests → pass; `python -m pytest deploy -q`.
- [ ] **Step 5: Commit** `deploy/claim_task.py deploy/test_claim_task.py` → "claim_task: claim Prod pipelines marked
  claimed:no and re-run what ran unclaimed (Brian's PC)".

---

### Task 5: Install script for the scheduled task

**Files:** Create `deploy/install_claim_task.ps1`.

- [ ] **Step 1: Write it**

```powershell
# deploy/install_claim_task.ps1
# Registers "\SPI\DP Claim Prod Pipelines" for the current user: every 15 minutes, 05:00-21:00 daily, runs
# deploy/claim_task.py with this repo's Python. Runs only while you're logged on (it uses your fab sign-in).
# Usage (PowerShell, as yourself, not admin):  .\deploy\install_claim_task.ps1      Remove: -Uninstall
param([switch]$Uninstall)
$ErrorActionPreference = "Stop"
$name = "DP Claim Prod Pipelines"
if ($Uninstall) { Unregister-ScheduledTask -TaskPath "\SPI\" -TaskName $name -Confirm:$false; return }
$python = (Get-Command python).Source
$script = Join-Path $PSScriptRoot "claim_task.py"
$action = New-ScheduledTaskAction -Execute $python -Argument "`"$script`"" -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Daily -At "05:00"
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At "05:00" -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration (New-TimeSpan -Hours 16)).Repetition
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
Register-ScheduledTask -TaskPath "\SPI\" -TaskName $name -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Force | Out-Null
Write-Host "Registered \SPI\$name ($python $script). Test now: Start-ScheduledTask -TaskPath '\SPI\' -TaskName '$name'"
Write-Host "Log: $env:LOCALAPPDATA\DPClaimTask\"
```

  If `(Get-Command python).Source` resolves to the `WindowsApps\python.exe` store stub, use the real interpreter
  (`py -3 -c "import sys; print(sys.executable)"`) instead. A task running the stub silently does nothing.
- [ ] **Step 2:** `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('deploy/install_claim_task.ps1',[ref]$null,[ref]$null) | Out-Null; 'ok'"` → `ok`. Don't run the installer (Brian does, Task 7).
- [ ] **Step 3: Commit** `deploy/install_claim_task.ps1` → "install_claim_task.ps1: register the claim task on Brian's PC".

---

### Task 6: Finish warns when the run started unclaimed

**Files:** `deploy/orchestrator_core.py`, `deploy/test_orchestrator_core.py`, `deploy/orchestrator_glue.py`, rendered notebooks.

- [ ] **Step 1: Failing test**

```python
def test_claim_warning():
    assert claim_warning("x | deploy:2026-10-16T18:21Z run:1 hash:abc | claimed:no").startswith(
        "Pipeline_DP_Refresh was not claimed after the 2026-10-16T18:21Z deploy")
    assert "claim_task" in claim_warning("x | deploy:2026-10-16T18:21Z run:1 hash:abc | claimed:no")
    assert claim_warning("x | deploy:2026-10-16T18:21Z run:1 hash:abc | claimed:2026-10-16T18:25Z") is None
    assert claim_warning("") is None and claim_warning(None) is None
```

- [ ] **Step 2: Implement** in `orchestrator_core.py` (near `freshness_warnings`):

```python
def claim_warning(description):
    """Warning text when this pipeline's description marker says it was never claimed after a deploy, else None."""
    m = re.search(r"\| deploy:(\S+) run:\S+ hash:\S+ \| claimed:no\s*$", description or "")
    if not m:
        return None
    return (f"Pipeline_DP_Refresh was not claimed after the {m.group(1)} deploy, so its dataflows ran as the deploy's "
            "service principal and fail with SPNBasedRefreshNotAllowed. The claim task on Brian's PC "
            "(deploy/claim_task.py) normally does this within 15 minutes: check its log, or run "
            "python deploy/claim_prod_pipeline.py.")
```

  In `orchestrator_glue.py`, in the gold **finish** branch after the upstream keys are copied (the
  `for key in ("items", "bronze_problems", …)` loop), add, guarded so it can never break the email:

```python
        if ENV == "Prod":
            try:
                _pipe = item_id("Pipeline_DP_Refresh", "DataPipeline", PRES_WS_ID)
                _w = claim_warning(rest_get(f"v1/workspaces/{PRES_WS_ID}/items/{_pipe}").get("description"))
                if _w:
                    summary["warnings"].append(_w)
            except Exception as ex:
                summary["warnings"].append(f"claim check could not run ({type(ex).__name__}: {str(ex)[:200]})")
```

  Confirm `summary["warnings"]` is a list at that point (it's copied from upstream; use
  `summary.setdefault("warnings", [])` if it may be missing).
- [ ] **Step 3:** `python deploy/render_orchestrator.py; python -m pytest deploy -q` → pass.
- [ ] **Step 4: Commit** the four files (core, test, glue, both rendered `Run_DP_Refresh` notebooks) → "Run_DP_Refresh
  Finish: warn when the Prod pipeline ran unclaimed".

---

### Task 7: Docs, workflow text, Dev check, release, install

- [ ] **Step 1: `.github/workflows/deploy.yml`.** Change the "ACTION NEEDED" step's `msg` and summary heading to:
  "Re-published pipelines are marked claimed:no. The claim task on Brian's PC (deploy/claim_task.py) claims them
  within 15 minutes. If it isn't installed or your PC is off, run 'python deploy/claim_prod_pipeline.py' before the
  next scheduled run." Keep it a `::warning`.
- [ ] **Step 2: OPERATIONS-GUIDE.md.**
  - **Release step 5:** "The claim task does it within 15 min (check `%LOCALAPPDATA%\DPClaimTask` or the pipelines'
    descriptions: `claimed:<time>`). Manual fallback: `python deploy/claim_prod_pipeline.py`."
  - **Identity section:** one line on the marker and the hash skip.
  - **New short section "Claim task (Brian's PC)":** install/uninstall, log location, what it does, and that it
    needs a valid `fab auth login`.
  - **TROUBLESHOOTING `SPNBasedRefreshNotAllowed` row:** point to the claim task log first.
- [ ] **Step 3:** `python -m pytest deploy -q`, `python deploy/dag_check.py`, `python deploy/hygiene_audit.py`; push
  `dev`; Git sync Dev (`git_sync.py` for both Dev workspaces). If the Presentation sync refuses on the known
  `Pipeline_PartsAvailability` re-serialisation conflict, export and compare the item first, as on 2026-10-16;
  accept Git only if the content is identical.
- [ ] **Step 4: Dry check against Prod, read-only:**
  `python -c "import sys; sys.path.insert(0,'deploy'); from claim_task import unclaimed; from claim_prod_pipeline import list_pipelines; print(unclaimed({i['displayName']: i.get('description') for i in list_pipelines()}))"`
  → `{}`. Today's descriptions have no marker yet.
- [ ] **Step 5: Release.** `merge_preview.py`, PR dev → main.
  1. Brian merges and runs **Deploy DP backend**. This first deploy re-publishes both pipelines (no hash yet) and
     marks them `claimed:no`.
  2. **Brian installs the task:** `cd C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs;
     .\deploy\install_claim_task.ps1`, then `Start-ScheduledTask -TaskPath '\SPI\' -TaskName 'DP Claim Prod
     Pipelines'`.
  3. **Verify:** the log shows "claimed: Pipeline_DP_Refresh …, Pipeline_PartsAvailability …", and both
     descriptions end `claimed:<time>`.
  4. Fast-forward `dev`.
- [ ] **Step 6: Second-deploy proof (next release with no pipeline change).** The deploy summary says "unchanged →
  still claimed", and no claim is needed.

### Task 8: Spec + memory

- [ ] Spec Progress: phase 2 live (PR number, date); 0c = not available; 2a = PC task (Power Automate not built).
  Open questions 1 and 2 answered.
- [ ] data-projects `CLAUDE.md` release step 4 and the Identity line: "the claim task on Brian's PC claims within 15
  min; manual fallback `claim_prod_pipeline.py`".
- [ ] Commit in data-projects.
