# Demo — agent-acceptance report mode (dogfooding fixture, P1a · D2)

A three-branch fixture that exercises both discrimination directions of the
test-bidirectional-validity check (SPEC v2 §2).

| Branch | Contents | Expected report |
|---|---|---|
| `main` | `format_jsonl` joins records with `", "` (bug); pre-existing suite green | — |
| `pr-valid` | separator fixed to `"\n"` + 2 new tests | both tests **VALID** (fail on base → pass on PR), strength **STRONG** |
| `pr-slop` | 2 new tests written to pass the buggy base | both tests **PRE-PASS** ⚠, strength **WEAK**, bug survives |
| `gate-demo` | same as `main` + **gate mode ON** (`.agent-acceptance.yml` + workflow input) | see "Gate-mode side story" below |

## Demo timeline (report mode — the default and the main story)

```text
AI contributes a PR containing 2 tests tuned to the existing bug
   │  pull_request_target triggers (tool code ALWAYS from main / pinned SHA)
   ▼
Docker sandbox: no network · read-only rootfs · cap-drop ALL · resource limits
   │  (1) new tests against the BASE revision  -> all pass (bug not caught)
   │  (2) new tests against the PR revision    -> all pass
   ▼
Verdict: PRE-PASS ⚠  (tests that pass before the change prove nothing)
   ▼
PR comment with the report (non-blocking; branch protection untouched)
   ▼
Maintainer reads the evidence and DECIDES: ask for valid tests / close the PR
```

**The timeline ends with a human decision based on evidence — not a machine
gate.** That is the product's stance: evidence first, blocking strictly
opt-in (below).

## Gate-mode side story (opt-in, demo only)

The `gate-demo` branch is `main` plus exactly two changes: an explicit
`.agent-acceptance.yml` (`gate: true`) and `gate: true` in the workflow. A
`slop` PR opened **into `gate-demo`** shows the other ending: the same
INVALID-EVIDENCE verdict now fails the `evidence` status check, and branch
protection (required check `evidence`) blocks the merge button.

> Gate mode is **off by default**. Enabling it is a maintainer decision,
> documented in [docs/GATE_MODE.md](https://github.com/KlldYKG/agent-acceptance/blob/main/docs/GATE_MODE.md).

## Local verification already performed (2026-11-16, pytest 9.2.0)

1. base overlay + `pr-valid`'s new tests → `2 failed, 1 passed` ✅ (fail-before holds)
2. `pr-valid` full tree → `3 passed` ✅ (pass-after holds)
3. `pr-slop` → `2 passed` ✅ (pre-pass detected; buggy output `'{"a": 1}, {"b": 2}'` confirmed)

## Publishing (requires a GitHub repo — external action, ask the owner)

```bash
git remote add origin git@github.com:<user>/agent-acceptance-demo.git
git push -u origin main pr-valid pr-slop
```

Then open `pr-valid` and `pr-slop` as PRs into `main`. The workflow
(`.github/workflows/agent-acceptance.yml`) references `./tool/action` — for a
standalone demo repo, replace that line with the published action ref
(`<org>/agent-acceptance@v0`) once released, or vendor the `tool/action`
directory into this repo.
