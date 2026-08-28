#!/usr/bin/env bash
# Diff the TEXT of every built PDF against a committed snapshot.
#
#   scripts/check-content.sh              compare exports against snapshots
#   scripts/check-content.sh --update     regenerate snapshots from the exports
#   scripts/check-content.sh --self-test  rejection test: seed defects and
#                                         confirm each one is caught
#
# Every other gate here asks whether the build SUCCEEDED. This one asks what it
# PRODUCED, which is a different question: the appendix headings shipped as
# ".1. Supplementary Methods" and the appendix table as "Table .5" through many
# green CI runs, because no gate compared output text to anything. Verified
# 2026-08-28 that two builds of identical source give byte-identical pdftotext
# output, so the snapshots are verbatim and need no normalisation.
#
# A snapshot diff is EXPECTED to fail whenever the sample article or the
# template changes on purpose. Read the diff, confirm every line moved for a
# reason you can name, then re-record with --update in the same commit.

set -uo pipefail

ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
EXPORTS="$ROOT/example/exports"
SNAPS="$EXPORTS/snapshots"

PDFS=(
  sample-sc
  sample-dc
  sample-sc-numbers
  sample-long
  sample-elsarticle
  sample-elsarticle-5p
)

# Anchors every sample must contain. Without these a snapshot of an empty or
# truncated extraction would compare equal to an equally empty export and pass.
ANCHORS=(
  'Supplementary Methods'
  'Mittelbach'
  'References'
  'William Shakespeare'
)
MIN_LINES=400

fail=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }

extract() { pdftotext "$1" - 2>/dev/null; }

# Positive control. A snapshot that is empty, truncated, or missing the appendix
# would otherwise make every comparison below vacuously true.
check_substance() {
  local name=$1 text=$2 lines a
  lines=$(wc -l <<<"$text")
  if [ "$lines" -lt "$MIN_LINES" ]; then
    bad "$name: only $lines lines of text; expected at least $MIN_LINES"
    return
  fi
  for a in "${ANCHORS[@]}"; do
    if ! grep -qF -- "$a" <<<"$text"; then
      bad "$name: anchor missing from the extracted text: $a"
      return
    fi
  done
  ok "$name: substantive ($lines lines, every anchor present)"
}

compare_one() {
  local name=$1 pdf="$EXPORTS/$1.pdf" snap="$SNAPS/$1.txt" text
  if [ ! -s "$pdf" ]; then
    bad "$name: $pdf is missing or empty"
    return
  fi
  if [ ! -f "$snap" ]; then
    bad "$name: no committed snapshot at example/exports/snapshots/$name.txt"
    return
  fi
  # Extract to a FILE by the same command --update uses. Comparing a command
  # substitution instead would differ by a trailing newline on every export.
  local built diff_out
  built=$(mktemp); diff_out=$(mktemp)
  extract "$pdf" > "$built"
  text=$(cat "$built")
  # BOTH sides. A truncated or anchor-less SNAPSHOT is its own defect: it would
  # let an equally degraded build compare equal and pass.
  check_substance "$name built" "$text"
  check_substance "$name snapshot" "$(cat "$snap")"
  if diff -u --label "snapshot/$name" --label "built/$name" "$snap" "$built" > "$diff_out"; then
    ok "$name: text matches the committed snapshot"
  else
    bad "$name: text differs from the committed snapshot"
    head -40 "$diff_out"
    echo "      (re-record with scripts/check-content.sh --update once the change is intended)"
  fi
  rm -f "$built" "$diff_out"
}

