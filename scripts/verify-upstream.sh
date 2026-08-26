#!/usr/bin/env bash
# Verify that original/ is pristine upstream and that the root class files
# differ from it by exactly the recorded patches.
#
#   scripts/verify-upstream.sh              verify this repository (offline)
#   scripts/verify-upstream.sh --online     also re-download the bundle from
#                                           Elsevier and compare it byte for byte
#   scripts/verify-upstream.sh --self-test  rejection test: mutate a copy of the
#                                           tree and confirm every check fails
#   scripts/verify-upstream.sh --update     regenerate SHA256SUMS and patches
#                                           from the current tree (use only when
#                                           you have deliberately changed a patch)
#
# Checks A through D are internally consistent only: they prove the root files
# match original/, not that original/ is what Elsevier published. Check E is the
# external anchor and needs network access.
#
# Checks:
#   A  original/SHA256SUMS matches original/ (the upstream files are untouched)
#   B  original/*.tex are byte-identical to their members inside the zip
#   C  root files claimed unpatched are byte-identical to the zip members
#   D  root files claimed patched differ from the zip by exactly the diff
#      recorded in original/patches/<file>.patch
#   E  (--online) the bundle Elsevier serves today is byte-identical to
#      original/els-cas-templates.zip

set -uo pipefail

ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
ZIP="$ROOT/original/els-cas-templates.zip"

# CTAN anchors both classes; see original/README.md, "Why CTAN and not Elsevier".
# E1 asks ctan.org itself, so no mirror can skew it. E2 can only reach a mirror
# (every archive path redirects), so it tries several before calling a mismatch.
CTAN_API='https://ctan.org/json/2.0/pkg'
CTAN_MIRRORS=(
  'https://mirrors.ctan.org/macros/latex/contrib'
  'https://mirror.clarkson.edu/ctan/macros/latex/contrib'
  'https://mirrors.rit.edu/CTAN/macros/latex/contrib'
)

# package name : vendored zip. No version constant here on purpose: it would be
# a second copy of a fact we ship, and the two drift apart the first time one is
# updated without the other. vendored_version() reads it from the artifact.
UPSTREAM_PKGS=(
  "els-cas-templates:els-cas-templates.zip"
  "elsarticle:elsarticle.zip"
)

# Read the version out of what we actually vendor.
#   CAS:        the bundle README's "Version 2.4" line, inside the zip.
#   elsarticle: \def\RCSversion{3.5} in the generated class at the repo root.
vendored_version() {
  local pkg=$1 up=$2
  case "$pkg" in
    els-cas-templates)
      sed -n 's/^Version[[:space:]]\+\([0-9.]\+\).*/\1/p' "$up/README" | head -1
      ;;
    elsarticle)
      sed -n 's/.*\\def\\RCSversion{\([0-9.]\+\)}.*/\1/p' "$ROOT/elsarticle.cls" | head -1
      ;;
  esac
}

UNPATCHED=(
  cas-model2-names.bst
  thumbnails/cas-email.jpeg
  thumbnails/cas-facebook.jpeg
  thumbnails/cas-gplus.jpeg
  thumbnails/cas-linkedin.jpeg
  thumbnails/cas-twitter.jpeg
  thumbnails/cas-url.jpeg
)
PATCHED=(cas-sc.cls cas-dc.cls cas-common.sty)
LOOSE=(cas-sc-template.tex cas-dc-template.tex)

# elsarticle is distributed as DocStrip source (.dtx + .ins), so these are
# GENERATED from original/elsarticle.zip, not copied out of it. Check F
# regenerates and compares, proving they are reproducible from that source.
GENERATED=(elsarticle.cls elsarticle-num.bst elsarticle-harv.bst elsarticle-num-names.bst)

