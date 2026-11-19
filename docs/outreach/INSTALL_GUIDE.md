# Install agent-acceptance (report mode) — 5 minutes, zero risk to your CI

> Report mode **never blocks merges**. It posts one comment per PR assessing the
> test evidence of AI (or human) contributions. No LLM involved — the checks are
> deterministic execution.

## What you get

For every PR that adds or modifies test files, a comment like this appears:

| Changed test | on base | on PR | verdict |
|---|---|---|---|
| `tests/test_x.py::test_foo` | ❌ failed | ✅ passed | **VALID** ✅ |
| `tests/test_y.py::test_bar` | ✅ passed | ✅ passed | PRE-PASS ⚠️ |

- **VALID** = the test fails on your current main and passes on the PR — real evidence.
- **PRE-PASS** = the test already passes without the change — it proves nothing about the change (classic AI-slop signature).
- Optional mutation sampling reports which behaviors the new tests fail to pin down (time-budgeted; skipped gracefully if the budget runs out).

Live demo (real runs on a public repo): [PR with valid evidence](https://github.com/KlldYKG/agent-acceptance-demo/pull/1) · [PR with fake evidence, detected](https://github.com/KlldYKG/agent-acceptance-demo/pull/2)

## Install (one file)

Create `.github/workflows/agent-acceptance.yml`:

```yaml
name: agent-acceptance
on: pull_request_target

permissions:
  contents: read
  pull-requests: write

jobs:
  evidence:
    runs-on: ubuntu-latest
    steps:
      # Action code: served from the tool repo, pinned to the v1.0.1 release SHA.
      - name: Evaluate test evidence
        uses: KlldYKG/agent-acceptance/action@a860ce6d180bd3bd78527188e354c9cbc996307e
        with:
          github-token: ${{ github.token }}
          # test-dirs: tests          # comma-separated, defaults to "tests"
          # mutation-budget-seconds: 600
          # gate: false               # report-only. Never set true without a team decision.
```

Pilot pin: `a860ce6` (tool repo release `v1.0.1`). Pinning to a SHA means
the tool's code **cannot change under you** — updates happen only when you edit
the pin. We will announce every new pin in advance; you are never auto-upgraded.

> **First run**: GitHub may ask you to approve the new workflow
> (Actions tab → the pending run → "I understand my workflows, go ahead and
> run them"). This is a one-time approval per repository.
>
> **Note**: the workflow uses `pull_request_target` so the report can comment on
> PRs from forks. GitHub is tightening defaults for this trigger in Dec 2026;
> if your repo restricts it, allow this one workflow under
> Settings → Actions → Workflow permissions, or ask us for a `pull_request`-only
> variant (same report, no fork-PR comments).

## Uninstall

Delete the workflow file. Nothing else was changed: no branch protection, no
required checks, no secrets, no dependencies added to your project.

## Security model (short version)

- PR code is executed only inside a hardened Docker container:
  `--network none`, `--read-only` rootfs, `--cap-drop ALL`, CPU/memory/PID limits.
- The action's code comes from the **pinned SHA of the tool repo**, never from
  the PR — contributors cannot alter the checks.
- Optional dependency installation (`install-deps: true`) is opt-in, networked,
  binary-wheels-only, and runs in a separate setup container.
- The gate never uses an LLM. Verdicts are reproducible from the PR diff alone.

Full design & threat model: see the README of
[KlldYKG/agent-acceptance-demo](https://github.com/KlldYKG/agent-acceptance-demo).
