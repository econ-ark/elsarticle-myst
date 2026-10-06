#!/usr/bin/env bash
# Round-trip LaTeX specials through the real template and assert they come out
# escaped. This exists because the escaping was DOCUMENTED and never ASSERTED:
# title, subtitle, keywords, tags and author names were raw for six releases,
# which produced a titleless PDF from a title containing '%'.
#
#   scripts/check-escaping.sh              build the fixture and check it
#   scripts/check-escaping.sh --self-test  rejection test: feed the checker a
#                                          known-raw .tex and confirm it FAILS
#
# Three directions are asserted, and the last two matter as much as the first:
#   ESCAPED     raw frontmatter strings the template interpolates itself
#   MATH KEPT   title, subtitle, short_title and keywords take esctext(), which
#               escapes & % # only, so '$x_1$' still typesets as mathematics
#   UNTOUCHED   fields MyST pre-renders to LaTeX (abstract, every parts.*),
#               which arrive already escaped and would be DOUBLE-escaped if
#               the template ran an escaper over them
#
# Emails and URLs are deliberately excluded. Escaping '_' or '%' there breaks
# the link, so they are emitted verbatim; see README.md "Escaping".

set -uo pipefail

ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}

fail=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }

# Every string below carries '&', '%' and '_'. '%' is the dangerous one: raw, it
# comments out the rest of the line INCLUDING the closing brace, so the macro
# swallows the following lines and the field vanishes from the PDF.
write_fixture() {
  local dir=$1
  mkdir -p "$dir"
  cat > "$dir/refs.bib" <<'BIB'
@article{probe2020,
  title = {A Probe Entry},
  author = {Probe, Pat},
  journal = {Journal of Escaping},
  year = {2020}
}
BIB
  cat > "$dir/fixture.md" <<MD
---
title: "Risk & Return: 50% of \$x_1\$"
subtitle: "Subtitle & 10%"
short_title: "Risk & Return 50%"
authors:
  - name: "Smith & Co_Ltd"
    note: "Note with & and 50% and _under"
    roles: ["Writing & 50%_editing"]
    affiliations:
      - id: probeaff
affiliations:
  - id: probeaff
    name: "Smith & Co_Ltd"
    department: "R&D 50%_unit"
abstract: "Costs rose 50% & margins fell; see Cost_Basis."
keywords: ["K&W", "50% risk", "\$\\\\alpha\$-mixing"]
tags: ["D&14", "C6%1"]
venue:
  title: "Journal of R&D 50%"
bibliography: [refs.bib]
parts:
  title_note: "Funded by R&D 50% grant_x"
exports:
  - format: tex
    template: $ROOT
    output: out/cas.tex
  - format: tex
    template: $ROOT
    document_class: elsarticle
    output: out/els.tex
---

# Body

Body text with 50% & Cost_Basis. Cites @probe2020.
MD
}

# Strip EVERY comment line, '%%' and single '%' alike. A comment must never
# satisfy a presence assertion nor trip an absence one, and the template's own
# comments legitimately contain '&', '%' and '$x_1$' while discussing them.
strip_comments() { grep -v '^[[:space:]]*%' "$1"; }

# Assert that $2 appears in the emitted body and $3 does not.
expect() {
  local file=$1 want=$2 forbid=$3 label=$4 body
  body=$(strip_comments "$file")
  if ! grep -qF -- "$want" <<<"$body"; then
    bad "$label: expected escaped form not found: $want"
    return
  fi
  if grep -qF -- "$forbid" <<<"$body"; then
    bad "$label: raw form still present: $forbid"
    return
  fi
  ok "$label"
}