fail=0
ok()   { printf 'ok    %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }
# warn does NOT set fail: reserved for an unreachable network peer, never for a
# check that ran and disagreed. It must not use the word "skip" (CI greps that).
warn() { printf 'warn  %s\n' "$*"; }

extract() {
  local dest
  dest=$(mktemp -d)
  unzip -qo "$ZIP" -d "$dest" || { echo "cannot unzip $ZIP" >&2; exit 2; }
  echo "$dest/els-cas-templates"
}

do_update() {
  local up tmp rc
  up=$(extract)
  # extract()'s `exit 2` only leaves the command substitution, so a failed
  # unzip arrives here as an empty $up. Without this guard the redirection
  # below truncates each patch record before diff errors on a bogus path.
  [ -n "$up" ] && [ -d "$up" ] || { echo "extract failed; refusing to rewrite patches" >&2; exit 2; }
  for f in "${PATCHED[@]}"; do
    tmp=$(mktemp)
    diff -u --label "upstream/$f" --label "root/$f" "$up/$f" "$ROOT/$f" > "$tmp"
    rc=$?
    # diff: 0 = identical, 1 = differences, 2 = trouble. Only move on 0 or 1,
    # so a failed diff can never replace a good patch record with an empty one.
    if [ "$rc" -gt 1 ]; then
      rm -f "$tmp"; echo "diff failed for $f; patch record left untouched" >&2; exit 2
    fi
    mv "$tmp" "$ROOT/original/patches/$f.patch"
    echo "wrote original/patches/$f.patch"
  done
  ( cd "$ROOT/original" && sha256sum els-cas-templates.zip elsarticle.zip "${LOOSE[@]}" > SHA256SUMS )
  echo "wrote original/SHA256SUMS"
}

# E. The only check that looks outside this repository. Everything else takes
# original/ on faith; this asks CTAN what is actually published. Runs the same
# two probes against both packages, so CAS and elsarticle are verified alike.
check_online() {
  local entry pkg zipname want live status ours theirs got up
  up=$(extract)
  for entry in "${UPSTREAM_PKGS[@]}"; do
    IFS=: read -r pkg zipname <<<"$entry"
    want=$(vendored_version "$pkg" "$up")
    if [ -z "$want" ]; then
      bad "E1 $pkg: could not read the vendored version from the repo"
      continue
    fi

    # E1: version, from the API. Cheap, and it names what changed.
    got=$(curl -sS --max-time 60 "$CTAN_API/$pkg" 2>/dev/null \
            | jq -r '.version.number // empty' 2>/dev/null)
    if [ -z "$got" ]; then
      bad "E1 $pkg: could not read the version from CTAN"
    elif [ "$got" = "$want" ]; then
      ok "E1 $pkg: CTAN still publishes $want (matches what we vendor)"
    else
      bad "E1 $pkg: CTAN now publishes $got, we vendor $want"
      echo "      Review the changes before adopting. For CAS that means"
      echo "      re-deriving every patch in PATCHES.md against the new source."
    fi

    # E2: bytes, from a mirror. A single mirror can be stale or mid-sync, so a
    # mismatch is only real if every mirror that answered agrees on it.
    ours=$(sha256sum "$ROOT/original/$zipname" | cut -d' ' -f1)
    local m fetched=0 matched=0 differing=""
    for m in "${CTAN_MIRRORS[@]}"; do
      live=$(mktemp)
      status=$(curl -sSL --max-time 180 -o "$live" -w '%{http_code}' \
                 "$m/$pkg.zip" 2>/dev/null) || status=000
      if [ "$status" = 200 ] && unzip -tqq "$live" >/dev/null 2>&1; then
        fetched=$((fetched + 1))
        theirs=$(sha256sum "$live" | cut -d' ' -f1)
        if [ "$theirs" = "$ours" ]; then matched=1; rm -f "$live"; break; fi
        differing="$differing        $theirs  ${m#https://}"$'\n'
      fi
      rm -f "$live"
    done

    if [ "$matched" = 1 ]; then
      ok "E2 $pkg: CTAN's zip is byte-identical to original/$zipname"
    elif [ "$fetched" = 0 ]; then
      # Not a failure: E1 already answered the drift question from ctan.org.
      warn "E2 $pkg: no CTAN mirror served a valid zip; E1 above still stands"
    else
      bad "E2 $pkg: $fetched mirror(s) served a zip and none matched original/$zipname"
      echo "      ours: $ours"
      printf '%s' "$differing"
      echo "      Same version from E1 but different bytes is a re-roll or worse."
    fi
  done
  rm -rf "${up%/els-cas-templates}"
}

# F. Regenerate the elsarticle files from the vendored DocStrip source and
# check they reproduce the vendored copies byte for byte. Skipped with a loud
# note when latex is unavailable, since a silent skip would read as a pass.
check_generated() {
  local work f
  if ! command -v latex >/dev/null 2>&1; then
    echo 'skip  F elsarticle regeneration: no latex on PATH'
    return
  fi
  work=$(mktemp -d)
  unzip -qo "$ROOT/original/elsarticle.zip" -d "$work" || { bad "F cannot unzip elsarticle.zip"; return; }
  local src
  src=$(dirname "$(find "$work" -name 'elsarticle.ins' | head -1)")
  if [ -z "$src" ] || [ ! -f "$src/elsarticle.ins" ]; then
    bad "F elsarticle.ins not found in original/elsarticle.zip"
    rm -rf "$work"; return
  fi
  ( cd "$src" && latex -interaction=nonstopmode elsarticle.ins >/dev/null 2>&1 )
  for f in "${GENERATED[@]}"; do
    if [ ! -f "$src/$f" ]; then
      bad "F $f was not produced by elsarticle.ins"
    elif cmp -s "$src/$f" "$ROOT/$f"; then
      ok "F $f reproduces byte-for-byte from original/elsarticle.zip"
    else
      bad "F $f does not match what original/elsarticle.zip generates"
    fi
  done
  rm -rf "$work"
}

do_verify() {
  local up
  up=$(extract)

  # A
  if ( cd "$ROOT/original" && sha256sum -c --status SHA256SUMS ); then
    ok "A original/ matches SHA256SUMS"
  else
    bad "A original/ does not match SHA256SUMS (upstream material was modified)"
    ( cd "$ROOT/original" && sha256sum -c SHA256SUMS 2>&1 | grep -v ': OK$' || true )
  fi

  # B
  for f in "${LOOSE[@]}"; do
    if cmp -s "$up/$f" "$ROOT/original/$f"; then
      ok "B original/$f is identical to its zip member"
    else
      bad "B original/$f differs from its zip member"
    fi
  done

  # C
  for f in "${UNPATCHED[@]}"; do
    if cmp -s "$up/$f" "$ROOT/$f"; then
      ok "C $f is identical to upstream"
    else
      bad "C $f is documented as unpatched but differs from upstream"
    fi
  done

  # D
  for f in "${PATCHED[@]}"; do
    local rec="$ROOT/original/patches/$f.patch"
    if [ ! -f "$rec" ]; then
      bad "D $f has no recorded patch at original/patches/$f.patch"
      continue
    fi
    # Not a pipeline: `diff -u` exits 1 whenever a patch exists, and pipefail
    # would surface that instead of the comparison's own verdict.
    local gen
    gen=$(mktemp)
    diff -u --label "upstream/$f" --label "root/$f" "$up/$f" "$ROOT/$f" > "$gen"
    if diff -q "$gen" "$rec" >/dev/null; then
      ok "D $f differs from upstream by exactly the recorded patch"
    else
      bad "D $f does not match its recorded patch (see PATCHES.md)"
      diff -u "$rec" "$gen" | head -40
    fi
    rm -f "$gen"
  done

  rm -rf "${up%/els-cas-templates}"
  check_generated
  [ "$ONLINE" = 1 ] && check_online
  if [ "$fail" -eq 0 ]; then
    echo "PASS: original/ is pristine and every root file matches its recorded state."
  else
    echo "FAIL: see above. Do not re-extract the zip over the root; that reverts the patches."
  fi
  return "$fail"
}

# Rejection test. A verifier that never fails proves nothing, so mutate a
# throwaway copy of the tree once per check and assert the check catches it.
do_self_test() {
  local rc=0
  expect_fail() {
    local label=$1 pattern=$2 tmp out
    tmp=$(mktemp -d)
    mkdir -p "$tmp/original/patches" "$tmp/thumbnails" "$tmp/scripts"
    cp -r "$ROOT/original/." "$tmp/original/"
    cp "$ROOT"/cas-*.cls "$ROOT"/cas-common.sty "$ROOT"/cas-model2-names.bst "$tmp/"
    cp "$ROOT"/elsarticle.cls "$ROOT"/elsarticle-*.bst "$tmp/"
    cp "$ROOT"/thumbnails/*.jpeg "$tmp/thumbnails/"
    cp "$ROOT/scripts/verify-upstream.sh" "$tmp/scripts/"
    shift 2
    ( cd "$tmp" && "$@" )
    out=$(ROOT="$tmp" bash "$tmp/scripts/verify-upstream.sh" 2>&1)
    if grep -q "^FAIL  $pattern" <<<"$out"; then
      printf 'ok    rejection test: %s\n' "$label"
    else
      printf 'FAIL  rejection test: %s was NOT caught\n' "$label"
      rc=1
    fi
    rm -rf "$tmp"
  }

  # Corrupt the checksum file, not the zip: appending to the zip only reaches
  # check A if unzip tolerates trailing garbage, which ties this case to zip
  # format tolerance rather than to check A's own comparison.
  expect_fail "checksum mismatch in original/" A bash -c 'sed -i "s/^./0/" original/SHA256SUMS'
  # Also refreshes SHA256SUMS, so check A passes and only B can catch this one.
  expect_fail "modified original/*.tex"    B bash -c 'printf "%% x\n" >> original/cas-sc-template.tex; (cd original && sha256sum els-cas-templates.zip elsarticle.zip cas-sc-template.tex cas-dc-template.tex > SHA256SUMS)'
  expect_fail "drift in unpatched .bst"    C bash -c 'printf "%% x\n" >> cas-model2-names.bst'
  expect_fail "undocumented edit to .cls"  D bash -c 'printf "%% x\n" >> cas-sc.cls'
  expect_fail "deleted patch record"       D rm -f original/patches/cas-common.sty.patch
  expect_fail "edited generated elsarticle" F bash -c 'printf "%% x\n" >> elsarticle.cls'

  if [ "$rc" -eq 0 ]; then
    echo "PASS: the verifier rejects every seeded defect."
  else
    echo "FAIL: the verifier missed a seeded defect; its PASS verdict is worthless."
  fi
  return "$rc"
}

ONLINE=0
case "${1:-}" in
  --self-test) do_self_test ;;
  --update)    do_update ;;
  --online)    ONLINE=1; do_verify ;;
  ""|--check)  do_verify ;;
  *) echo "usage: $0 [--check|--online|--self-test|--update]" >&2; exit 2 ;;
esac
