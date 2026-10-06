#!/usr/bin/env bash
# Build the six sample PDFs and run every gate that needs a TeX installation.
#
#   scripts/check-pdfs.sh   rebuild the committed PDFs, then gate them
#
# Local only: CI installs no TeX and checks the committed PDFs as they are. Run
# this before committing a change to the template, the classes or the sample.

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The fixed build date that makes a rebuild of unchanged sources byte-identical.
# README.md's build command must use the same constant. CI compares the two.
EPOCH=1756400000
EX="$ROOT/example"

build() {
  # Delete last build's PDFs and per-export directories first: a build that
  # produces nothing must not leave stale PDFs, or a stale class copy MyST will
  # not overwrite, for the gates below to "verify".
  rm -f "$EX"/exports/*.pdf
  rm -rf "$EX"/exports/*_pdf_tex "$EX"/exports/*_pdf_logs
  ( cd "$EX" && SOURCE_DATE_EPOCH=$EPOCH FORCE_SOURCE_DATE=1 \
      myst build sample-article.md --pdf --force > build.stdout.log 2>&1 )
}

# '^! ' is TeX's fatal-error convention; undefined references and citations are
# warnings that print as '?'; every sample compiles with no overfull box, so a
# new one is text running past its line. See README.md "What CI asserts".
check_compile_logs() {
  local log n=0 x=0
  for log in "$EX"/exports/*_pdf_logs/*.log; do
    # -s: half these files are empty *.shell.log, which would grep "clean".
    [ -s "$log" ] || continue
    n=$((n + 1))
    grep -q 'This is XeTeX' "$log" && x=$((x + 1))
    if grep -qE '^! |Misplaced alignment tab character|Undefined control sequence|LaTeX Error:|Emergency stop|! Package .* Error|\*\*\* \(Job aborted|Warning: (Reference|Citation).*undefined|There were undefined (references|citations)' "$log"; then
      bad "$(basename "$log"): LaTeX errors or undefined references"
    fi
    if grep -q 'Overfull \\hbox' "$log"; then
      bad "$(basename "$log"): text overflows its line"
      grep -A2 'Overfull \\hbox' "$log" | head -6
    fi
  done
  # Positive controls: six non-empty logs, each from a XeTeX run of this build.
  if [ "$n" -lt 6 ] || [ "$x" -lt 6 ]; then
    bad "only $n non-empty compile logs, $x with a XeTeX run; expected 6 of each"
  else
    ok "$n compile logs from XeTeX runs, no error, undefined reference or overfull box"
  fi
}

# mystmd deletes the .blg with the aux files, so build.stdout.log is the only
# bibtex output left. A jtex render error reaches no compile log at all.
check_build_log() {
  local out="$EX/build.stdout.log"
  if ! grep -q 'This is BibTeX' "$out"; then
    bad 'bibtex never ran; the bibliography gate would pass on any input'
  elif grep -qE "didn't find a database entry|I couldn't open|Warning--|gave return code" "$out"; then
    bad 'bibtex or latexmk reported a problem in example/build.stdout.log'
  else
    ok 'bibtex ran with no missing entry or warning'
  fi
  if grep -qE 'Template render error|TypeError' "$out"; then
    bad 'the template failed to render; any PDF on disk is stale'
  fi
  if grep -q 'Unhandled TEX conversion' "$out"; then
    bad 'a {raw} latex block holds a macro mystmd cannot parse; see README.md "Raw LaTeX: which fence"'
  fi
}

# Each checker's self-test runs first: a PASS from a checker that misses its
# seeded defects is worthless.
run_checker() {
  local s="$ROOT/scripts/$1"; shift
  "$s" --self-test > /dev/null 2>&1 || { bad "$(basename "$s") --self-test failed; run it to see why"; return; }
  if "$s" "$@" > /dev/null 2>&1; then ok "$(basename "$s") $*"; else bad "$(basename "$s") $* failed; run it to see why"; fi
}

build
check_compile_logs
check_build_log
run_checker check-title-gap.sh
run_checker check-math-macros.sh
run_checker check-content.sh
for pdf in "$EX"/exports/*.pdf; do run_checker check-ink.sh "$pdf" 1 0.8; done
verdict "$fail" 'the PDFs rebuild cleanly and pass every TeX-dependent gate.' \
  'see above. If only snapshots differ on purpose, re-record with scripts/check-content.sh --update.'
