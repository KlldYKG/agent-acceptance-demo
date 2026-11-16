#!/usr/bin/env python3
"""Classify bidirectional test validity + mutation results -> evidence.json.

Usage: evaluate.py OUT_DIR BASE_SHA HEAD_SHA MUT_STATUS
Reads OUT_DIR/{base.xml, pr.xml, mutation.xml?}, writes OUT_DIR/evidence.json.
JUnit XML parsing uses only the stdlib. Class Semantics (DESIGN_REPORT_MODE.md §3):
VALID (fail on base, pass on PR) / PRE-PASS / BROKEN / ERROR.
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

VERDICTS = ("VALID", "PRE-PASS", "BROKEN", "ERROR")


def parse_junit(path: Path) -> dict:
    """Return {test_key: outcome} where outcome in {passed, failed, error, missing}."""
    if not path.exists():
        return {}
    outcomes = {}
    root = ET.parse(path).getroot()
    for case in root.iter("testcase"):
        key = f"{case.get('classname', '')}::{case.get('name', '')}"
        if case.find("failure") is not None or case.find("assertion") is not None:
            outcomes[key] = "failed"
        elif case.find("error") is not None:
            outcomes[key] = "error"
        else:
            outcomes[key] = "passed"
    return outcomes


def parse_mutation(path: Path) -> dict:
    """mutmut junitxml: one testcase per mutant; survivors carry a 'skipped' marker."""
    if not path.exists():
        return {"status": "SKIPPED", "score": None, "killed": 0, "survived": 0,
                "survivor_samples": []}
    killed = survived = 0
    samples = []
    for case in ET.parse(path).getroot().iter("testcase"):
        desc = f"{case.get('classname', '')}::{case.get('name', '')}"
        if case.find("skipped") is not None:  # mutmut marks survived mutants skipped
            survived += 1
            if len(samples) < 5:
                msg = case.find("skipped").get("message", "")[:160]
                samples.append({"mutant": desc, "detail": msg})
        else:
            killed += 1
    total = killed + survived
    return {"status": "OK", "score": round(killed / total, 3) if total else None,
            "killed": killed, "survived": survived, "survivor_samples": samples}


def main() -> None:
    out = Path(sys.argv[1])
    base_sha, head_sha, mut_status = sys.argv[2], sys.argv[3], sys.argv[4]

    base = parse_junit(out / "base.xml")
    pr = parse_junit(out / "pr.xml")

    if not base or not pr:
        strength, verdict = "NONE", "ERROR"
        rows = [{"test": k, "on_base": v, "on_pr": pr.get(k, "missing"),
                 "verdict": "ERROR", "note": "run collection failed"} for k, v in base.items()]
    else:
        rows = []
        for key, b in base.items():
            p = pr.get(key, "missing")
            if b == "failed" and p == "passed":
                verdict = "VALID"
            elif b == "passed" and p == "passed":
                verdict = "PRE-PASS"
            elif p == "missing" or p == "error" or b == "error":
                verdict = "ERROR"
            else:
                verdict = "BROKEN"
            rows.append({"test": key, "on_base": b, "on_pr": p, "verdict": verdict,
                         "note": ""})
        valid = sum(r["verdict"] == "VALID" for r in rows)
        prepass = sum(r["verdict"] == "PRE-PASS" for r in rows)
        errored = sum(r["verdict"] == "ERROR" for r in rows)
        if errored == len(rows):
            strength, verdict = "NONE", "ERROR"
        elif valid and prepass == 0:
            strength, verdict = "STRONG", "EVIDENCE_OK"
        elif valid or any(r["verdict"] == "BROKEN" for r in rows):
            strength, verdict = "PARTIAL", "EVIDENCE_OK" if valid else "INVALID_EVIDENCE"
        else:
            strength, verdict = "WEAK", "INVALID_EVIDENCE"

    mut = parse_mutation(out / "mutation.xml")
    if mut_status != "OK":
        mut = {**mut, "status": "SKIPPED", "score": None}

    evidence = {
        "schema": "agent-acceptance/evidence@v0",
        "base_sha": base_sha, "head_sha": head_sha,
        "strength": strength, "verdict": verdict,
        "tests": rows,
        "counts": {v: sum(r["verdict"] == v for r in rows) for v in VERDICTS},
        "mutation": mut,
    }
    (out / "evidence.json").write_text(json.dumps(evidence, indent=2))
    print(json.dumps({"strength": strength, "verdict": verdict}))


if __name__ == "__main__":
    main()
