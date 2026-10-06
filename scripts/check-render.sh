#!/usr/bin/env bash
# Render every sample export to TeX, with no TeX installation.
#
#   scripts/check-render.sh              render all exports of the sample
#   scripts/check-render.sh --self-test  seed a render abort into a copy of the
#                                        template; it must be caught
#
# CI builds no PDF. This is its whole-template render: a copy of the sample with
# each pdf+tex export turned into a tex export, since --tex still runs xelatex for
# pdf+tex. mystmd prints "Exported TeX" and exits 0 when the render aborts.

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Fixed before any seed points ROOT at a template copy, which has no example/.
EXAMPLE="$ROOT/example"

check_render_all() {
  local root=$1 work n tex want
  work=$(mktemp -d)
  tar -C "$EXAMPLE" --exclude=./exports --exclude=./_build -cf - . | tar -C "$work" -xf -
  ROOT_TPL="$root" perl -0pi -e \
    's/format: pdf\+tex/format: tex/g; s{(output: exports/[^\s]+)\.pdf}{$1.tex}g; s{template: \.\.}{template: $ENV{ROOT_TPL}}g' \
    "$work/sample-article.md"
  want=$(grep -c 'output: exports/.*\.tex' "$work/sample-article.md")
  [ "$want" -ge 6 ] || { bad "only $want tex exports after rewriting the sample; expected 6"; rm -rf "$work"; return; }
  if ! render_page "$work" sample-article.md tex; then
    bad 'the template render aborted on the sample'
  fi
  if grep -q 'Unhandled TEX conversion' "$work/build.log"; then
    bad 'a {raw} latex block holds a macro mystmd cannot parse; see README.md "Raw LaTeX: which fence"'
  fi
  n=0
  for tex in "$work"/exports/*.tex; do
    [ -s "$tex" ] || continue
    if grep -q '\\documentclass' "$tex" && grep -q '\\end{document}' "$tex"; then
      n=$((n + 1))
    else
      bad "$(basename "$tex"): rendered without \\documentclass or \\end{document}"
    fi
  done
  if [ "$n" -eq "$want" ]; then
    ok "all $n sample exports render to complete TeX"
  else
    bad "$n of $want sample exports rendered to complete TeX"
  fi
  rm -rf "$work"
}

run_checks() { check_render_all "$1"; }

do_check() {
  run_checks "$ROOT"
  verdict "$fail" 'every sample export renders to TeX.' \
    'see above. Check template.tex against the sample.'
}

do_self_test() {
  local rc=0
  expect_control_passes
  seed_defect 'a template render abort' 'render aborted' run_checks template.tex \
    replace_fixed '[-CONTENT-]' '[- CONTENT | no_such_filter -]'
  verdict "$rc" 'the render checker rejects a render abort and accepts the untouched template.' \
    'the render checker missed a seeded defect; its PASS verdict is worthless.'
}

run_cli "$@"
