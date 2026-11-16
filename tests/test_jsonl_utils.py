"""Pre-existing suite on main (green on the buggy base — parse_jsonl is correct)."""
from demo_pkg.jsonl_utils import parse_jsonl


def test_parse_jsonl_roundtrip():
    text = '{"a": 1}\n{"b": 2}\n'
    assert parse_jsonl(text) == [{"a": 1}, {"b": 2}]
