#!/usr/bin/env bash
# Assert that the parts this template shares with econ-ark-myst (MyST's seven
# known parts plus `declaration`) appear in the .tex where they belong, whichever
# way a paper writes them. MyST hands a template only the parts
# it declares and drops the rest silently, so a part missing from template.yml,
# or declared and never printed, vanishes from the PDF at exit 0.
#
#   scripts/check-parts.sh              build the fixtures and check them
#   scripts/check-parts.sh --self-test  seed one defect per check into a copy
#                                       of the template; each must be caught

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Build one fixture page against template $1 into a fresh directory, left in
# WORK. Every fixture exports CAS to out/cas.tex and elsarticle to out/els.tex.
build_fixture() {
  local root=$1 front=$2 body=$3
  WORK=$(mktemp -d)
  cat > "$WORK/p.md" <<MD
---
title: Parts Fixture
authors:
  - name: Pat Probe
$front
exports:
  - {format: tex, template: $root, output: out/cas.tex}
  - {format: tex, template: $root, document_class: elsarticle, output: out/els.tex}
---

$body
MD
  render_tex "$WORK" p.md || { rm -rf "$WORK"; return 1; }
}

# Each pattern must appear, and the first occurrence of each must follow the
# first occurrence of the one before it.
check_order() {
  local file=$1 label=$2 body prev=0 n pat
  shift 2
  body=$(strip_comments "$file")
  for pat in "$@"; do
    n=$(grep -nF -- "$pat" <<<"$body" | head -1 | cut -d: -f1)
    if [ -z "$n" ]; then bad "$label: missing: $pat"; return; fi
    if [ "$n" -le "$prev" ]; then bad "$label: out of order: $pat"; return; fi
    prev=$n
  done
  ok "$label"
}

# One \item line per point inside the highlights environment, each point on
# exactly one of them, and no list nested inside.
check_keypoints() {
  local file=$1 label=$2 block items m
  shift 2
  block=$(strip_comments "$file" | awk '/\\begin\{highlights\}/{f=1; next} /\\end\{highlights\}/{f=0} f')
  items=$(grep -c '^\\item ' <<<"$block")
  if [ "$items" -ne "$#" ]; then bad "$label: $items \\item line(s) for $# point(s)"; return; fi
  if grep -q 'itemize' <<<"$block"; then bad "$label: a list nested inside highlights"; return; fi
  for m in "$@"; do
    if [ "$(grep -c "^\\\\item .*$m" <<<"$block")" -ne 1 ]; then
      bad "$label: '$m' is not on exactly one \\item"; return
    fi
  done
  ok "$label"
}

check_absent() {
  local file=$1 label=$2 body pat
  shift 2
  body=$(strip_comments "$file")
  for pat in "$@"; do
    if grep -qF -- "$pat" <<<"$body"; then bad "$label: emitted with no content: $pat"; return; fi
  done
  ok "$label"
}

# Run check $2 on both classes' output. $1 labels the fixture.
both_classes() {
  local fixture=$1 cls f
  shift
  for cls in cas els; do
    f="$WORK/out/$cls.tex"
    if [ ! -s "$f" ]; then bad "$fixture ($cls): produced no .tex"; continue; fi
    "$@" "$f" "$cls"
  done
}

# Every part written in the frontmatter, as top-level keys where MyST takes
# them there. The body contains an epigraph DIRECTIVE, which must stay in the
# body now that `epigraph` is also a declared part.
FRONT_ALL='abstract: ABSTRACTMARK opens the abstract.
summary: SUMMARYMARK says it plainly.
dedication: DEDICATIONMARK to a reader.
epigraph: EPIGRAPHMARK is a quotation. Someone
data_availability: DATAMARK is available on request.
acknowledgments: ACKMARK thanks a reviewer.
keypoints:
  - Yamlpointone holds the first point.
  - Yamlpointtwo holds the second point.
  - Yamlpointthree holds the third point.
