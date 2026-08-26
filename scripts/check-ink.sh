#!/usr/bin/env bash
# Assert that a given PDF page actually has ink on it.
#
# The graphical abstract regression this guards against was invisible to every
# other check: the build exited 0, no LaTeX error was logged, and `pdfimages`
# even listed the image as present on the page. Only rasterising the page and
# measuring it showed that nothing was drawn.
#
#   scripts/check-ink.sh <pdf> <page> <max-mean-luminance>
#   scripts/check-ink.sh --self-test
#
# Mean luminance runs 0 (black) to 1 (white). A blank page measures ~0.9995, so
# a threshold of 0.99 passes any page with real content and fails an empty one.

set -uo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "check-ink: missing $1" >&2; exit 2; }; }
need pdftoppm
MAGICK=$(command -v magick || command -v identify) || { echo "check-ink: missing ImageMagick" >&2; exit 2; }
identify_mean() {
  if [[ "$MAGICK" == *magick ]]; then "$MAGICK" identify -format '%[fx:mean]' "$1"
  else "$MAGICK" -format '%[fx:mean]' "$1"; fi
}

mean_of_page() {
  local pdf=$1 page=$2 dir out
  dir=$(mktemp -d)
  pdftoppm -f "$page" -l "$page" -r 60 -png "$pdf" "$dir/p" >/dev/null 2>&1
  out=$(find "$dir" -name 'p*.png' | head -1)
  [ -n "$out" ] || { rm -rf "$dir"; return 1; }
  identify_mean "$out"
  rm -rf "$dir"
}

check() {
  local pdf=$1 page=$2 limit=$3 mean
  mean=$(mean_of_page "$pdf" "$page") || { echo "FAIL  $pdf p$page: could not rasterise"; return 1; }
  if awk -v m="$mean" -v l="$limit" 'BEGIN{exit !(m < l)}'; then
    printf 'ok    %s p%s has ink (mean %.6f < %s)\n' "$(basename "$pdf")" "$page" "$mean" "$limit"
  else
    printf 'FAIL  %s p%s looks BLANK (mean %.6f >= %s)\n' "$(basename "$pdf")" "$page" "$mean" "$limit"
    return 1
  fi
}

# A threshold checker that never rejects is worthless, so prove it rejects a
# genuinely blank page before any real verdict is trusted.
self_test() {
  local dir rc=0
  dir=$(mktemp -d)
  printf '\\documentclass{article}\\begin{document}\\thispagestyle{empty}\\mbox{}\\end{document}\n' > "$dir/blank.tex"
  printf '\\documentclass{article}\\begin{document}\\thispagestyle{empty}\\rule{5in}{4in}\\end{document}\n' > "$dir/inked.tex"
  ( cd "$dir" && pdflatex -interaction=nonstopmode blank.tex >/dev/null 2>&1
                 pdflatex -interaction=nonstopmode inked.tex >/dev/null 2>&1 )
  if check "$dir/blank.pdf" 1 0.99 >/dev/null 2>&1; then
    echo "FAIL  self-test: a blank page was accepted"; rc=1
  else
    echo "ok    self-test: blank page rejected"
  fi
  if check "$dir/inked.pdf" 1 0.99 >/dev/null 2>&1; then
    echo "ok    self-test: inked page accepted"
  else
    echo "FAIL  self-test: an inked page was rejected"; rc=1
  fi
  rm -rf "$dir"
  return "$rc"
}

if [ "${1:-}" = "--self-test" ]; then self_test; exit $?; fi
[ $# -eq 3 ] || { echo "usage: $0 <pdf> <page> <max-mean-luminance> | --self-test" >&2; exit 2; }
check "$1" "$2" "$3"
