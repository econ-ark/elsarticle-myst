#!/usr/bin/env bash
# Check the math macros MyST passes through but loads no package for.
#
#   scripts/check-math-macros.sh              build a fixture page in both classes
#   scripts/check-math-macros.sh --self-test  seed each defect into a copy of the
#                                             template; each must be caught
#
# MyST writes math to the .tex verbatim and loads amsmath and amssymb. Through
# 1.11.0 it loads nothing for \coloneqq (mathtools) or \llbracket, \rrbracket
# (stmaryrd), so without the template's block they are undefined: the build
# exits 0, and "a := b" prints as "ab". The sentinel half fails once MyST loads
# either package itself, so the template's line is deleted rather than carried.

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BODY='# Body

Derivtext $\partial v / \partial a$ inline.
$$\frac{\partial^2 v}{\partial a^2} = 0$$
Engtext $\texttt{ENGINE}_k$ and Ordtext $T(\mathord{\cdot}, x)$ inline.
Symtext $a \coloneqq b$ and $\llbracket x \rrbracket$ and $\mathstrut y$ inline.'

# Write the fixture against template $1 into directory $2, exporting to extension
# $3 (pdf or tex) for both classes. A PDF export is pdf+tex, which keeps the log.
write_fixture() {
  local root=$1 dir=$2 ext=$3 fmt=$3
  [ "$ext" = pdf ] && fmt=pdf+tex
  mkdir -p "$dir"
  cat > "$dir/p.md" <<MD
---
title: Math Macro Fixture
authors:
  - name: Pat Probe
exports:
  - {format: $fmt, template: $root, output: out/cas.$ext}
  - {format: $fmt, template: $root, document_class: elsarticle, output: out/els.$ext}
---

$BODY
MD
}

# Verdict for class $1 from its compile log text $2 and PDF text $3. The double
# brackets extract as J...K from stmaryrd (its font has no Unicode map), as [[...]]
# from the template's fallback, and as U+27E6/U+27E7 from stix.
judge() {
  local cls=$1 log=$2 text=$3
  # Positive control: the line under test reached the PDF at all.
  if ! grep -q 'Symtext' <<<"$text"; then
    bad "$cls: the fixture text is missing from the PDF; the checks below are vacuous"
  elif grep -q 'Undefined control sequence' <<<"$log"; then
    bad "$cls: a math macro is undefined ($(grep -c 'Undefined control sequence' <<<"$log") in the log); it vanishes from the PDF"
  # stix (CAS, when installed) defines \coloneqq as one glyph, U+2254; mathtools
  # only provides it otherwise, as : and =.
  elif ! grep -qE 'a (:=|≔) b' <<<"$text"; then
    bad "$cls: glyph missing: \\coloneqq did not print as := or ≔"
  elif ! grep -qE '(J|\[\[|⟦) ?x ?(K|\]\]|⟧)' <<<"$text"; then
    bad "$cls: glyph missing: \\llbracket x \\rrbracket printed without its brackets"
  else
    ok "$cls: \\coloneqq, \\llbracket, \\rrbracket and the rest compile and print"
  fi
}

check_render() {
  local root=$1 work cls log
  work=$(mktemp -d)
  write_fixture "$root" "$work" pdf
  render_pdf "$work" p.md || bad 'the template render aborted on the fixture'
  for cls in cas els; do
    log="$work/out/${cls}_pdf_logs/$cls.log"
    if [ ! -s "$work/out/$cls.pdf" ] || [ ! -s "$log" ]; then
      bad "$cls: the fixture produced no PDF or no compile log"; continue
    fi
    judge "$cls" "$(<"$log")" "$(pdftotext "$work/out/$cls.pdf" - 2>/dev/null)"
  done
  rm -rf "$work"
}

# $1 is a .tex MyST emitted with the template's block and declarations removed.
check_myst_loads() {
  local tex=$1 pkg
  for pkg in mathtools stmaryrd; do
    if grep -qE "\\\\usepackage(\[[^]]*\])?\{$pkg\}" "$tex"; then
      bad "MyST now loads $pkg itself; delete it from template.tex and template.yml"
    else
      ok "MyST still loads no $pkg, so the template's line is needed"
    fi
  done
}

check_not_dead() {
  local root=$1 tmpl work
  tmpl=$(copy_template "$root")
  perl -0pi -e 's/\\usepackage\{mathtools\}.*?\\makeatother\n//s' "$tmpl/template.tex"
  perl -0pi -e 's/^  - (?:mathtools|stmaryrd)\n//mg' "$tmpl/template.yml"
  if grep -qE 'mathtools|stmaryrd' "$tmpl/template.tex" "$tmpl/template.yml"; then
    bad 'the template block could not be removed from the copy; the sentinel is vacuous'
  else
    work=$(mktemp -d)
    write_fixture "$tmpl" "$work" tex
    if render_tex "$work" p.md && [ -s "$work/out/els.tex" ]; then
      check_myst_loads "$work/out/els.tex"
    else
      bad 'the stripped template did not render the fixture'
    fi
    rm -rf "$work"
  fi
  rm -rf "$(dirname "$tmpl")"
}

run_checks() {
  check_render "$1"
  check_not_dead "$1"
}

do_check() {
  require_pdftotext || return 1
  run_checks "$ROOT"
  verdict "$fail" 'every passed-through math macro is defined, and each package line is still needed.' \
    'see above. Check the mathtools/stmaryrd block in template.tex.'
}

do_self_test() {
  local rc=0 out probe
  expect_control_passes
  seed_defect 'mathtools not loaded' 'undefined' check_render template.tex \
    replace_fixed '\usepackage{mathtools}' ''
  # The whole bracket block, stmaryrd and fallback alike.
  seed_defect 'no definition of the double brackets' 'undefined' check_render template.tex \
    perl -0pi -e 's/\\\@ifundefined\{llbracket\}.*?\n(?=\\makeatother)//s'
  # Each verdict branch at function level: a log with the error, and a PDF
  # missing each glyph while its log is clean.
  local good='Symtext a := b and JxK and y'
  out=$( fail=0; judge probe '! Undefined control sequence.' "$good" )
  expect_caught 'an undefined macro in a log' '^FAIL  probe: a math macro is undefined' "$out"
  out=$( fail=0; judge probe 'clean' 'Symtext ab and JxK and y' )
  expect_caught 'a PDF missing :=' '^FAIL  probe: glyph missing: .coloneqq' "$out"
  out=$( fail=0; judge probe 'clean' 'Symtext a := b and x and y' )
  expect_caught 'a PDF missing the double brackets' '^FAIL  probe: glyph missing: .llbracket' "$out"
  out=$( fail=0; judge probe 'clean' "$good" )
  expect_passes 'a clean log and full glyphs' '^ok    probe' "$out"
  # The sentinel, at function level: MyST loading a package makes the line dead.
  probe=$(mktemp)
  printf '\\usepackage{amsmath}\n\\usepackage[only,llbracket]{stmaryrd}\n' > "$probe"
  out=$( fail=0; check_myst_loads "$probe" )
  expect_caught 'MyST loading stmaryrd itself' '^FAIL  MyST now loads stmaryrd' "$out"
  rm -f "$probe"
  verdict "$rc" 'the math-macro checker rejects every seeded defect and accepts the untouched template.' \
    'the math-macro checker missed a seeded defect; its PASS verdict is worthless.'
}

run_cli "$@"
