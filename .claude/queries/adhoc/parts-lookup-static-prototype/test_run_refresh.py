"""Offline tests of run_refresh.run_pipeline's branching (no network, no .env)."""

import json
import os
import sys
import types

import pytest


@pytest.fixture
def rr(tmp_path, monkeypatch):
    fake = types.ModuleType("config")
    for k, v in dict(TENANT_ID="t", CLIENT_ID="c", CLIENT_SECRET="secret", SITE_ID="s", DRIVE_ID="drive-1",
                     LIBRARY_BASE="b", TEAMS_WEBHOOK_URL=None, SOURCE="dp").items():
        setattr(fake, k, v)
    monkeypatch.setitem(sys.modules, "config", fake)
    monkeypatch.chdir(tmp_path)
    sys.modules.pop("run_refresh", None)
    import run_refresh
    return run_refresh


def install_steps(rr, monkeypatch, extracted_at="2026-10-14T11:50:00+00:00", fail=None):
    steps = []

    def fake_step(step):
        steps.append(step)
        if step == fail:
            return False
        if step == "extract.py" and extracted_at is not None:
            with open("extract_meta.json", "w") as f:
                json.dump({"source": "dp", "extractedAtUtc": extracted_at, "rows": 5}, f)
        elif step == "extract.py":
            with open("extract_meta.json", "w") as f:
                json.dump({"source": "dp", "rows": 5}, f)
        if step == "partition.py":
            os.makedirs(os.path.join("output", "2char"), exist_ok=True)
        return True

    monkeypatch.setattr(rr, "run_step", fake_step)
    return steps


FULL = ["extract.py", "partition.py", "upload.py"]


def test_first_run_publishes(rr, monkeypatch):
    steps = install_steps(rr, monkeypatch)
    assert rr.run_pipeline() == 0
    assert steps == FULL
    meta = json.load(open(os.path.join("output", "2char", "_meta.json")))
    assert meta["generatedAt"] == "2026-10-14T11:50:00+00:00" and meta["publishedAt"]
    last = json.load(open("last_published.json"))
    assert {k: last[k] for k in ("extractedAtUtc", "source", "driveId")} == {
        "extractedAtUtc": "2026-10-14T11:50:00+00:00", "source": "dp", "driveId": "drive-1"}
    assert last["publishedAt"]
    assert not os.path.exists("last_published.json.tmp")
    assert "completed successfully" in open("refresh.log").read()


def test_second_run_same_load_is_skipped(rr, monkeypatch):
    install_steps(rr, monkeypatch)
    assert rr.run_pipeline() == 0
    steps = install_steps(rr, monkeypatch)
    assert rr.run_pipeline() == 0
    assert steps == ["extract.py"]
    assert "SKIPPED - source unchanged" in open("refresh.log").read()


def test_upload_failure_returns_1_and_records_nothing(rr, monkeypatch):
    steps = install_steps(rr, monkeypatch, fail="upload.py")
    assert rr.run_pipeline() == 1
    assert steps == FULL
    assert not os.path.exists("last_published.json")


def test_extract_meta_without_extracted_at_fails(rr, monkeypatch):
    steps = install_steps(rr, monkeypatch, extracted_at=None)
    assert rr.run_pipeline() == 1
    assert steps == ["extract.py"]


def test_corrupt_last_published_republishes(rr, monkeypatch):
    open("last_published.json", "w").write("{not json")
    steps = install_steps(rr, monkeypatch)
    assert rr.run_pipeline() == 0
    assert steps == FULL
    assert "unreadable" in open("refresh.log").read()
    assert json.load(open("last_published.json"))["driveId"] == "drive-1"


def test_different_library_republishes(rr, monkeypatch):
    json.dump({"extractedAtUtc": "2026-10-14T11:50:00+00:00", "source": "dp", "driveId": "staging"},
              open("last_published.json", "w"))
    steps = install_steps(rr, monkeypatch)
    assert rr.run_pipeline() == 0
    assert steps == FULL
