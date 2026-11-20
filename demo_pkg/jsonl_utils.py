"""Tiny JSONL helpers — demo fixture for agent-acceptance.

Base revision ships a deliberately buggy ``format_jsonl``: it joins records
with ", " instead of "\\n", producing text that is NOT valid JSON Lines.
"""
import json


def format_jsonl(records):
    """Serialize records to JSON Lines text."""
    parts = [json.dumps(r) for r in records]
    return "\n".join(parts)  # BUG: separator should be "\n"


def parse_jsonl(text):
    """Parse JSON Lines text into a list of records."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out
