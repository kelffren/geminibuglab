#!/usr/bin/env bash
set -u
LAB_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
WORK="${RUNNER_TEMP:-/tmp}/kelo-gemini-world-freeze-webkit"
ART="$LAB_ROOT/lab-artifacts-webkit"
RUNNER="$LAB_ROOT/lab/world-freeze-profile-webkit.mjs"
GOOD_CANDIDATES=(
  "624829b9cfd4598a9fc34ad948030ee7290b524d"
  "72604f28d4023c0543bfd2c36b1bf6823704a3db"
  "307850e1a10ac8c77bf2e059cce56d69b967966e"
)
# Fixed snapshot of current main at start of this diagnostic round.
BAD="ea0dc18a55007351cfdccb37fda5ed1faca9eac3"
mkdir -p "$ART"
rm -rf "$WORK"
git clone --quiet https://github.com/kelffren/gemini.git "$WORK"
cd "$WORK"
echo "BAD=$BAD" | tee "$ART/baselines.txt"
for g in "${GOOD_CANDIDATES[@]}"; do echo "GOOD_CANDIDATE=$g" | tee -a "$ART/baselines.txt"; done

prepare_deps(){
  npm install --no-audit --no-fund >/tmp/kelo-npm-install-webkit.log 2>&1 || { cat /tmp/kelo-npm-install-webkit.log; return 125; }
  test -x node_modules/.bin/playwright || return 125
}
run_current(){
  local label="$1" sha rc server ready
  sha="$(git rev-parse HEAD)"
  echo "=== TEST $label $sha ===" | tee -a "$ART/run-log.txt"
  git clean -ffd -e node_modules >/dev/null 2>&1 || true
  prepare_deps || return 125
  mkdir -p scripts
  cp "$RUNNER" scripts/__lab-world-freeze-webkit.mjs
  python3 -m http.server 4173 --bind 127.0.0.1 >"$ART/http-${sha:0:12}.log" 2>&1 & server=$!
  ready=0
  for _ in $(seq 1 30); do if curl -fsS http://127.0.0.1:4173/index.html >/dev/null 2>&1; then ready=1; break; fi; sleep .2; done
  if [ "$ready" != 1 ]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; return 125; fi
  timeout 65s node scripts/__lab-world-freeze-webkit.mjs --sha="$sha" --out="$ART" --base=http://127.0.0.1:4173/ >>"$ART/run-log.txt" 2>&1; rc=$?
  kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true
  rm -f scripts/__lab-world-freeze-webkit.mjs
  [ "$rc" = 124 ] && return 1
  return "$rc"
}
checkout_and_test(){
  local sha="$1" label="$2"
  git reset --hard -q
  git clean -ffd -e node_modules >/dev/null 2>&1 || true
  git checkout --detach -q "$sha" || return 125
  run_current "$label"
}

git checkout --detach -q "$BAD"
prepare_deps || exit 2
npx playwright install webkit --with-deps

GOOD=""
for candidate in "${GOOD_CANDIDATES[@]}"; do
  checkout_and_test "$candidate" GOOD_CANDIDATE; rc=$?
  echo "$candidate rc=$rc" | tee -a "$ART/checkpoint-results.txt"
  if [ "$rc" = 0 ]; then GOOD="$candidate"; break; fi
done
checkout_and_test "$BAD" BAD_HEAD; BAD_RC=$?
echo "$BAD rc=$BAD_RC" | tee -a "$ART/checkpoint-results.txt"

if [ -z "$GOOD" ]; then echo "NO_VALID_GOOD_CHECKPOINT" | tee "$ART/bisect-result.txt"; exit 3; fi
if [ "$BAD_RC" = 0 ]; then echo "CURRENT_HEAD_PASSES_WEBKIT_PROFILE good=$GOOD bad=$BAD" | tee "$ART/bisect-result.txt"; exit 4; fi
echo "VALID_PASS_FAIL good=$GOOD bad=$BAD" | tee "$ART/bisect-result.txt"
if ! git merge-base --is-ancestor "$GOOD" "$BAD"; then echo "GOOD_NOT_ANCESTOR" | tee -a "$ART/bisect-result.txt"; exit 5; fi

git bisect reset >/dev/null 2>&1 || true
git bisect start "$BAD" "$GOOD" | tee "$ART/bisect-start.txt"
round=0
while [ "$round" -lt 20 ]; do
  round=$((round+1)); current="$(git rev-parse HEAD)"
  echo "BISECT_ROUND=$round SHA=$current" | tee -a "$ART/bisect-steps.txt"
  run_current "BISECT_$round"; rc=$?
  if [ "$rc" = 0 ]; then verdict=good; elif [ "$rc" = 125 ]; then verdict=skip; else verdict=bad; fi
  echo "$current $verdict rc=$rc" | tee -a "$ART/bisect-steps.txt"
  output="$(git bisect "$verdict" 2>&1)"; command_rc=$?
  echo "$output" | tee -a "$ART/bisect-steps.txt"
  if echo "$output" | grep -q "is the first bad commit"; then break; fi
  if [ "$command_rc" != 0 ] && ! echo "$output" | grep -qi "only skipped commits"; then break; fi
done
FIRST_BAD="$(git rev-parse refs/bisect/bad 2>/dev/null || true)"
git bisect log > "$ART/bisect-log.txt" 2>&1 || true
if [ -n "$FIRST_BAD" ]; then
  PARENT="$(git rev-parse "${FIRST_BAD}^" 2>/dev/null || true)"
  { echo "GOOD=$GOOD"; echo "BAD=$BAD"; echo "FIRST_BAD=$FIRST_BAD"; echo "PARENT=$PARENT"; git show -s --format='SUBJECT=%s%nAUTHOR=%an%nDATE=%aI' "$FIRST_BAD" || true; } >> "$ART/bisect-result.txt"
  git show --stat --oneline --decorate "$FIRST_BAD" > "$ART/first-bad-stat.txt" 2>&1 || true
  [ -n "$PARENT" ] && git diff --name-status "$PARENT" "$FIRST_BAD" > "$ART/first-bad-files.txt" 2>&1 || true
fi
git bisect reset >/dev/null 2>&1 || true
cat "$ART/bisect-result.txt"
