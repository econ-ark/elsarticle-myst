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

# Build a fixture against template $1 and run check $5 on both classes' output.
# $2 labels the fixture, $3 and $4 are its frontmatter lines and its body.
run_fixture() {
  local root=$1 label=$2 front=$3 body=$4 check=$5 cls f
  if ! build_fixture "$root" "$front" "$body"; then bad "$label: the template render aborted"; return; fi
  for cls in cas els; do
    f="$WORK/out/$cls.tex"
    if [ ! -s "$f" ]; then bad "$label ($cls): produced no .tex"; continue; fi
    "$check" "$f" "$cls"
  done
  rm -rf "$WORK"
}

# Every part written in the frontmatter, as top-level keys where MyST takes
# them there. The body contains an epigraph DIRECTIVE, which must stay in the
# body now that `epigraph` is also a declared part.
FRONT_ALL='abstract: ABSTRACTMARK opens the abstract.
summary: SUMMARYMARK says it plainly.
dedication: DEDICATIONMARK to a reader.
epigraph: |
  EPIGRAPHMARK is a quotation.

  --- CITEMARK
data_availability: DATAMARK is available on request.
acknowledgments: ACKMARK thanks a reviewer.
keypoints:
  - Yamlpointone holds the first point.
  - Yamlpointtwo holds the second point.
  - Yamlpointthree holds the third point.
parts:
  title_note: TITLENOTEMARK funds the work.
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
  check_order "$f" "abstract in its block ($cls)" '\begin{abstract}' ABSTRACTMARK '\end{abstract}'
  check_order "$f" "acknowledgments as a first-page note ($cls)" '\nonumnote{ACKMARK' "$front_end"
  if [ "$cls" = cas ]; then
    check_order "$f" "title note, then dedication, as title footnotes ($cls)" \
      '\tnotemark[1,2]' '\tnotetext[1]{TITLENOTEMARK' '\tnotetext[2]{DEDICATIONMARK' "$front_end"
  else
    check_order "$f" "title note, then dedication, as title footnotes ($cls)" \
      '\tnoteref{tn1,tn2}' '\tnotetext[tn1]{TITLENOTEMARK' '\tnotetext[tn2]{DEDICATIONMARK' "$front_end"
  fi
  check_order "$f" "summary and epigraph open the body as a plain section and a quote; the body epigraph stays ($cls)" \
    "$front_end" '\section*{Summary}' SUMMARYMARK \
    '\begin{quote}' EPIGRAPHMARK '\end{quote}' '\section{Body' DIRECTIVEQUOTE
  check_order "$f" "the epigraph's citation is set apart, flush right ($cls)" \
    '\itshape EPIGRAPHMARK' '{\raggedleft\upshape --- CITEMARK\par}' '\end{quote}'
  check_order "$f" "declarations, then data availability, after the body and before the references ($cls)" \
    "${after_body[@]}" '\section*{Declarations}' DECLMARK '\section*{Data Availability}' DATAMARK '\bibliographystyle'
  check_keypoints "$f" "keypoints as a YAML list ($cls)" Yamlpointone Yamlpointtwo Yamlpointthree
}

check_all() { run_fixture "$1" 'all parts' "$FRONT_ALL" "$BODY_ALL" all_parts_checks; }

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

check_block() { run_fixture "$1" 'keypoints block' '' "$BODY_BLOCK" block_checks; }

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
  run_fixture "$1" 'highlights precedence' $'keypoints:\n  - Losingpoint must not print.' \
    "$BODY_PRECEDENCE" precedence_checks
}

# No part supplied: nothing may print, not even a heading or an empty block.
none_checks() {
  check_absent "$1" "no parts, no furniture ($2)" '\begin{abstract}' '\begin{highlights}' \
    '\section*{Summary}' '\tnote' '\begin{quote}' \
    '\section*{Declarations}' '\section*{Data Availability}'
}

check_none() { run_fixture "$1" 'no parts' '' $'# Body\n\nText.' none_checks; }

