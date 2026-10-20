import pytest
import requests

import config
import upload


class Resp:
    def __init__(self, status, text="", headers=None):
        self.status_code, self.text, self.headers = status, text, headers or {}
        self.ok = status < 400


@pytest.fixture
def rig(tmp_path, monkeypatch):
    f = tmp_path / "a.json.gz"
    f.write_bytes(b"data")
    r = type("Rig", (), {})()
    r.path, r.calls, r.sleeps, r.script = str(f), [], [], []

    def put(url, **kw):
        r.calls.append(url)
        item = r.script.pop(0)
        if isinstance(item, Exception):
            raise item
        return item
    monkeypatch.setattr(upload.requests, "put", put)
    monkeypatch.setattr(upload.time, "sleep", lambda s: r.sleeps.append(s))
    return r


def test_503_then_200_succeeds(rig):
    rig.script = [Resp(503), Resp(200)]
    upload.put_file(rig.path, "tok")
    assert len(rig.calls) == 2


def test_403_fails_fast_with_body(rig):
    rig.script = [Resp(403, "Access denied for site")]
    with pytest.raises(RuntimeError, match="403.*Access denied for site"):
        upload.put_file(rig.path, "tok")
    assert len(rig.calls) == 1
    assert rig.sleeps == []


def test_429_honors_retry_after(rig):
    rig.script = [Resp(429, "", {"Retry-After": "7"}), Resp(200)]
    upload.put_file(rig.path, "tok")
    assert rig.sleeps == [7]


def test_oversize_file_rejected_before_put(rig, monkeypatch):
    monkeypatch.setattr(upload, "SIMPLE_LIMIT", 2)
    with pytest.raises(RuntimeError, match="bytes"):
        upload.put_file(rig.path, "tok")
    assert rig.calls == []


def test_network_errors_exhaust_attempts(rig):
    rig.script = [requests.exceptions.ConnectionError("boom")] * 5
    with pytest.raises(requests.exceptions.ConnectionError):
        upload.put_file(rig.path, "tok")
    assert len(rig.calls) == 5


def test_token_requires_secret(monkeypatch):
    monkeypatch.setattr(config, "CLIENT_SECRET", "")
    with pytest.raises(RuntimeError, match="CLIENT_SECRET is empty"):
        upload.token()
