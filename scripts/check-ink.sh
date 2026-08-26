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
# Mean luminance runs 0 (black) to 1 (white). The operating point is tighter
# than it looks: the real failure mode is not an empty page but a page that
# still has its heading, title and author line and is only missing the image,
# which measures ~0.9970 against ~0.9995 for a truly blank page and ~0.93-0.86
# when the image is present. 0.99 sits in that gap, so three lines of text are
# correctly NOT enough ink to pass.

set -uo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "check-ink: missing $1" >&2; exit 2; }; }
need pdftoppm
MAGICK=$(command -v magick || command -v identify) || { echo "check-ink: missing ImageMagick" >&2; exit 2; }
identify_mean() {
  if [[ "$MAGICK" == *magick ]]; then "$MAGICK" identify -format '%[fx:mean]' "$1"
  else "$MAGICK" -format '%[fx:mean]' "$1"; fi
}

mean_of_page() {
  local pdf=$1 page=$2 dir out rc=0
  dir=$(mktemp -d)
  pdftoppm -f "$page" -l "$page" -r 60 -png "$pdf" "$dir/p" >/dev/null 2>&1
  out=$(find "$dir" -name 'p*.png' | head -1)
  if [ -n "$out" ]; then identify_mean "$out" || rc=1; else rc=1; fi
  rm -rf "$dir"
  return "$rc"
}

check() {
  local pdf=$1 page=$2 limit=$3 mean
  mean=$(mean_of_page "$pdf" "$page") || { echo "FAIL  $pdf p$page: could not rasterise"; return 1; }
  # An empty mean is NOT zero ink. awk would compare "" against "0.99" as
  # strings, "" sorts first, and a total measurement failure would report a
  # perfectly black page. Reject anything that is not a number.
  case "$mean" in
    ''|*[!0-9.]*) echo "FAIL  $pdf p$page: measurement produced no number ('$mean')"; return 1 ;;
  esac
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
  # The fixture that matters: heading + title + authors and NO image, i.e. the
  # actual shape of the regression. Without it the threshold could drift up to
  # ~0.996 and still pass the two synthetic extremes while catching nothing.
  printf '\\documentclass{article}\\begin{document}\\thispagestyle{empty}\n\\noindent{\\Large Graphical Abstract}\\par\\medskip\n\\noindent\\textbf{A Representative Title That Wraps Onto Two Lines In The Real Document}\\par\\medskip\n\\noindent A N Author, A N Other, A Third Person\\par\n\\end{document}\n' > "$dir/textonly.tex"
  ( cd "$dir" && for t in blank inked textonly; do
                   pdflatex -interaction=nonstopmode "$t.tex" >/dev/null 2>&1
                 done )
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
  if check "$dir/textonly.pdf" 1 0.99 >/dev/null 2>&1; then
    echo "FAIL  self-test: heading+title+authors with NO image was accepted"; rc=1
  else
    echo "ok    self-test: text-only page (image missing) rejected"
  fi
  rm -rf "$dir"
  return "$rc"
}

if [ "${1:-}" = "--self-test" ]; then self_test; exit $?; fi
[ $# -eq 3 ] || { echo "usage: $0 <pdf> <page> <max-mean-luminance> | --self-test" >&2; exit 2; }
check "$1" "$2" "$3"
