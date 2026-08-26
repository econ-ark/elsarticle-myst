# `original/` - pristine upstream sources

Everything here is **unmodified upstream material**, kept so the class files at
the repository root can be checked against their source. Nothing here is used by
the build. Do not edit these files, and do not extract a zip over the repository
root: that would silently revert every patch in [`../PATCHES.md`](../PATCHES.md).

The repository wraps two different Elsevier classes, and their provenance
differs, so each is recorded separately below.

## Contents

| Path | What it is |
|---|---|
| `els-cas-templates.zip` | CAS bundle 2.4. 34 files: `cas-sc.cls`, `cas-dc.cls`, `cas-common.sty`, `cas-model2-names.bst`, samples, `figs/`, `thumbnails/`, `manifest.txt`, `doc/elsdoc-cas.pdf`. |
| `elsarticle.zip` | elsarticle 3.5, as DocStrip source (`elsarticle.dtx` + `.ins`), plus the three `.bst` files and templates. |
| `cas-sc-template.tex`, `cas-dc-template.tex` | Byte-identical copies of two zip members, extracted when the root `template.tex` was first written. Redundant with the zip; kept because they predate it (`bfc72bb`, then `b052c26` the same day). |
| `SHA256SUMS` | Checksums for the above, verified by check A. |
| `patches/*.patch` | The exact diffs between upstream and the patched root files, verified by check D. |

## CAS

