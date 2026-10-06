#!/usr/bin/env bash
# Assert that a given PDF page actually has ink on it.
#
# The graphical abstract regression this guards against was invisible to every
# other check: the build exited 0, no LaTeX error was logged, and `pdfimages`
# even listed the image as present on the page. Only rasterising the page and
# measuring it showed that nothing was drawn.
#
#   scripts/check-ink.sh <pdf> <page> <max-tile-luminance>
#   scripts/check-ink.sh --self-test
#
# Measures the DARKEST TILE of a 6x6 grid, not the page mean. Luminance runs
# 0 (black) to 1 (white), so a low number means ink is present somewhere.
#
# The page mean is the obvious metric and it is a trap. The real failure is not
# a blank page but one that keeps its heading, title and author line and loses
# only the image, and those are barely distinguishable by page mean:
#
#   case                     page mean   min tile
#   blank                       1.0000     1.0000
#   text only (the failure)     0.9977     0.9791
#   image present, elsarticle   0.9321     0.3416
#   image present, CAS          0.8544     0.2058
#
# Page mean leaves ~0.008 between pass and fail, so a fourth author or a longer
# title would silently disarm the check. Tiling gives ~0.18 on either side of
# the 0.8 default, because a block image darkens one whole tile while a line of
# text never does.

set -uo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "check-ink: missing $1" >&2; exit 2; }; }
need pdftoppm
if command -v magick >/dev/null 2>&1; then CONVERT=(magick); else
  command -v convert >/dev/null 2>&1 || { echo "check-ink: missing ImageMagick" >&2; exit 2; }
  CONVERT=(convert)
fi

# Darkest cell of a 6x6 grid. `-crop WxH@` splits into that many tiles.
min_tile_of_page() {
  local pdf=$1 page=$2 dir out val rc=0
  dir=$(mktemp -d)
  pdftoppm -f "$page" -l "$page" -r 60 -png "$pdf" "$dir/p" >/dev/null 2>&1
  out=$(find "$dir" -name 'p*.png' | head -1)
  if [ -n "$out" ]; then
    val=$("${CONVERT[@]}" "$out" -crop 6x6@ +repage -format '%[fx:mean]\n' info: 2>/dev/null \
            | sort -g | head -1)
    [ -n "$val" ] && printf '%s' "$val" || rc=1
  else
    rc=1
  fi
  rm -rf "$dir"
  return "$rc"
}

check() {
  local pdf=$1 page=$2 limit=$3 val
  val=$(min_tile_of_page "$pdf" "$page") || { echo "FAIL  $pdf p$page: could not measure"; return 1; }
  # An empty value is NOT zero ink. awk would compare "" against the limit as
  # STRINGS, "" sorts first, and a total measurement failure would report a
  # perfectly black page. Reject anything that is not a number.
  case "$val" in
    ''|*[!0-9.eE+-]*) echo "FAIL  $pdf p$page: measurement produced no number ('$val')"; return 1 ;;
  esac
  if awk -v m="$val" -v l="$limit" 'BEGIN{exit !(m < l)}'; then
    printf 'ok    %s p%s has ink (darkest tile %.4f < %s)\n' "$(basename "$pdf")" "$page" "$val" "$limit"
  else
    printf 'FAIL  %s p%s has no image-sized block of ink (darkest tile %.4f >= %s)\n' \
      "$(basename "$pdf")" "$page" "$val" "$limit"
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
  if check "$dir/blank.pdf" 1 0.8 >/dev/null 2>&1; then
    echo "FAIL  self-test: a blank page was accepted"; rc=1
  else
    echo "ok    self-test: blank page rejected"
  fi
  if check "$dir/inked.pdf" 1 0.8 >/dev/null 2>&1; then
    echo "ok    self-test: inked page accepted"
  else
    echo "FAIL  self-test: an inked page was rejected"; rc=1
  fi
  if check "$dir/textonly.pdf" 1 0.8 >/dev/null 2>&1; then
    echo "FAIL  self-test: heading+title+authors with NO image was accepted"; rc=1
  else
    echo "ok    self-test: text-only page (image missing) rejected"
  fi
  rm -rf "$dir"
  return "$rc"
}

if [ "${1:-}" = "--self-test" ]; then self_test; exit $?; fi
[ $# -eq 3 ] || { echo "usage: $0 <pdf> <page> <max-tile-luminance> | --self-test" >&2; exit 2; }
check "$1" "$2" "$3"