check_tex() {
  local cas=$1 els=$2

  # ESCAPED with esctext() (& % # only), so the math survives.
  expect "$cas" '\title[mode=title]{Risk \& Return: 50\% of $x_1$}' \
                'Risk & Return: 50% of' 'title keeps math, escapes & and %'
  expect "$cas" '\title[mode=sub]{Subtitle \& 10\%}' \
                'Subtitle & 10%' 'subtitle (cas)'
  expect "$cas" '\shorttitle{Risk \& Return 50\%}' \
                'Risk & Return 50%' 'short_title'
  expect "$cas" 'K\&W \sep 50\% risk \sep $\alpha$-mixing' \
                'K&W' 'keywords keep math, separator intact'
  expect "$els" '\title{Risk \& Return: 50\% of $x_1$: Subtitle \& 10\%' \
                'Risk & Return: 50% of' 'title (elsarticle)'

  # ESCAPED with esc() (everything), for fields that never carry mathematics.
  expect "$cas" 'Smith \& Co\_Ltd' 'Smith & Co_Ltd' 'author name and affiliation'
  expect "$cas" 'R\&D 50\%\_unit' 'R&D 50%_unit' 'affiliation department'
  expect "$cas" 'Note with \& and 50\% and \_under' \
                'Note with & and 50% and _under' 'author note'
  expect "$cas" '\credit{Writing \& 50\%\_editing}' \
                'Writing & 50%_editing' 'credit role'
  expect "$cas" '\JEL{D\&14; C6\%1}' 'D&14' 'JEL codes from tags'
  expect "$els" '\journal{Journal of R\&D 50\%}' \
                'Journal of R&D 50%' 'venue title (elsarticle)'

  # UNTOUCHED. MyST renders these to LaTeX before jtex sees them, so they arrive
  # escaped. A second pass would emit '\textbackslash{}%' and print literally.
  local body
  body=$(strip_comments "$cas")
  if grep -qF 'Costs rose 50\% \& margins fell; see Cost\_Basis.' <<<"$body"; then
    ok 'abstract escaped exactly once by MyST'
  else
    bad 'abstract is not singly-escaped (double-escaping, or MyST changed)'
  fi
  if grep -qF 'Funded by R\&D 50\% grant\_x' <<<"$body"; then
    ok 'parts.title_note escaped exactly once by MyST'
  else
    bad 'parts.title_note is not singly-escaped'
  fi
  if grep -qF '\textbackslash{}' <<<"$body"; then
    bad 'a \textbackslash{} appeared; something was escaped twice'
  else
    ok 'no double-escaping anywhere in the emitted document'
  fi
}

# A fixture that supplies every field cannot catch a field being ABSENT. An
# undefined key aborts the render, and mystmd prints "Exported TeX" and exits 0
# with no file written, leaving whatever PDF was already on disk.
build_absent_case() {
  local label=$1 body=$2 work out
  work=$(mktemp -d)
  printf '%s\n' "$body" > "$work/case.md"
  out=$( cd "$work" && myst build --tex case.md --force 2>&1 )
  if grep -qE 'Template render error|TypeError' <<<"$out"; then
    bad "$label: aborts the template render"
    grep -E 'Template render error|TypeError' <<<"$out" | head -2
  elif [ ! -s "$work/out/c.tex" ]; then
    bad "$label: produced no .tex (mystmd reports success either way)"
  else
    check_no_empty_furniture "$label" "$work/out/c.tex"
  fi
  rm -rf "$work"
}

# An absent field must omit its macro, not emit an empty one, and must take its
# SEPARATOR with it. Comments are stripped first: the template's own comments
# name these macros while discussing them, which would trip every pattern.
check_no_empty_furniture() {
  local label=$1 file=$2 body hit
  body=$(strip_comments "$file")
  # \author[]{} is deliberately absent from this list. An author with no
  # affiliations emits an empty optional group, and both classes accept it
  # (measured: exit 0, no \endcsname error, no superscript printed).
  hit=$(grep -nE '\\(ead|credit|JEL|shorttitle|shortauthors|journal|fntext\[[^]]*\]|cortext\[[^]]*\]|tnotetext\[[^]]*\])\{\}|\\begin\{keywords?\}[[:space:]]*\\end\{keywords?\}|\\shortauthors\{,|organization=\{\}' <<<"$body" | head -3)
  if [ -n "$hit" ]; then
    bad "$label: empty macro or orphan separator emitted"
    printf '      %s\n' "$hit"
  else
    ok "$label"
  fi
}

