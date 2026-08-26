# Patches applied to upstream Elsevier classes

Only the CAS bundle is patched. The elsarticle files at the repository root
(`elsarticle.cls` and its three `.bst` files) carry **no patches**: they are
generated verbatim from `original/elsarticle.zip` by `latex elsarticle.ins`, and
check F in `scripts/verify-upstream.sh` regenerates them on every CI run to prove
it. See [`original/README.md`](original/README.md) for why the two classes have
different provenance.

## CAS

The `cas-sc.cls`, `cas-dc.cls`, and `cas-common.sty` files at the root of
this repository are NOT byte-identical to the corresponding files in
`original/els-cas-templates.zip`. Each patch corrects a defect or
adapts the upstream code for the MyST + XeLaTeX pipeline.

If you re-extract the zip on top of the root, every patch is lost and
the template will either fail to compile or produce subtly broken
output. Do not re-extract.

## Upstream source

| Field | Value |
|---|---|
| Bundle | `els-cas-templates.zip` |
| Version | `cas-sc.cls` / `cas-dc.cls` v2.4 (2024/05/04) |
| `cas-model2-names.bst` | identical to upstream (no patch) |
| Upstream source | <https://www.elsevier.com/researcher/author/policies-and-guidelines/latex-instructions> |
| SHA-256 of the bundle | `36d97da01c6bbd134f315bff6c3de553735e2550444a6ddd4f869ddc67a20757` |
| Provenance and verification | [`original/README.md`](original/README.md) |

## Patches

### `cas-sc.cls`

| Patch | Rationale |
|---|---|
| File header comment changed from `cas-dc.cls` to `cas-sc.cls` | Upstream copy-paste bug; the comment misidentifies the file. |
| `pdfproducer={pdfTeX;}` -> `pdfproducer={}` | MyST renders this template through XeLaTeX, not pdfTeX. The literal `pdfTeX;` string would mislabel the engine in the produced PDF metadata. |
| `\file_if_exist:nTF { inconsolata }` -> `\file_if_exist:nTF { inconsolata.sty }` | Upstream omits the `.sty` extension; the existence test then always returns false, causing a silent fallback to CMR (`\tex_gdef:D \ttdefault { cmtt }`). With the patch, `inconsolata` loads correctly when available. |
| Stray `\AtEndDocument{\hypersetup{pdftitle=..., pdfauthor=...}}` block removed (was commented out upstream) | Cosmetic; the commented block was incomplete and confusing. |

### `cas-dc.cls`

| Patch | Rationale |
|---|---|
| File header comment changed from `cas-sc.cls` to `cas-dc.cls` | Upstream copy-paste bug. |
| LPPL version reference `1.2` -> `1.3c` | Matches the actual license in `manifest.txt` and the `cas-sc.cls` declaration. The upstream `cas-dc.cls` is the only file in the bundle with the wrong LPPL version. |
| `pdfcreator={LaTeX3; cas-sc.cls; hyperref.sty}` -> `pdfcreator={LaTeX3; cas-dc.cls; hyperref.sty}` | Upstream copy-paste bug; the double-column class names the single-column class in its PDF metadata. |
| `pdfproducer={pdfTeX;}` -> `pdfproducer={}` | Same as `cas-sc.cls`; the engine is XeLaTeX, not pdfTeX. |
| Section comment `% Specific to Single Column` -> `% Specific to Double Column` | Upstream copy-paste bug inside the double-column class. |

### `cas-common.sty`

| Patch | Rationale |
|---|---|
| Six `\vbox_unpack_clear:N` calls replaced with `\vbox_unpack_drop:N` | `\vbox_unpack_clear:N` was removed from the LaTeX3 kernel in 2022; current kernels provide only `\vbox_unpack_drop:N`. Verified 2026-08-26 with `\cs_if_exist:NTF`: the old name is undefined, the new one is defined. The six calls sit in the frontmatter and two-column output branches, which neither stock Elsevier template reaches, so both still compile clean unpatched; the breakage is path-dependent rather than universal, and this patch keeps documents that do reach those branches from dying on an undefined control sequence. An inline comment marks each replacement. |
| `Abstract` environment: introduce `\g_stm_keybox_ht_dim`, switch `\dim_gset/_gadd` to local `\dim_set/_add`, add a trailing `\skip_vertical:n` that re-balances spacing when a non-empty `\g_stm_key_box` precedes the abstract | Without these, long keyword boxes overflow into the abstract baseline in single-column mode. The original behavior is preserved for empty keyword boxes. |
| Two `\tl_set:Nn` -> `\tl_set:Nx` in the `fig` and `tbl` position-key dispatchers | The right-hand side `\l_keys_key_tl` is itself a control sequence whose value must be fully expanded for the dispatcher to store a string; `Nn` preserves the macro token, `Nx` expands it. Upstream uses `Nn`, which fails for nontrivial position values. |
| Stray `\l_fig_pos_tl` in the table key dispatcher renamed to `\l_tbl_pos_tl` | Upstream copy-paste bug; the table dispatcher was writing into the figure position variable, so table positions would leak into the most recent figure. |

## Verifying the patches

Run the checker, which enforces that these files differ from upstream by exactly
the diffs recorded in `original/patches/`, and nothing else:

```bash
./scripts/verify-upstream.sh            # offline
./scripts/verify-upstream.sh --online   # also re-download from Elsevier
```

It runs in CI on every push and pull request. See
[`original/README.md`](original/README.md) for what each check does and why the
offline checks alone are not enough. To inspect a patch by hand:

```bash
unzip -o original/els-cas-templates.zip -d /tmp/cas_check
diff -u /tmp/cas_check/els-cas-templates/cas-sc.cls cas-sc.cls
```

After deliberately changing a patch, re-record it with
`./scripts/verify-upstream.sh --update` and update the table above in the same
commit.

Expected: only the patches listed above. If `diff` shows nothing, the
patched files have been overwritten by the upstream copies and you need
to restore them from git history.

## Why patches live in the root copy, not as a `.sty` overlay

`cas-common.sty` is loaded by `\RequirePackage{cas-common}` deep inside
`cas-sc.cls` / `cas-dc.cls`, before any user code can run. There is no
hook for a post-load overlay to redefine the `vbox_unpack_*` calls that
appear at preamble time. Replacing the file at root is the only
mechanism that intercepts these calls early enough.

If Elsevier publishes a corrected upstream bundle, regenerate this file
list by running:

```bash
diff -u /tmp/cas_check/els-cas-templates/cas-common.sty cas-common.sty > .patches/cas-common.diff
```

and update this document.