# A dedication with no title note takes the first title-note slot alone.
dedication_only_checks() {
  if [ "$2" = cas ]; then
    check_order "$1" "a lone dedication is title note 1 ($2)" '\tnotemark[1]' '\tnotetext[1]{LONEDEDICATION'
  else
    check_order "$1" "a lone dedication is title note 1 ($2)" '\tnoteref{tn1}' '\tnotetext[tn1]{LONEDEDICATION'
  fi
}

check_dedication_only() {
  run_fixture "$1" 'dedication alone' 'dedication: LONEDEDICATION to a reader.' $'# Body\n\nText.' dedication_only_checks
}

# Pins MyST behaviour that README "Document Parts" warns about: with no explicit
# summary, a closing body section titled "Summary" moves to the front.
implicit_checks() {
  check_order "$1" "a body section titled Summary moves to the front ($2)" \
    '\section*{Summary}' IMPLICITSUMMARY '\section{Introduction'
}

check_implicit() {
  run_fixture "$1" 'implicit summary' '' \
    $'# Introduction\n\nText.\n\n# Summary\n\nIMPLICITSUMMARY closes the paper.' implicit_checks
}

# An epigraph written as a blockquote in a part block: MyST sets it as a figure
# holding a quote and a \caption* citation. Wrapping that figure in a second
# quote is a fatal "Not in outer par mode".
BODY_EPIGRAPH_BLOCK='+++ {"part": "epigraph"}

> BLOCKQUOTEMARK is quoted.
>
> -- BLOCKBYLINE

+++

# Body

Text.'

epigraph_block_checks() {
  local flat
  check_order "$1" "a blockquote epigraph keeps its citation, before the first heading ($2)" \
    BLOCKQUOTEMARK '\caption*{BLOCKBYLINE}' '\section{Body'
  flat=$(strip_comments "$1" | tr '\n' ' ')
  # A figure opened while a quote is still open, whatever sits between them.
  if grep -qP '\\begin\{quote\}(?:(?!\\end\{quote\}).)*\\begin\{figure\}' <<<"$flat"; then
    bad "a blockquote epigraph is wrapped in a second quote ($2)"
  else
    ok "a blockquote epigraph is not wrapped twice ($2)"
  fi
}

check_epigraph_block() { run_fixture "$1" 'epigraph block' '' "$BODY_EPIGRAPH_BLOCK" epigraph_block_checks; }

run_checks() {
  check_all "$1"
  check_epigraph_block "$1"
  check_block "$1"
  check_precedence "$1"
  check_none "$1"
  check_dedication_only "$1"
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
  seed_defect 'an undeclared part is dropped' 'summary and epigraph open the body' check_all template.yml \
    perl -0pi -e 's/^  - id: epigraph\n(?:    .*\n)+//m'
  seed_defect 'a declared part never printed' 'missing: \\section\*{Summary}' check_all template.tex \
    perl -0pi -e 's/\Q[# if parts.summary #]\E/[# if false #]/'
  seed_defect 'the Declarations heading dropped' 'Declarations' check_all template.tex \
    perl -0pi -e 's/\Q\section*{Declarations}\E\n//'
  seed_defect 'a heading printed with no content' 'Data Availability' check_none template.tex \
    perl -0pi -e 's/\Q[# if parts.data_availability #]\E\n(\Q\section*{Data Availability}\E\n)/$1\[# if parts.data_availability #]\n/'
  seed_defect 'a blockquote epigraph wrapped twice' 'wrapped in a second quote' check_epigraph_block template.tex \
    perl -0pi -e 's/\Q[# if parts.epigraph and '"'"'\\begin{quote}'"'"' in parts.epigraph #]\E/[# if false #]/'
  seed_defect 'the epigraph citation left inside the quotation' 'citation is set apart' check_all template.tex \
    perl -0pi -e 's/\Qepi_cite.startsWith("--")\E/false/'
  seed_defect 'a lone dedication numbered as if a title note preceded it' 'a lone dedication is title note 1' check_dedication_only template.tex \
    perl -0pi -e 's/\Qset ded_n = 2 if parts.title_note else 1\E/set ded_n = 2/'
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