check_absent_fields() {
  # Everything optional omitted, and author 1 has no name at all: MyST only
  # WARNS on that, so it reaches the template and `.split` would abort there.
  build_absent_case 'minimal frontmatter: no optional fields, one nameless author' \
"---
title: Only A Title
authors:
  - email: nobody@example.org
  - name: Solo
exports:
  - {format: tex, template: $ROOT, output: out/c.tex}
---

# Body

Text."

  # Author with no email, no affiliations, no roles, no orcid. \ead, \credit and
  # the affiliation label group must all be omitted rather than emitted empty.
  build_absent_case 'author with no email, affiliations, roles or orcid' \
"---
title: T
authors:
  - name: Solo Author
exports:
  - {format: tex, template: $ROOT, output: out/c.tex}
---

# Body

Text."

  # Affiliation with a name and nothing else: op={} must suppress the trailing
  # comma, and every absent key must take its separator with it.
  build_absent_case 'affiliation with a bare name and no address parts' \
"---
title: T
authors:
  - name: A B
    affiliations: [Solo University]
exports:
  - {format: tex, template: $ROOT, output: out/c.tex}
---

# Body

Text."

  # No keywords, no tags: the whole keyword environment must be omitted, not
  # emitted empty with a dangling \\JEL label.
  build_absent_case 'no keywords and no JEL codes' \
"---
title: T
authors: [{name: A B}]
exports:
  - {format: tex, template: $ROOT, output: out/c.tex}
---

# Body

Text."

  # A page inheriting everything from project scope and declaring nothing:
  # doc.short_title is undefined here even though the project sets it.
  local work out
  work=$(mktemp -d)
  cat > "$work/myst.yml" <<'YML'
version: 1
project:
  title: Project Title
  short_title: Inherited Short Title
  authors:
    - name: Project Author
  keywords: [alpha, beta]
YML
  cat > "$work/page.md" <<MD
---
exports:
  - {format: tex, template: $ROOT, output: out/c.tex}
---

# Body

Text.
MD
  out=$( cd "$work" && myst build --tex page.md --force 2>&1 )
  if grep -qE 'Template render error|TypeError' <<<"$out"; then
    bad 'page inheriting from project scope: aborts the template render'
  elif [ ! -s "$work/out/c.tex" ]; then
    bad 'page inheriting from project scope: produced no .tex'
  elif ! grep -q '\\shorttitle{' "$work/out/c.tex"; then
    bad 'page inheriting from project scope: no \shorttitle fallback was emitted'
  else
    ok 'page declaring nothing, inheriting project scope'
  fi
  rm -rf "$work"

  # elsarticle exercises a different half of the template (frontmatter
  # environment, \journal, \corref inside the name group), so the absent-field
  # cases above would leave all of it untested under the default class.
  build_absent_case 'minimal frontmatter under document_class: elsarticle' \
"---
title: Only A Title
authors:
  - email: nobody@example.org
  - name: Solo
exports:
  - {format: tex, template: $ROOT, document_class: elsarticle, output: out/c.tex}
---

# Body

Text."
}

do_check() {
  local work
  work=$(mktemp -d)
  write_fixture "$work"
  if ! ( cd "$work" && myst build --tex fixture.md >/dev/null 2>&1 ); then
    bad 'myst build failed on the escaping fixture'
    rm -rf "$work"; return 1
  fi
  for f in cas els; do
    [ -s "$work/out/$f.tex" ] || { bad "out/$f.tex was not produced"; rm -rf "$work"; return 1; }
  done
  check_tex "$work/out/cas.tex" "$work/out/els.tex"
  rm -rf "$work"
  check_absent_fields
  if [ "$fail" -eq 0 ]; then
    echo 'PASS: every raw frontmatter string is escaped and nothing is escaped twice.'
  else
    echo 'FAIL: see above. Check the esc() macro and its call sites in template.tex.'
  fi
  return "$fail"
}

