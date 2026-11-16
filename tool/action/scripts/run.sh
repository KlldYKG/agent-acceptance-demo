#!/usr/bin/env bash
# Orchestrator for the agent-acceptance report-mode prototype.
# Runs on ubuntu-latest (docker, git, gh, jq preinstalled by GitHub).
set -euo pipefail

T="$(mktemp -d)"
OUT="$T/out"; mkdir -p "$OUT"
chmod 777 "$OUT"   # bind-mount target must be writable regardless of container uid mapping
RUN_ID="$(head -c 8 /proc/sys/kernel/random/uuid)"
changed_tests=()  # populated below

log() { echo "[agent-acceptance] $*"; }

# ---------------------------------------------------------------- classify changes
mapfile -t ALL_CHANGED < <(git diff --name-only "$AA_BASE_SHA" "$AA_HEAD_SHA" || true)
is_test_file() {
  local f="$1"
  [[ "$f" == *.py ]] || return 1
  for d in ${AA_TEST_DIRS//,/ }; do
    [[ "$f" == "$d"/* ]] || continue
    [[ "$(basename "$f")" == test_*.py || "$(basename "$f")" == *_test.py ]] && return 0
  done
  return 1
}
for f in "${ALL_CHANGED[@]}"; do
  if is_test_file "$f"; then changed_tests+=("$f"); else [[ "$f" == *.py ]] && changed_src+=("$f"); fi
done
changed_src=(${changed_src[@]-})

# ---------------------------------------------------------------- no-evidence path
if [ "${#changed_tests[@]}" -eq 0 ]; then
  log "no changed test files; nothing to verify"
  printf '# Test-evidence assessment\n\nNo test files were changed in this PR, so there is no executable test evidence to verify.\n' > "$OUT/report.md"
  TEST_STRENGTH="NONE"; VERDICT="NO_EVIDENCE"
  bash "$(dirname "$0")/post_comment.sh" "$OUT/report.md" "$AA_PR_NUMBER" "$AA_REPO"
  exit 0
fi

TEST_PATHS="${changed_tests[*]}"

# ---------------------------------------------------------------- prepare trees
mkdir -p "$T/base-tree" "$T/pr-tree"
git archive "$AA_BASE_SHA" | tar -x -C "$T/base-tree"
git archive "$AA_HEAD_SHA" | tar -x -C "$T/pr-tree"
# Overlay the PR's changed test files onto the base tree (plain copy, no execution).
( cd "$T/pr-tree" && cp --parents "${changed_tests[@]}" "$T/base-tree/" )

# ---------------------------------------------------------------- optional deps phase
DEPS_VOL="aa_deps_${RUN_ID}"
docker volume create "$DEPS_VOL" >/dev/null
DEPS_MOUNT=()
if [ "$AA_INSTALL_DEPS" = "true" ]; then
  log "setup container: installing dependencies (networked, 900s cap, binary wheels only)"
  timeout 900 docker run --rm --user "$(id -u):$(id -g)" \
    -v "$T/pr-tree:/src:ro" -v "$DEPS_VOL:/deps" \
    aa-runner:local bash -c \
    "pip install --no-cache-dir --target /deps --only-binary=:all: \
       -i https://pypi.org/simple -r /src/requirements.txt 2>&1 || \
     pip install --no-cache-dir --target /deps --only-binary=:all: \
       -i https://pypi.org/simple /src 2>&1" \
    || log "dependency installation failed; tests may ImportError (reported as ERROR)"
  DEPS_MOUNT=(-v "$DEPS_VOL:/deps:ro" -e PYTHONPATH=/deps)
fi

# ---------------------------------------------------------------- sandbox runs
run_sandbox() { # $1=tree $2=junitxml
  docker run --rm --network none \
    --cpus 2 --memory 2g --pids-limit 256 \
    --read-only --tmpfs /tmp:rw,noexec,nosuid,size=512m \
    --cap-drop ALL --security-opt no-new-privileges --user "$(id -u):$(id -g)" \
    -e PYTHONDONTWRITEBYTECODE=1 -e HOME=/tmp \
    -v "$1:/work:ro" -v "$OUT:/out:rw" "${DEPS_MOUNT[@]}" \
    -w /work aa-runner:local \
    python -m pytest -p no:cacheprovider -q --junitxml="/out/$2" $TEST_PATHS \
    || true   # failing tests are data, not runner failure
}
log "sandbox run: changed tests against BASE revision"
run_sandbox "$T/base-tree" base.xml
log "sandbox run: changed tests against PR revision"
run_sandbox "$T/pr-tree" pr.xml

# ---------------------------------------------------------------- mutation phase
MUT_STATUS="SKIPPED"
if [ "${#changed_src[@]}" -gt 0 ]; then
  mkdir -p "$T/mut-tree"
  git archive "$AA_HEAD_SHA" | tar -x -C "$T/mut-tree"
  printf '[mutmut]\nrunner=python -m pytest -x -q -p no:cacheprovider %s\npaths_to_mutate=%s\n' \
    "$TEST_PATHS" "$(IFS=,; echo "${changed_src[*]}")" > "$T/mut-tree/setup.cfg"
  log "sandbox run: mutmut sampling (budget ${AA_MUTATION_BUDGET_S}s)"
  if timeout "$AA_MUTATION_BUDGET_S" docker run --rm --network none \
      --cpus 2 --memory 2g --pids-limit 256 \
      --cap-drop ALL --security-opt no-new-privileges --user "$(id -u):$(id -g)" \
      -e PYTHONDONTWRITEBYTECODE=1 -e HOME=/tmp \
      -v "$T/mut-tree:/work" -v "$OUT:/out:rw" "${DEPS_MOUNT[@]}" \
      -w /work aa-runner:local bash -c \
      "mutmut run 2>&1 | tail -5; mutmut junitxml > /out/mutation.xml" ; then
    MUT_STATUS="OK"
  else
    log "mutation phase did not finish within budget; will render as SKIPPED"
  fi
fi

# ---------------------------------------------------------------- assess & publish
python "$(dirname "$0")/evaluate.py" "$OUT" "$AA_BASE_SHA" "$AA_HEAD_SHA" "$MUT_STATUS"
python "$(dirname "$0")/report.py"   "$OUT"

bash "$(dirname "$0")/post_comment.sh" "$OUT/report.md" "$AA_PR_NUMBER" "$AA_REPO"

VERDICT="$(jq -r .verdict "$OUT/evidence.json")"
log "config: AA_GATE='${AA_GATE}' VERDICT='${VERDICT}' (gate fires only when AA_GATE=true)"
if [ "$AA_GATE" = "true" ] && { [ "$VERDICT" = "INVALID_EVIDENCE" ] || [ "$VERDICT" = "ERROR" ]; }; then
  log "gate mode: failing on verdict=$VERDICT"
  exit 1
fi
exit 0
