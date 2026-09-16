#!/usr/bin/env bash
set -u
LAB_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
WORK="${RUNNER_TEMP:-/tmp}/kelo-gemini-world-freeze"
ART="$LAB_ROOT/lab-artifacts"
RUNNER="$LAB_ROOT/lab/world-freeze-profile.mjs"
GOOD_CANDIDATES=(
  "307850e1a10ac8c77bf2e059cce56d69b967966e"
  "624829b9cfd4598a9fc34ad948030ee7290b524d"
  "72604f28d4023c0543bfd2c36b1bf6823704a3db"
)
BAD="58433abd908184ede151b3c8d9fe43b96c0969c1"
mkdir -p "$ART"
rm -rf "$WORK"
git clone --quiet https://github.com/kelffren/gemini.git "$WORK"
cd "$WORK"

echo "BAD=$BAD" | tee "$ART/baselines.txt"
for g in "${GOOD_CANDIDATES[@]}"; do echo "GOOD_CANDIDATE=$g" | tee -a "$ART/baselines.txt"; done

prepare_deps(){
  npm install --no-audit --no-fund >/tmp/kelo-npm-install.log 2>&1 || { cat /tmp/kelo-npm-install.log; return 125; }
  if [ ! -x node_modules/.bin/playwright ]; then return 125; fi
  return 0
}

run_current(){
  local label="$1"
  local sha
  sha="$(git rev-parse HEAD)"
  echo "=== TEST $label $sha ===" | tee -a "$ART/run-log.txt"
  git clean -ffd -e node_modules >/dev/null 2>&1 || true
  prepare_deps || return 125
  mkdir -p scripts
  cp "$RUNNER" scripts/__lab-world-freeze-profile.mjs
  python3 -m http.server 4173 --bind 127.0.0.1 >"$ART/http-${sha:0:12}.log" 2>&1 &
  local server=$!
  local ready=0
  for _ in $(seq 1 30); do
    if curl -fsS http://127.0.0.1:4173/index.html >/dev/null 2>&1; then ready=1; break; fi
    sleep .2
  done
  if [ "$ready" != 1 ]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; return 125; fi
  set +e
  timeout 55s node scripts/__lab-world-freeze-profile.mjs --sha="$sha" --out="$ART" --base=http://127.0.0.1:4173/ >>"$ART/run-log.txt" 2>&1
  local rc=$?
  set -e
  kill "$server" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
  rm -f scripts/__lab-world-freeze-profile.mjs
  if [ "$rc" = 124 ]; then echo "TIMEOUT $sha" | tee -a "$ART/run-log.txt"; return 1; fi
  return "$rc"
}

checkout_and_test(){
  local sha="$1" label="$2"
  git reset --hard -q
  git clean -ffd -e node_modules >/dev/null 2>&1 || true
  git checkout --detach -q "$sha" || return 125
  run_current "$label"
}

# Install Chromium once using the bad/current dependency set.
git checkout --detach -q "$BAD"
prepare_deps || exit 2
npx playwright install chromium --with-deps

GOOD=""
for candidate in "${GOOD_CANDIDATES[@]}"; do
  set +e; checkout_and_test "$candidate" "GOOD_CANDIDATE"; rc=$?; set -e
  echo "$candidate rc=$rc" | tee -a "$ART/checkpoint-results.txt"
  if [ "$rc" = 0 ]; then GOOD="$candidate"; break; fi
done

set +e; checkout_and_test "$BAD" "BAD_HEAD"; BAD_RC=$?; set -e
echo "$BAD rc=$BAD_RC" | tee -a "$ART/checkpoint-results.txt"

if [ -z "$GOOD" ]; then
  echo "NO_VALID_GOOD_CHECKPOINT" | tee "$ART/bisect-result.txt"
  exit 3
fi
if [ "$BAD_RC" = 0 ]; then
  echo "BAD_PASSES_CHROMIUM_PROFILE good=$GOOD bad=$BAD" | tee "$ART/bisect-result.txt"
  exit 4
fi

echo "VALID_PASS_FAIL good=$GOOD bad=$BAD" | tee "$ART/bisect-result.txt"
if ! git merge-base --is-ancestor "$GOOD" "$BAD"; then
  echo "GOOD_NOT_ANCESTOR" | tee -a "$ART/bisect-result.txt"
  exit 5
fi

git bisect reset >/dev/null 2>&1 || true
git bisect start "$BAD" "$GOOD" | tee "$ART/bisect-start.txt"
round=0
while [ "$round" -lt 18 ]; do
  round=$((round+1))
  current="$(git rev-parse HEAD)"
  echo "BISECT_ROUND=$round SHA=$current" | tee -a "$ART/bisect-steps.txt"
  set +e; run_current "BISECT_$round"; rc=$?; set -e
  if [ "$rc" = 0 ]; then verdict=good
  elif [ "$rc" = 125 ]; then verdict=skip
  else verdict=bad
  fi
  echo "$current $verdict rc=$rc" | tee -a "$ART/bisect-steps.txt"
  set +e
  output="$(git bisect "$verdict" 2>&1)"
  command_rc=$?
  set -e
  echo "$output" | tee -a "$ART/bisect-steps.txt"
  if echo "$output" | grep -q "is the first bad commit"; then break; fi
  if [ "$command_rc" != 0 ] && ! echo "$output" | grep -qi "only skipped commits"; then break; fi
done

FIRST_BAD="$(git rev-parse refs/bisect/bad 2>/dev/null || true)"
git bisect log > "$ART/bisect-log.txt" 2>&1 || true
if [ -n "$FIRST_BAD" ]; then
  PARENT="$(git rev-parse "${FIRST_BAD}^" 2>/dev/null || true)"
  {
    echo "GOOD=$GOOD"
    echo "BAD=$BAD"
    echo "FIRST_BAD=$FIRST_BAD"
    echo "PARENT=$PARENT"
    git show -s --format='SUBJECT=%s%nAUTHOR=%an%nDATE=%aI' "$FIRST_BAD" || true
  } >> "$ART/bisect-result.txt"
  git show --stat --oneline --decorate "$FIRST_BAD" > "$ART/first-bad-stat.txt" 2>&1 || true
  if [ -n "$PARENT" ]; then git diff --name-status "$PARENT" "$FIRST_BAD" > "$ART/first-bad-files.txt" 2>&1 || true; fi
fi
git bisect reset >/dev/null 2>&1 || true
cat "$ART/bisect-result.txt"