# Rejection test, with FOUR seeded defects. Raw input exercises the positive
# assertions; the double-escape assertion is a negative check that raw input
# passes correctly, so it needs a doubly-escaped fixture of its own.
do_self_test() {
  local work out rc=0 dbl
  work=$(mktemp -d)
  mkdir -p "$work/out"
  cat > "$work/out/cas.tex" <<'RAW'
\title[mode=title]{Risk & Return: 50% of $x_1$}
\title[mode=sub]{Subtitle & 10%}
\shorttitle{Risk & Return 50%}
\author[1]{Smith & Co_Ltd}
\affiliation[1]{organization={Smith & Co_Ltd},department={R&D 50%_unit}}
\fntext[1]{Note with & and 50% and _under}
\credit{Writing & 50%_editing}
K&W \sep 50% risk \sep $\alpha$-mixing
\JEL{D&14; C6%1}
Costs rose 50% & margins fell; see Cost_Basis.
Funded by R&D 50% grant_x
RAW
  cp "$work/out/cas.tex" "$work/out/els.tex"
  cat >> "$work/out/els.tex" <<'RAW'
\journal{Journal of R&D 50%}
\title{Risk & Return: 50% of $x_1$: Subtitle & 10%}
RAW
  out=$( fail=0; check_tex "$work/out/cas.tex" "$work/out/els.tex"; echo "__fail=$fail" )

  # Defect 1: raw input. Every assertion except the double-escape check must
  # FAIL; that one is expected to pass, because raw input is not double-escaped.
  local passed
  passed=$(grep '^ok    ' <<<"$out" | grep -cv 'no double-escaping')
  if [ "$passed" -ne 0 ]; then
    printf '%s\n' "$out"
    printf 'FAIL  rejection test: %d positive assertion(s) PASSED on known-raw input\n' "$passed"
    rc=1
  elif ! grep -q '^ok    no double-escaping' <<<"$out"; then
    printf 'FAIL  rejection test: the double-escape check fired on input that is not double-escaped\n'
    rc=1
  else
    printf 'ok    rejection test 1: every positive assertion fails on known-raw input\n'
  fi

  # Defect 2: doubly-escaped input, which is what running an escaper over a
  # field MyST already rendered would produce.
  dbl="$work/out/dbl.tex"
  printf '%s\n' '\title[mode=title]{Costs rose 50\textbackslash{}\% \textbackslash{}\& fell}' > "$dbl"
  out=$( fail=0; check_tex "$dbl" "$dbl"; echo "__fail=$fail" )
  if grep -q '^ok    no double-escaping' <<<"$out"; then
    printf 'FAIL  rejection test: double-escaped input was NOT caught\n'
    rc=1
  else
    printf 'ok    rejection test 2: double-escaped input is caught\n'
  fi
  rm -rf "$work"

  # Defect 3: the assertion strings present ONLY as comments. A comment must
  # not satisfy a presence assertion, and must not trip an absence one.
  local cmt="$work/out/cmt.tex"
  mkdir -p "$work/out"
  {
    sed 's/^/% /' "$work/out/cas.tex" 2>/dev/null
    printf '%s\n' '% \title[mode=title]{Risk \& Return: 50\% of $x_1$}'
    printf '%s\n' '% [add1]{\fnms{}~\snm{}\ead[label=e?]{}}'
    printf '%s\n' '%% Costs rose 50\% \& margins fell; see Cost\_Basis.'
    printf '%s\n' '%% mentions \textbackslash{} while discussing the sentinel'
  } > "$cmt"
  out=$( fail=0; check_tex "$cmt" "$cmt"; echo "__fail=$fail" )
  if grep -qE '^ok    (title|subtitle|short_title|keywords|author|affiliation|credit|JEL|venue|abstract|parts)' <<<"$out"; then
    printf '%s\n' "$out"
    printf 'FAIL  rejection test: a COMMENT satisfied a presence assertion\n'
    rc=1
  elif ! grep -q '^ok    no double-escaping' <<<"$out"; then
    printf 'FAIL  rejection test: a \\textbackslash{} inside a COMMENT tripped the absence assertion\n'
    rc=1
  else
    printf 'ok    rejection test 3: comments neither satisfy nor trip assertions\n'
  fi

  # Defects 4 and 5 need a real template tree, because check_absent_fields
  # builds through one. Each reverts ONE guard so the two assertions it makes
  # (no render abort, no empty furniture) are exercised independently.
  seed_template() {
    local label=$1 pattern=$2 marker=$3 tmpl out
    shift 3
    tmpl=$(mktemp -d)/tpl
    cp -r "$ROOT" "$tmpl"
    rm -rf "$tmpl/example" "$tmpl/_build" "$tmpl/original"
    "$@" "$tmpl/template.tex"
    if ! grep -qF "$marker" "$tmpl/template.tex"; then
      printf 'FAIL  %s: could not seed the defect; the guard was not where expected\n' "$label"
      rc=1
    else
      out=$( ROOT="$tmpl" fail=0; ROOT="$tmpl" check_absent_fields 2>&1 )
      if grep -qE "^FAIL  .*$pattern" <<<"$out"; then
        printf 'ok    %s\n' "$label"
      else
        printf 'FAIL  %s: the seeded defect was NOT caught\n' "$label"
        rc=1
      fi
    fi
    rm -rf "$(dirname "$tmpl")"
  }

  seed_template 'rejection test 4: an unguarded undefined key is caught' \
    'aborts the template render' 'esc(author.name.split(" ") | last)' \
    perl -0pi -e 's/\Qset named_authors = doc.authors | selectattr("name") | list if doc.authors else []\E/set named_authors = doc.authors if doc.authors else []/; s/\Qesc(author.name.split(" ") | last)\E/esc(author.name.split(" ") | last)/'

  # Loop the UNFILTERED list but keep the undefined-key guard, so the only
  # defect present is the orphan separator and defect 4 cannot mask it.
  seed_template 'rejection test 5: an orphan separator is caught' \
    'empty macro or orphan separator' 'default("")' \
    perl -0pi -e 's/\Qfor author in named_authors\E/for author in doc.authors/; s/\Qesc(author.name.split(" ") | last)\E/esc((author.name | default("")).split(" ") | last)/'
  if [ "$rc" -eq 0 ]; then
    echo 'PASS: the escaping checker rejects unescaped input.'
  else
    echo 'FAIL: the escaping checker missed unescaped input; its PASS is worthless.'
  fi
  return "$rc"
}

case "${1:-}" in
  --self-test) do_self_test ;;
  ""|--check)  do_check ;;
  *) echo "usage: $0 [--check|--self-test]" >&2; exit 2 ;;
esac
