"""PR pr-valid: real evidence — both tests fail on the buggy base, pass after the fix."""
import json

from demo_pkg.jsonl_utils import format_jsonl, parse_jsonl


def test_format_jsonl_emits_lines():
    text = format_jsonl([{"a": 1}, {"b": 2}])
    assert "\n" in text  # fails on base: joins with ", "


def test_format_jsonl_output_is_parseable():
    text = format_jsonl([{"a": 1}, {"b": 2}])
    assert parse_jsonl(text) == [{"a": 1}, {"b": 2}]  # fails on base: loads(", {...}") raises
