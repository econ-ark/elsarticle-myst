# Shared by the scripts/check-*.sh gates and verify-upstream.sh. Source it after
# `set -uo pipefail`. Sourcing resets the fail flag that ok/bad report through.

ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
fail=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }

# Strip EVERY comment line, '%%' and single '%' alike. A comment must never
# satisfy a presence assertion nor trip an absence one, and the template's own
# comments mention the macros and strings the checks look for.
strip_comments() { grep -v '^[[:space:]]*%' "$1"; }

# Build page $2 in directory $1 to TeX. mystmd prints "Exported TeX" and exits 0
# even when the template render aborts, so the log is the only signal.
render_tex() {
  local out
  out=$( cd "$1" && myst build --tex "$2" --force 2>&1 )
  if grep -qE 'Template render error|TypeError' <<<"$out"; then
    grep -E 'Template render error|TypeError' <<<"$out" | head -2
    return 1
  fi
}

# Self-test verdict. $3 is a checker's output after a seeded defect and must hold
# a line matching the regex $2. A miss sets rc in the calling self-test.
expect_caught() {
  if grep -q -- "$2" <<<"$3"; then
    printf 'ok    rejection test: %s\n' "$1"
  else
    printf 'FAIL  rejection test: %s was NOT caught\n' "$1"
    rc=1
  fi
}

# PDF-reading checkers: a missing pdftotext must fail, never read as empty text.
require_pdftotext() { command -v pdftotext >/dev/null || { bad 'pdftotext is not installed'; return 1; }; }

# Final verdict line: flag $1 (a check's fail, a self-test's rc) of 0 prints PASS
# $2, anything else FAIL $3. Returns the flag.
verdict() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $3"; fi; return "$1"; }

# Self-test control: the caller's run_checks must pass on the untouched template
# at ROOT, or no seeded defect proves anything. A failure sets rc.
expect_control_passes() {
  local out
  out=$( fail=0; run_checks "$ROOT" 2>&1 )
  if grep -q '^FAIL' <<<"$out"; then
    printf '%s\n' "$out"
    printf 'FAIL  control: the untouched template does NOT pass; the seeds below prove nothing\n'
    rc=1
  else
    printf 'ok    control: the untouched template passes\n'
  fi
}

# Seed ONE defect into a copy of the template at ROOT: run the command after $4
# on the copy's file $4, then check $3 against the copy, which must FAIL matching
# $2. An edit that leaves the file unchanged fails as unseeded.
seed_defect() {
  local label=$1 pattern=$2 check=$3 file=$4 tmpl before out
  shift 4
  tmpl=$(copy_template "$ROOT")
  before=$(md5sum < "$tmpl/$file")
  "$@" "$tmpl/$file"
  if [ "$(md5sum < "$tmpl/$file")" = "$before" ]; then
    printf 'FAIL  rejection test: %s could not be seeded; the code was not where expected\n' "$label"
    rc=1
  else
    out=$( fail=0; ROOT="$tmpl" "$check" "$tmpl" 2>&1 )
    expect_caught "$label" "^FAIL  .*$pattern" "$out"
  fi
  rm -rf "$(dirname "$tmpl")"
}

# Copy the template tree at $1 to a temporary directory and print its path, for
# self-tests that seed a defect. Excluded trees are skipped at copy time, since
# _build alone can run to hundreds of megabytes.
copy_template() {
  local tmpl
  tmpl=$(mktemp -d)/tpl
  mkdir -p "$tmpl"
  tar -C "$1" --exclude=./example --exclude=./_build --exclude=./original \
      --exclude=./.git --exclude=./.claude -cf - . | tar -C "$tmpl" -xf -
  printf '%s\n' "$tmpl"
}
