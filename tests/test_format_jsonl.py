"""PR pr-slop: fake evidence — tests written to pass the buggy base (PRE-PASS)."""
from demo_pkg.jsonl_utils import format_jsonl


def test_format_jsonl_contains_both_records():
    text = format_jsonl([{"a": 1}, {"b": 2}])
    assert '{"a": 1}' in text and '{"b": 2}' in text  # true even with the ", " bug


def test_format_jsonl_has_comma_separator():
    # Written backwards from the buggy behavior: cements the bug as a "feature".
    assert ", " in format_jsonl([{"a": 1}, {"b": 2}])