| Field | Value |
|---|---|
| Class files | `cas-sc.cls` (single column), `cas-dc.cls` (double column) |
| Version | 2.4, dated 2024-05-04; bundle packaged 2024-05-06 |
| CAS stands for | Complex Article Service, the Elsevier submission workflow these classes target. Elsevier does not expand the acronym anywhere in the bundle itself. |
| Upstream | Elsevier, [LaTeX instructions for authors](https://www.elsevier.com/researcher/author/policies-and-guidelines/latex-instructions); mirrored to CTAN as `els-cas-templates` |
| License | LPPL. The bundle README says "version 1.2 or any later version"; `manifest.txt` and `cas-sc.cls` declare 1.3c. Author-maintained. |
| Copyright | Elsevier Ltd, 2019-2024 |
| Root files | `cas-sc.cls`, `cas-dc.cls`, `cas-common.sty` are **patched** (see `../PATCHES.md`). `cas-model2-names.bst` and `thumbnails/*.jpeg` are byte-identical to upstream. |

CAS has been frozen at 2.4 since May 2024. Elsevier's download, CTAN's
`els-cas-templates`, and the copy in TeX Live are all byte-identical, and all
three still contain the six `\vbox_unpack_clear:N` calls that the LaTeX3 kernel
dropped in 2022. There is no fixed CAS anywhere, which is why the patches here
exist rather than being deferred to a distribution update.

The `thumbnails/` images are not optional for CAS: `cas-common.sty` includes
`thumbnails/cas-email.jpeg` and `cas-url.jpeg` whenever an author has `\ead{}`
or `\ead[url]{}`, which is nearly every paper. The `nologo` key on the
`stm/mktitle` family swaps the icons for text labels if you want to drop them.

## elsarticle

| Field | Value |
|---|---|
| Class file | `elsarticle.cls` |
| Version | 3.5, dated 2026-01-09 |
| Upstream | [CTAN](https://ctan.org/pkg/elsarticle), `macros/latex/contrib/elsarticle`; also in TeX Live under `collection-publishers` |
| License | LPPL 1.3 |
| Copyright | Elsevier Ltd, 2007-2026 |
| Root files | `elsarticle.cls` and the three `.bst` files are **generated**, not copied, and carry no patches. |

elsarticle is distributed as DocStrip source, so the root files are produced by
running `latex elsarticle.ins` against this zip. Check F regenerates them and
compares byte for byte, which is a stronger guarantee than a copy check: it
proves the vendored files are reproducible from the recorded source. The
generated `elsarticle.cls` is byte-identical to the one in TeX Live.

### Why CTAN and not Elsevier

Elsevier's own instructions page serves elsarticle **3.4** (2024-04-04), which
CTAN superseded with 3.5. The difference is substantive, not cosmetic: 3.5
renames `\newcounter{author}` to `\newcounter{elsarticle@author}`, fixing a
clash on a very generic counter name, and removes the "Preprint submitted to
..." line at Elsevier's own instruction (recorded in the class source, dated
22 October 2024). Vendoring Elsevier's copy would carry a known defect forward.

CTAN is therefore the anchor for **both** classes, which also means one
mechanism verifies both:

- For elsarticle, CTAN is where the maintainer uploads. It is simply upstream.
- For CAS, Elsevier publishes and CTAN mirrors. Verified 2026-08-26: the two
  zips are byte-identical, so anchoring on CTAN loses nothing.
- CTAN URLs are stable and versioned, and its JSON API reports the version
  directly, so drift is detectable without downloading megabytes. Elsevier's
  Contentful CDN paths are content-addressed and 404 on every republish.

Not TeX Live, for three reasons. Its `cat-version` field *is* the CTAN catalogue
version, so checking it would check the same fact one layer removed and staler.
It is a frozen annual snapshot, so as a drift detector it lags by up to a year
and moves in steps. And it does not determine our output anyway: the `pdf+tex`
export carries the class files with it, so whoever compiles the bundle uses the
copies vendored here, not their own installation. TeX Live would become the
right anchor only if this template stopped vendoring.

## Verification

`scripts/verify-upstream.sh` is the gate. Checks A-D and F run in CI on every
push and pull request; E runs monthly in `upstream-drift.yml`.

```bash
./scripts/verify-upstream.sh              # offline: A-D and F
./scripts/verify-upstream.sh --online     # adds E1+E2, against CTAN
./scripts/verify-upstream.sh --self-test  # rejection test of the checker itself
./scripts/verify-upstream.sh --update     # re-record after a deliberate change
```

| Check | Question it answers |
|---|---|
| A | Is `original/` itself untouched? (against `SHA256SUMS`) |
| B | Are the loose `.tex` files byte-identical to their members in the CAS zip? |
| C | Are the root files claimed unpatched (`.bst`, `thumbnails/`) byte-identical to upstream? |
| D | Do the three patched root files differ from upstream by *exactly* the diffs in `patches/`? |
| F | Do the elsarticle root files regenerate byte-for-byte from `elsarticle.zip`? |
| E1 | Does CTAN still publish the version we vendor? (asks `ctan.org` directly) |
| E2 | Do CTAN's bytes still match our zips? (mirrors; see below) |

Checks A-D and F are internally consistent only. On their own they prove nothing
more than that the repository agrees with itself: a substituted `original/` would
still pass, because the checksums would have been computed from the substituted
copy. **E is the only external anchor.** It is kept separate because it needs
network access and because a mismatch there is usually news, a new upstream
release, rather than a defect.

E1 derives the expected version from the vendored artifact (the CAS bundle
README, and `\RCSversion` in the generated `elsarticle.cls`) rather than from a
constant in the script. A hardcoded version would be a second copy of a fact
already recorded here, and the two would drift apart the first time one was
updated without the other.

E2 has to go through a mirror, because every `ctan.org` archive path redirects to
one, and the JSON API publishes no checksums. A stale or mid-sync mirror serving
old bytes would be a false alarm, and a monthly job that cries wolf gets ignored,
so E2 tries three mirrors and reports a mismatch only if every mirror that
answered disagrees. The three outcomes are distinct on purpose:

| Outcome | Verdict | Reasoning |
|---|---|---|
| Some mirror matches | `ok` | One stale mirror is skew, not drift. |
| No mirror answers | `warn`, build still passes | Nothing was verified and nothing was contradicted; E1 already answered the drift question from `ctan.org`. |
| Every mirror that answered disagrees | `FAIL` | Same version from E1 but different bytes is a re-roll or worse. |

`warn` deliberately avoids the word "skip", which is what CI greps for to catch a
check that silently did not run.

The checker carries its own rejection test. `--self-test` copies the tree, seeds
one defect per check (tampered zip; tampered `.tex` with refreshed checksums;
drift in a supposedly-unpatched file; an undocumented edit to a class file; a
deleted patch record; an edited generated file) and asserts each is caught. A
checker never shown to fail is not evidence of anything, so CI runs `--self-test`
before it trusts a pass.

## Other Elsevier LaTeX bundles

Elsevier's instructions page offers three families. This repository wraps the
first two.

| Family | Files | What it is |
|---|---|---|
| **CAS** | `els-cas-templates.zip` | Current bundle for journal articles, single- and double-column. Supports CRediT roles, highlights, graphical abstracts. |
| **elsarticle** | `elsarticle.zip`, `elsarticle.cls`, `elsarticle-num.bst`, `elsdoc-1.pdf` | The older general-purpose class, still offered and far more actively maintained. |
| **ecrc** | `elsarticle-ecrc.zip`, `ecrc.sty`, `ecrc-template.tex`, plus per-series `ecrc-procs.zip` (Procedia Computer Science) and `ecrc-nppp-p1.zip` (Nuclear and Particle Physics Proceedings) | Camera-ready-copy variant layered on `elsarticle`, for Procedia-style proceedings. **Not wrapped here.** |