parts:
  declaration: DECLMARK declares no competing interests.'
BODY_ALL='# Body

Text before.

:::{epigraph}
DIRECTIVEQUOTE stays in the body.

Einstein
:::'

# The environments named here are also the ones none_checks forbids, so these
# order checks are the positive control for that absence check.
all_parts_checks() {
  local f=$1 cls=$2 front_end=$'\\end{frontmatter}' after_body=(DIRECTIVEQUOTE)
  if [ "$cls" = cas ]; then front_end=$'\\maketitle'; after_body+=($'\\printcredits'); fi
  check_order "$f" "summary runs in after the abstract ($cls)" \
    '\begin{abstract}' ABSTRACTMARK '\textbf{Summary.} SUMMARYMARK' '\end{abstract}'
  check_order "$f" "acknowledgments as a first-page note ($cls)" '\nonumnote{ACKMARK' "$front_end"
  check_order "$f" "dedication and epigraph precede the first heading; the body epigraph stays ($cls)" \
    "$front_end" '\begin{center}\itshape' DEDICATIONMARK '\begin{flushright}' EPIGRAPHMARK \
    '\section{Body' DIRECTIVEQUOTE
  check_order "$f" "declarations, then data availability, after the body and before the references ($cls)" \
    "${after_body[@]}" '\section*{Declarations}' DECLMARK '\section*{Data Availability}' DATAMARK '\bibliographystyle'
  check_keypoints "$f" "keypoints as a YAML list ($cls)" Yamlpointone Yamlpointtwo Yamlpointthree
}

check_all() {
  if ! build_fixture "$1" "$FRONT_ALL" "$BODY_ALL"; then bad 'all parts: the template render aborted'; return; fi
  both_classes 'all parts' all_parts_checks
  rm -rf "$WORK"
}

# Keypoints written as a bullet list in a part block. Before `as_list`, the
# template split the rendered list on newlines and emitted broken LaTeX.
BODY_BLOCK='+++ {"part": "keypoints"}

- Blockpointone holds the first point.
- Blockpointtwo holds the *second* point.
- Blockpointthree holds the third point.

+++

# Body

Text.'

block_checks() {
  check_keypoints "$1" "keypoints as a bullet list in a part block ($2)" Blockpointone Blockpointtwo Blockpointthree
}

check_block() {
  if ! build_fixture "$1" '' "$BODY_BLOCK"; then bad 'keypoints block: the template render aborted'; return; fi
  both_classes 'keypoints block' block_checks
  rm -rf "$WORK"
}

# parts.highlights takes precedence over keypoints.
BODY_PRECEDENCE='+++ {"part": "highlights"}

:::{raw:latex}
\item Winningpoint is raw LaTeX.
:::

+++

# Body

Text.'

precedence_checks() {
  check_keypoints "$1" "highlights wins over keypoints ($2)" Winningpoint
  check_absent "$1" "keypoints yield to highlights ($2)" Losingpoint
}

check_precedence() {
  if ! build_fixture "$1" $'keypoints:\n  - Losingpoint must not print.' "$BODY_PRECEDENCE"; then
    bad 'highlights precedence: the template render aborted'; return
  fi
  both_classes 'highlights precedence' precedence_checks
  rm -rf "$WORK"
}

# No part supplied: nothing may print, not even a heading or an empty block.
none_checks() {
  check_absent "$1" "no parts, no furniture ($2)" '\begin{abstract}' '\textbf{Summary.}' \
    '\begin{highlights}' '\begin{center}\itshape' '\begin{flushright}' \
    '\section*{Declarations}' '\section*{Data Availability}'
}

check_none() {
  if ! build_fixture "$1" '' $'# Body\n\nText.'; then bad 'no parts: the template render aborted'; return; fi
  both_classes 'no parts' none_checks
  rm -rf "$WORK"
}