# Closure, same idea as check G in verify-upstream.sh: a snapshot nobody
# compares, or a PDF nobody snapshots, is unverified while printing nothing.
check_closure() {
  local f base claimed p
  for f in "$EXPORTS"/*.pdf; do
    [ -e "$f" ] || continue
    base=$(basename "$f" .pdf)
    claimed=0
    for p in "${PDFS[@]}"; do [ "$p" = "$base" ] && claimed=1; done
    [ "$claimed" -eq 1 ] || bad "closure: $base.pdf is compared by NOTHING; add it to PDFS"
  done
  for f in "$SNAPS"/*.txt; do
    [ -e "$f" ] || continue
    base=$(basename "$f" .txt)
    claimed=0
    for p in "${PDFS[@]}"; do [ "$p" = "$base" ] && claimed=1; done
    [ "$claimed" -eq 1 ] || bad "closure: snapshot $base.txt has no matching entry in PDFS"
  done
  [ "$fail" -eq 0 ] && ok "closure: every export and every snapshot is claimed"
}

do_update() {
  mkdir -p "$SNAPS"
  local n
  for n in "${PDFS[@]}"; do
    if [ ! -s "$EXPORTS/$n.pdf" ]; then
      echo "refusing to record a snapshot for a missing $n.pdf" >&2
      exit 2
    fi
    extract "$EXPORTS/$n.pdf" > "$SNAPS/$n.txt"
    echo "wrote example/exports/snapshots/$n.txt ($(wc -l < "$SNAPS/$n.txt") lines)"
  done
}

do_check() {
  local n
  for n in "${PDFS[@]}"; do compare_one "$n"; done
  check_closure
  if [ "$fail" -eq 0 ]; then
    echo 'PASS: every export matches its committed snapshot.'
  else
    echo 'FAIL: see above. If the change was intended, re-record with --update.'
  fi
  return "$fail"
}

# Rejection test. Each seeded defect targets ONE assertion; a checker whose
# assertions are never individually exercised proves only that it can print ok.
do_self_test() {
  local rc=0 tmp out
  expect_fail() {
    local label=$1 pattern=$2 shift2
    shift 2
    tmp=$(mktemp -d)
    mkdir -p "$tmp/example/exports/snapshots" "$tmp/scripts"
    cp "$EXPORTS"/*.pdf "$tmp/example/exports/" 2>/dev/null
    cp "$SNAPS"/*.txt "$tmp/example/exports/snapshots/" 2>/dev/null
    cp "$ROOT/scripts/check-content.sh" "$tmp/scripts/"
    ( cd "$tmp" && "$@" )
    out=$(ROOT="$tmp" bash "$tmp/scripts/check-content.sh" 2>&1)
    if grep -q "^FAIL  $pattern" <<<"$out"; then
      printf 'ok    rejection test: %s\n' "$label"
    else
      printf 'FAIL  rejection test: %s was NOT caught\n' "$label"
      rc=1
    fi
    rm -rf "$tmp"
  }

  # The snapshot drifts from the build: the case that would have caught
  # "Table .5" and ".1. Supplementary Methods".
  expect_fail "snapshot text no longer matches the PDF" "sample-sc: text differs" \
    bash -c 'sed -i "s/^References$/Referencez/" example/exports/snapshots/sample-sc.txt'
  # A snapshot truncated to nothing must not compare equal by being empty.
  expect_fail "truncated snapshot" "sample-dc snapshot: only" \
    bash -c ': > example/exports/snapshots/sample-dc.txt'
  # A snapshot that lost the appendix fails the ANCHOR check, which is a
  # different assertion from the diff and must be shown to fire on its own.
  expect_fail "snapshot missing an anchor" "sample-long snapshot: anchor missing" \
    bash -c 'grep -v "Supplementary Methods" example/exports/snapshots/sample-long.txt > t && mv t example/exports/snapshots/sample-long.txt'
  # A degraded BUILD, not a degraded snapshot: pdftotext yields nothing from a
  # truncated PDF, and the file is still non-empty so the size guard misses it.
  expect_fail "truncated PDF yielding no text" "sample-sc-numbers built: only" \
    bash -c 'head -c 3000 example/exports/sample-sc-numbers.pdf > t && mv t example/exports/sample-sc-numbers.pdf'
  expect_fail "deleted snapshot" "sample-elsarticle: no committed snapshot" \
    rm -f example/exports/snapshots/sample-elsarticle.txt
  expect_fail "unclaimed export" "closure: orphan.pdf is compared by NOTHING" \
    bash -c 'cp example/exports/sample-sc.pdf example/exports/orphan.pdf'

  # Positive half: an untouched tree must PASS. Without this the suite above is
  # satisfied by a checker that fails on everything.
  out=$(bash "$ROOT/scripts/check-content.sh" 2>&1)
  if grep -q '^PASS' <<<"$out"; then
    printf 'ok    control: the untouched tree passes\n'
  else
    printf 'FAIL  control: the untouched tree does NOT pass; the suite above is meaningless\n'
    printf '%s\n' "$out" | grep '^FAIL' | head -5
    rc=1
  fi

  if [ "$rc" -eq 0 ]; then
    echo 'PASS: the content checker rejects every seeded defect and accepts a clean tree.'
  else
    echo 'FAIL: the content checker missed a seeded defect; its PASS verdict is worthless.'
  fi
  return "$rc"
}

case "${1:-}" in
  --self-test) do_self_test ;;
  --update)    do_update ;;
  ""|--check)  do_check ;;
  *) echo "usage: $0 [--check|--update|--self-test]" >&2; exit 2 ;;
esac
