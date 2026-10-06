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

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
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

# elsarticle's \title drops its title-note mark after its FIRST printing. Passes when
# no graphical-abstract or highlights page shows a mark and a title-page line has one
# mid-line (a footnote line STARTS with it). Pages split on form feeds.
check_title_marks() {
  local name=$1 text=$2 counts prelim inline
  counts=$(awk 'BEGIN { RS = "\f" }
    { n = split($0, L, "\n"); f = ""
      for (i = 1; i <= n; i++) if (L[i] != "") { f = L[i]; break }
      if (f == "Graphical Abstract" || f == "Highlights") { pm += gsub(/⋆/, "&") }
      else if (!done) { for (i = 1; i <= n; i++) if (L[i] ~ /⋆/ && L[i] !~ /^⋆/) ti++; done = 1 } }
    END { print pm + 0, ti + 0 }' <<<"$text")
  read -r prelim inline <<<"$counts"
  if [ "$prelim" -gt 0 ]; then
    bad "$name: a title-note mark printed on a graphical-abstract or highlights page"
  elif [ "$inline" -lt 1 ]; then
    bad "$name: the title page's title lost its title-note mark"
  else
    ok "$name: the title-note mark is on the title page only"
  fi
}

# PDF metadata against the sample's own frontmatter: Title is "title: subtitle",
# Author the names joined ", ", and empty for an export with `blind: double`.
# CAS once titled every PDF by its subtitle and wrote U+2C20 after the names.
fm() { yq --front-matter=extract -r "$1" "$ROOT/example/sample-article.md"; }
check_metadata() {
  local name=$1 title=$2 author=$3 want_title want_author sub
  sub=$(fm '.subtitle // ""')
  want_title="$(fm '.title')${sub:+: $sub}"
  want_author=$(fm '[.authors[].name] | join(", ")')
  [ -n "$want_author" ] || { bad "$name: the sample names no authors; the metadata check is vacuous"; return; }
  if [ "$(fm ".exports[] | select(.output == \"exports/$name.pdf\") | .blind // \"\"")" = double ]; then
    want_author=''
  fi
  if [ "$title" != "$want_title" ]; then
    bad "$name: PDF Title is '$title', expected '$want_title'"
  elif [ "$author" != "$want_author" ]; then
    bad "$name: PDF Author is '$author', expected '$want_author'"
  elif [ -z "$want_author" ]; then
    ok "$name: PDF Title matches the frontmatter, and no author is named (double-blind)"
  else
    ok "$name: PDF Title and Author match the frontmatter"
  fi
}

# A literal '??' is an unresolved cross-reference, and two ways it arises raise
# NO LaTeX warning, so the compile-log gate cannot see them. See README.md
# "Known upstream limitations".
check_no_unresolved_refs() {
  local name=$1 text=$2 hit
  hit=$(grep -n '??' <<<"$text" | head -3)
  if [ -n "$hit" ]; then
    bad "$name: unresolved cross-reference(s) in the PDF text"
    printf '      %s\n' "$hit"
  else
    ok "$name: no unresolved cross-references"
  fi
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
  check_no_unresolved_refs "$name" "$text"
  check_metadata "$name" "$(pdfinfo "$pdf" 2>/dev/null | sed -n 's/^Title: *//p')" \
    "$(pdfinfo "$pdf" 2>/dev/null | sed -n 's/^Author: *//p')"
  # The double-blind export prints no title-note marks at all.
  [ "$name" = sample-elsarticle-5p ] || check_title_marks "$name" "$text"
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
in_pdfs() {
  local p
  for p in "${PDFS[@]}"; do [ "$p" = "$1" ] && return 0; done
  return 1
}

check_closure() {
  local f base
  for f in "$EXPORTS"/*.pdf; do
    [ -e "$f" ] || continue
    base=$(basename "$f" .pdf)
    in_pdfs "$base" || bad "closure: $base.pdf is compared by NOTHING; add it to PDFS"
  done
  for f in "$SNAPS"/*.txt; do
    [ -e "$f" ] || continue
    base=$(basename "$f" .txt)
    in_pdfs "$base" || bad "closure: snapshot $base.txt has no matching entry in PDFS"
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
  verdict "$fail" 'every export matches its committed snapshot.' \
    'see above. If the change was intended, re-record with --update.'
}

# Rejection test. Each seeded defect targets ONE assertion; a checker whose
# assertions are never individually exercised proves only that it can print ok.
do_self_test() {
  local rc=0 tmp out
  expect_fail() {
    local label=$1 pattern=$2
    shift 2
    tmp=$(mktemp -d)
    mkdir -p "$tmp/example/exports/snapshots" "$tmp/scripts"
    cp "$EXPORTS"/*.pdf "$tmp/example/exports/" 2>/dev/null
    cp "$SNAPS"/*.txt "$tmp/example/exports/snapshots/" 2>/dev/null
    cp "$ROOT/scripts/check-content.sh" "$ROOT/scripts/lib.sh" "$tmp/scripts/"
    ( cd "$tmp" && "$@" )
    out=$(ROOT="$tmp" bash "$tmp/scripts/check-content.sh" 2>&1)
    expect_caught "$label" "^FAIL  $pattern" "$out"
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
  # The ?? check is exercised at FUNCTION level: seeding it through a real PDF
  # would need a PDF writer in CI, and rebuilding a sample with a broken ref is
  # far slower than feeding the extracted text directly.
  out=$( fail=0; check_no_unresolved_refs probe "Cross-ref: Sec ?? and Algorithm ??."; echo "__fail=$fail" )
  if grep -q '^FAIL  probe: unresolved cross-reference' <<<"$out"; then
    printf 'ok    rejection test: an unresolved cross-reference is caught\n'
  else
    printf 'FAIL  rejection test: an unresolved cross-reference was NOT caught\n'
    rc=1
  fi
  out=$( fail=0; check_no_unresolved_refs probe "Ordinary prose with no markers."; echo "__fail=$fail" )
  if grep -q '^ok    probe: no unresolved' <<<"$out"; then
    printf 'ok    control: clean text does not trip the ?? check\n'
  else
    printf 'FAIL  control: the ?? check fires on clean text\n'
    rc=1
  fi
  # Title-note marks, at function level for the same reason as the ?? check.
  # The first text is the defect: mark stolen by the graphical-abstract page.
  local stolen=$'Graphical Abstract\nTitle⋆,⋆⋆\n\fHighlights\nTitle\n\fTitle\nA. Author\n⋆ Funded.'
  local placed=$'Graphical Abstract\nTitle\n\fHighlights\nTitle\n\fTitle⋆,⋆⋆\nA. Author\n⋆ Funded.'
  out=$( fail=0; check_title_marks probe "$stolen" )
  expect_caught 'a title-note mark stolen by the graphical-abstract page' '^FAIL  probe: a title-note mark printed' "$out"
  out=$( fail=0; check_title_marks probe "$placed" )
  if grep -q '^ok    probe: the title-note mark is on the title page only' <<<"$out"; then
    printf 'ok    control: a mark on the title page alone passes\n'
  else
    printf 'FAIL  control: the title-mark check fires on a correct layout\n'
    rc=1
  fi
  # Metadata, at function level: CAS's U+2C20 after the names, the subtitle as
  # Title, and authors named in the double-blind export.
  local sub ftitle names
  sub=$(fm '.subtitle // ""'); ftitle="$(fm '.title')${sub:+: $sub}"
  names=$(fm '[.authors[].name] | join(", ")')
  out=$( fail=0; check_metadata sample-sc "$ftitle" "$names"$'Ⱐ' )
  expect_caught 'U+2C20 after the PDF author names' '^FAIL  sample-sc: PDF Author' "$out"
  out=$( fail=0; check_metadata sample-sc "$sub" "$names" )
  expect_caught 'the subtitle as PDF Title' '^FAIL  sample-sc: PDF Title' "$out"
  out=$( fail=0; check_metadata sample-elsarticle-5p "$ftitle" "$names" )
  expect_caught 'authors named in the double-blind PDF metadata' '^FAIL  sample-elsarticle-5p: PDF Author' "$out"
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

  verdict "$rc" 'the content checker rejects every seeded defect and accepts a clean tree.' \
    'the content checker missed a seeded defect; its PASS verdict is worthless.'
}

case "${1:-}" in
  --self-test) do_self_test ;;
  --update)    do_update ;;
  ""|--check)  do_check ;;
  *) echo "usage: $0 [--check|--update|--self-test]" >&2; exit 2 ;;
esac
