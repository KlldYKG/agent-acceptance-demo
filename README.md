# Demo — agent-acceptance report mode (dogfooding fixture, P1a · D2)

A three-branch fixture that exercises both discrimination directions of the
test-bidirectional-validity check (SPEC v2 §2).

| Branch | Contents | Expected report |
|---|---|---|
| `main` | `format_jsonl` joins records with `", "` (bug); pre-existing suite green | — |
| `pr-valid` | separator fixed to `"\n"` + 2 new tests | both tests **VALID** (fail on base → pass on PR), strength **STRONG** |
| `pr-slop` | 2 new tests written to pass the buggy base | both tests **PRE-PASS** ⚠, strength **WEAK**, bug survives |

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
