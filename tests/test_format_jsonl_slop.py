"""Deliberately slop test: tuned to the BUGGY base behavior.

This test passes on the base revision (bug present) and on this PR (no fix
included) — so it proves nothing about any change. The bidirectional check
marks it PRE-PASS; with gate: true on the base branch this fails the
`evidence` required check and blocks the merge.
"""
from demo_pkg.jsonl_utils import format_jsonl


def test_format_jsonl_uses_comma_separator():
    # WRONG on purpose: encodes the bug as if it were the spec.
    assert format_jsonl([{"a": 1}, {"b": 2}]) == '{"a": 1}, {"b": 2}'
