from datetime import datetime, timezone

import pytest

from refresh_logic import (MIN_ROWS, build_meta, has_extracted_at, should_skip, source_path, to_utc_iso,
                           upload_order, validate_extract)


def test_source_paths():
    assert source_path("lh").endswith("/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/InMaster_PartsLookup_Raw")
    assert source_path("dp") == ("abfss://189e5c0a-548a-4feb-93d6-dda9ebbe96c1@onelake.dfs.fabric.microsoft.com/"
                                 "6713bd45-a4ad-47e6-8bff-1bb0415e9784/Tables/PartsAvailability")
    assert "876255e0-d462-4697-adc1-4a655f5bb101" in source_path("dp-dev")
    assert not has_extracted_at("lh") and has_extracted_at("dp") and has_extracted_at("dp-dev")
    with pytest.raises(ValueError, match="unknown source"):
        source_path("prod")


def test_to_utc_iso_treats_naive_as_utc():
    assert to_utc_iso(datetime(2026, 10, 14, 11, 50, 3)) == "2026-10-14T11:50:03+00:00"
    aware = datetime(2026, 10, 14, 11, 50, tzinfo=timezone.utc)
    assert to_utc_iso(aware) == "2026-10-14T11:50:00+00:00"


def test_validate_extract_ok():
    t = datetime(2026, 10, 14, 11, 50)
    assert validate_extract(1_068_934, [t], 0, require_extracted_at=True) == []
    assert validate_extract(1_068_934, [], 0, require_extracted_at=False) == []


def test_validate_extract_failures():
    t = datetime(2026, 10, 14, 11, 50)
    assert "rows" in validate_extract(MIN_ROWS - 1, [t], 0, True)[0]
    assert "duplicate" in validate_extract(1_068_934, [t], 3, True)[0]
    assert "ExtractedAtUtc" in validate_extract(1_068_934, [t, datetime(2026, 10, 14, 12, 50)], 0, True)[0]
    assert "ExtractedAtUtc" in validate_extract(1_068_934, [None], 0, True)[0]
    assert "ExtractedAtUtc" in validate_extract(1_068_934, [], 0, True)[0]
    assert len(validate_extract(10, [], 2, True)) == 3


def test_should_skip_only_when_the_same_load_was_already_published():
    assert should_skip("2026-10-14T11:50:03+00:00", "2026-10-14T11:50:03+00:00")
    assert not should_skip("2026-10-14T12:50:03+00:00", "2026-10-14T11:50:03+00:00")
    assert not should_skip("2026-10-14T11:50:03+00:00", None)
    assert not should_skip(None, None)


def test_build_meta():
    assert build_meta("A", "B") == {"generatedAt": "A", "publishedAt": "B"}


def test_upload_order_puts_meta_last():
    files = ["out/_meta.json", "out/RE1.json.gz", "out/_manifest.json", "out/AB.json.gz"]
    assert upload_order(files) == ["out/AB.json.gz", "out/RE1.json.gz", "out/_manifest.json", "out/_meta.json"]
    assert upload_order(["out/AB.json.gz"]) == ["out/AB.json.gz"]