# Pins MyST behaviour that README "Document Parts" warns about: with no explicit
# summary, a body section titled exactly "Summary" moves into the abstract.
implicit_checks() {
  check_order "$1" "a body section titled Summary moves into the abstract ($2)" \
    '\begin{abstract}' IMPLICITSUMMARY '\end{abstract}' '\section{Introduction'
}

check_implicit() {
  if ! build_fixture "$1" '' $'# Introduction\n\nText.\n\n# Summary\n\nIMPLICITSUMMARY closes the paper.'; then
    bad 'implicit summary: the template render aborted'; return
  fi
  both_classes 'implicit summary' implicit_checks
  rm -rf "$WORK"
}

run_checks() {
  check_all "$1"
  check_block "$1"
  check_precedence "$1"
  check_none "$1"
  check_implicit "$1"
}

do_check() {
  run_checks "$ROOT"
  if [ "$fail" -eq 0 ]; then
    echo 'PASS: every declared part reaches the .tex where it belongs.'
  else
    echo 'FAIL: see above. Check parts: in template.yml and where template.tex prints each one.'
  fi
  return "$fail"
}

do_self_test() {
  local rc=0 out
  out=$( fail=0; run_checks "$ROOT" 2>&1 )
  if grep -q '^FAIL' <<<"$out"; then
    printf '%s\n' "$out"
    printf 'FAIL  control: the untouched template does NOT pass; the seeds below prove nothing\n'
    rc=1
  else
    printf 'ok    control: the untouched template passes\n'
  fi
  seed_defect 'all points joined into one \item' 'item line' check_block template.tex \
    perl -0pi -e 's/\Q[# for point in parts.keypoints #]\E\n\Q\item [-point-]\E\n\Q[# endfor #]\E/\\item [-parts.keypoints | join(" ")-]/'
  seed_defect 'keypoints without as_list' 'item line' check_block template.yml \
    perl -0pi -e 's/\n    as_list: true//'
  seed_defect 'an undeclared part is dropped' 'dedication and epigraph precede' check_all template.yml \
    perl -0pi -e 's/^  - id: epigraph\n(?:    .*\n)+//m'
  seed_defect 'a declared part never printed' 'SUMMARYMARK' check_all template.tex \
    perl -0pi -e 's/\Q[# if parts.summary #]\E/[# if false #]/'
  seed_defect 'the Declarations heading dropped' 'Declarations' check_all template.tex \
    perl -0pi -e 's/\Q\section*{Declarations}\E\n//'
  seed_defect 'a heading printed with no content' 'Data Availability' check_none template.tex \
    perl -0pi -e 's/\Q[# if parts.data_availability #]\E\n(\Q\section*{Data Availability}\E\n)/$1\[# if parts.data_availability #]\n/'
  seed_defect 'highlights no longer win' 'Losingpoint' check_precedence template.tex \
    perl -0pi -e 's/\Q[# if parts.highlights #]\E/[# if false #]/'
  # elsarticle has no \printcredits to order against, so the body itself must
  # anchor its declarations. The seed misplaces them for elsarticle alone.
  seed_defect 'elsarticle declarations printed before the body' 'before the references (els)' check_all template.tex \
    perl -0pi -e 's/\Q[# if parts.declaration #]\E/[# if parts.declaration and options.document_class != "elsarticle" #]/; s/(\Q[-CONTENT-]\E)/[# if parts.declaration and options.document_class == "elsarticle" #]\n\\section*{Declarations}\n[-parts.declaration-]\n[# endif #]\n$1/'
  if [ "$rc" -eq 0 ]; then
    echo 'PASS: the parts checker rejects every seeded defect and accepts the untouched template.'
  else
    echo "FAIL: the parts checker missed a seeded defect; its PASS verdict is worthless."
  fi
  return "$rc"
}

case "${1:-}" in
  --self-test) do_self_test ;;
  ""|--check)  do_check ;;
  *) echo "usage: $0 [--check|--self-test]" >&2; exit 2 ;;
esac
