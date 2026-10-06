#!/usr/bin/env bash
# Check the CAS title page's space below the abstract and keywords block.
#
#   scripts/check-title-gap.sh              build four fixture PDFs and assert
#   scripts/check-title-gap.sh --self-test  seed each past defect into a copy of
#                                           the template; each must be caught
#
# CAS sets the keyword column beside the abstract and then has to skip down past
# whichever of the two is longer. A fixed guess at that skip left 85pt of blank
# space under a long abstract, and almost none under a short one, where the
# keywords ran into the rule. The gap is the distance from the block's lowest
# line to the first heading. It must not depend on the abstract's length.

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LONG='Heterogeneous-agent models with multiple decisions face a computational dilemma. Joint optimization over all choices is slow, and strong separability restrictions speed computation but rule out interesting interactions. The method decomposes the problem into sequential stages so that each stage can exploit a closed-form inversion, chaining speed gains across decisions wherever separable utility or an invertible transition permits it. The resulting curvilinear grids require interpolation that respects their structure, which the companion interpolator exploits through the index structure inherited from exogenous grids. In the canonical household block it solves an order of magnitude faster than the nested method in serial.'
SHORT='A short abstract of one sentence.'
# Abstracts of different lengths may differ by a line's leading or so.
TOL=6
# Below this the keyword column crowds the rule under the block.
MIN_GAP=12

# Build fixture $3 ($LONG or $SHORT text in $4) in $2 columns against template
# $1 and print its gap in pt, or NOPDF.
gap_of() {
  local root=$1 cols=$2 dir=$3 abs=$4
  mkdir -p "$dir"
  cat > "$dir/p.md" <<MD
---
title: Title Gap Fixture
authors:
  - name: Pat Probe
abstract: $abs
keywords: [endogenous grid method, dynamic programming, interpolation, computational economics, one, two]
tags: [C61, C63, E21]
exports:
  - {format: pdf+tex, template: $root, output: out/c.pdf, columns: $cols}
---

# Introduction

Body text.
MD
  ( cd "$dir" && myst build --pdf p.md > build.log 2>&1 )
  if [ ! -s "$dir/out/c.pdf" ]; then echo NOPDF; return; fi
  pdftotext -f 1 -l 1 -bbox "$dir/out/c.pdf" "$dir/bbox.html"
  # Block lines are every word written before the heading's "1.", wherever it
  # lands: a keyword line pushed below the heading top must count, as overlap.
  awk '/<word/ { match($0, /yMin="[0-9.]+"/); y0 = substr($0, RSTART+6, RLENGTH-7) + 0
                 match($0, /yMax="[0-9.]+"/); y1 = substr($0, RSTART+6, RLENGTH-7) + 0
                 w = $0; sub(/.*">/, "", w); sub(/<.*/, "", w)
                 n++; Y1[n] = y1
                 if (w == "Introduction" && !h) { h = y0; hn = n } }
       END { if (!h) { print "NOHEADING"; exit }
             for (i = 1; i < hn - 1; i++) if (Y1[i] > low) low = Y1[i]
             printf "%.1f\n", h - low }' "$dir/bbox.html"
}

check_layout() {
  local root=$1 cols=$2 work long short
  work=$(mktemp -d)
  # Build the long and short fixtures side by side.
  gap_of "$root" "$cols" "$work/long" "$LONG" > "$work/long.gap" &
  gap_of "$root" "$cols" "$work/short" "$SHORT" > "$work/short.gap" &
  wait
  long=$(cat "$work/long.gap"); short=$(cat "$work/short.gap")
  rm -rf "$work"
  if ! [[ $long =~ ^-?[0-9.]+$ && $short =~ ^-?[0-9.]+$ ]]; then
    bad "$cols column: a fixture did not build or has no heading (long: $long, short: $short)"
    return
  fi
  # Both verdicts, independently: a defect can trip either or both.
  local clean=1
  if awk -v a="$long" -v b="$short" -v m=$MIN_GAP 'BEGIN { exit !(a < m || b < m) }'; then
    bad "$cols column: the title block crowds the rule below it (long ${long}pt, short ${short}pt, at least ${MIN_GAP}pt expected)"
    clean=0
  fi
  if awk -v a="$long" -v b="$short" -v t=$TOL 'BEGIN { d = a - b; exit !(d > t || d < -t) }'; then
    bad "$cols column: the gap under the title block depends on the abstract's length (long ${long}pt, short ${short}pt)"
    clean=0
  fi
  [ "$clean" -eq 1 ] && ok "$cols column: the same gap under a long and a short abstract (${long}pt, ${short}pt)"
}

run_checks() {
  check_layout "$1" single
  check_layout "$1" double
}

do_check() {
  require_pdftotext || return 1
  run_checks "$ROOT"
  verdict "$fail" 'the CAS title block leaves the same space whatever the abstract length.' \
    'see above. Check the Abstract environment in cas-common.sty.'
}

do_self_test() {
  local rc=0
  expect_control_passes
  # Fixed strings, since perl reads \l as an escape even inside \Q...\E.
  # 1.4.1's fixed guess: skip the keyword height less five lines, always.
  seed_defect 'a fixed skip under the abstract' 'depends on the abstract' run_checks cas-common.sty \
    sd -F -- '- \l_tmpb_dim } }' '- 5\baselineskip } }'
  # Upstream does not skip at all. A short abstract then lets the keywords overrun.
  seed_defect 'no skip past a longer keyword column' 'crowds the rule' run_checks cas-common.sty \
    sd -F -- '{ \skip_vertical:n { \g_stm_keybox_ht_dim - \l_tmpb_dim } }' '{ }'
  verdict "$rc" 'the title-gap checker rejects every seeded defect and accepts the untouched template.' \
    'the title-gap checker missed a seeded defect; its PASS verdict is worthless.'
}

case "${1:-}" in
  --self-test) do_self_test ;;
  '') do_check ;;
  *) echo "usage: $0 [--self-test]" >&2; exit 2 ;;
esac
