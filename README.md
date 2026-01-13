# Elsevier CAS Template for MyST Markdown

A comprehensive MyST Markdown template for Elsevier journal articles using the CAS (Content Acquisition System) document classes.

![Template Preview](thumbnail.png)

## Overview

| | |
|---|---|
| **Authors** | [Alan Lujan](https://econ-ark.org) |
| **Affiliation** | Johns Hopkins University, Econ-ARK |
| **Repository** | [github.com/econ-ark/elsarticle-myst](https://github.com/econ-ark/elsarticle-myst) |
| **Source** | [Elsevier LaTeX Instructions](https://www.elsevier.com/authors/policies-and-guidelines/latex-instructions) |
| **License** | Content: CC-BY-4.0 / Code: MIT / LaTeX: LPPL-1.3c |

## Features

- **Dual layouts**: Single column (`cas-sc`) and double column (`cas-dc`)
- **Citation styles**: Author-year or numeric references
- **Rich metadata**: ORCID, email, CRediT contributor roles, affiliations
- **Elsevier features**: Research highlights, graphical abstracts, keywords
- **Extended author metadata**: Equal contributors, author notes, deceased markers, social links (Twitter)
- **Title features**: Main title, subtitle, title footnotes, general notes
- **Full MyST support**: Math, proofs, theorems, admonitions, cross-references, tables, figures
- **Multiple exports**: Generate PDFs in different formats from a single source

## Requirements

- **MyST Markdown**: Latest version (install via `pip install mystmd` or `npm install -g mystmd`)
- **LaTeX Distribution**: TeX Live 2022+ or MiKTeX 22.1+ (required for PDF export)
- **XeLaTeX**: Recommended for Unicode support (included in standard TeX distributions)
- **Python**: 3.8+ (if using pip installation)
- **Node.js**: 16+ (if using npm installation)

> **⚠️ LaTeX3 Required**: This template uses modern LaTeX3 commands (`vbox_unpack_drop:N`) introduced in 2022. Earlier LaTeX distributions will fail with cryptic errors. If you encounter `vbox_unpack_drop:N` errors, upgrade your TeX distribution to TeX Live 2022+ or MiKTeX 22.1+.

## Quick Start

### 1. Install MyST

```bash
pip install mystmd
# or
npm install -g mystmd
```

### 2. Create Your Article

Create a markdown file with frontmatter:

```yaml
---
title: Your Article Title
authors:
  - name: Your Name
    email: you@university.edu
    corresponding: true
    orcid: 0000-0000-0000-0000
    affiliations:
      - id: univ
        name: Your University
    roles:
      - Conceptualization
      - Methodology
keywords:
  - keyword1
  - keyword2
abstract: |
  Your abstract text here.
exports:
  - format: pdf
    template: path/to/elsarticle-myst
    output: article.pdf
    columns: single
---

# Introduction

Your content here...
```

### 3. Build PDF

```bash
myst build your-article.md --pdf
```

## Template Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `columns` | choice | `single` | Layout: `single` or `double` column |
| `citation_style` | choice | `authoryear` | Citation style: `authoryear` or `numbers` |
| `longmktitle` | boolean | `false` | Use if frontmatter spans multiple pages |
| `graphical_abstract` | file | — | Path to graphical abstract image |

## Document Structure

### Frontmatter Fields

```yaml
title: Article Title
subtitle: Optional Subtitle  # Displayed below main title
short_title: Short Title  # For running headers
authors:
  - name: Author Name
    email: author@example.com
    orcid: 0000-0000-0000-0000
    corresponding: true
    equal_contributor: true  # Mark as equal contribution
    deceased: false  # Mark if deceased
    note: Additional author info  # Author-specific footnote
    twitter: username  # Twitter/X handle
    affiliations:
      - institution-id
    roles:
      - Conceptualization
      - Writing – original draft
affiliations:
  - id: institution-id
    name: Institution Name
    department: Department
    city: City
    country: Country
keywords:
  - keyword1
  - keyword2
abstract: |
  Abstract text...
keypoints:  # Research highlights
  - First key finding
  - Second key finding
parts:
  title_note: Acknowledgment or note attached to title
  note: General note without numbering (e.g., disclaimers)
  appendix: appendix.md  # External appendix file
  biography: |  # Author biographies (raw LaTeX)
    \bio{}
    Author biography text...
    \endbio
bibliography:
  - references.bib
```

### CRediT Contributor Roles

Supported roles (per [CRediT taxonomy](https://credit.niso.org/)):

- Conceptualization
- Data curation
- Formal analysis
- Funding acquisition
- Investigation
- Methodology
- Project administration
- Resources
- Software
- Supervision
- Validation
- Visualization
- Writing - original draft
- Writing - review & editing

### Document Parts

Use MyST `parts` for special content:

```yaml
parts:
  appendix: appendix.md      # External appendix file
  title_note: Funding note   # Footnote on title
  note: General disclaimer   # Non-numbered note
  biography: |               # Author bios (raw LaTeX)
    \bio{}
    Biography text...
    \endbio
```

Or inline with block syntax:

```markdown
+++ {"part": "abstract"}
Your abstract here.
+++
```

## Files Included

| File | Description |
|------|-------------|
| `template.tex` | Main Jinja/jtex template |
| `template.yml` | Template configuration |
| `cas-sc.cls` | Single column document class |
| `cas-dc.cls` | Double column document class |
| `cas-common.sty` | Shared style definitions |
| `cas-model2-names.bst` | Bibliography style (author-year & numeric) |
| `example/` | Complete working example |

## Supported LaTeX Packages and Environments

The template includes comprehensive package support for scientific writing:

### Mathematics (amsmath, mathtools)
- `align`, `align*`, `alignat`, `flalign` - Aligned equations
- `gather`, `gather*` - Centered equation groups
- `multline`, `multline*` - Multi-line equations
- `subequations` - Equation sub-numbering
- `pmatrix`, `bmatrix`, `vmatrix`, `Vmatrix` - Matrix brackets
- `pmatrix*`, `bmatrix*`, `vmatrix*`, `Vmatrix*` - Matrix brackets with alignment (mathtools)

### Figures (graphicx, caption, subcaption, wrapfig, rotating)
- `figure`, `figure*` - Standard figures
- `subfigure` - Sub-figures with individual captions
- `wrapfigure` - Text-wrapped figures
- `sidewaysfigure` - Rotated full-page figures

### Tables (array, booktabs, tabularx, longtable, threeparttable)
- `table`, `table*` - Standard tables
- `tabular` - Basic table environment
- `tabularx` - Tables with auto-width columns
- `longtable` - Multi-page tables
- `threeparttable` + `tablenotes` - Tables with footnotes
- `sidewaystable` - Rotated full-page tables

### Lists (enumitem)
- `enumerate` - Numbered lists
- `itemize` - Bulleted lists
- `description` - Description lists

### Quotations (csquotes)
- `quote`, `quotation` - Standard quote blocks
- `displayquote` - Enhanced quotations with attribution

### Algorithms (algorithm, algorithmicx)
- `algorithm` - Algorithm float environment
- `algorithmic` - Algorithm pseudocode (via algpseudocode)

### Page Layout (changepage, pdflscape)
- `adjustwidth` - Adjust margins
- `landscape` - Landscape page orientation
- `minipage`, `center`, `centering` - Layout control

### Boxes (adjustbox)
- `adjustbox` - Scale, trim, and adjust content

### Additional Packages
- `hyperref` - Hyperlinks and PDF metadata
- `xcolor`, `colortbl` - Colors in text and tables
- `multirow`, `makecell` - Complex table cells
- `natbib` - Citation management
- `csquotes` - Context-sensitive quotation marks

## Example

See the `example/` directory for a comprehensive demonstration including:

- Typography (formatting, footnotes, definition lists)
- Mathematics (inline, display, custom macros)
- Formal environments (definitions, theorems, proofs)
- Admonitions (notes, warnings, tips, etc.)
- Tables (markdown, list-table, csv-table, raw LaTeX)
- Code blocks with syntax highlighting
- Figures and cross-references
- Citations and bibliography

Build the example:

```bash
cd example
myst build sample-article.md --pdf
```

## Credits

Based on the official [Elsevier CAS LaTeX templates](https://www.elsevier.com/authors/policies-and-guidelines/latex-instructions). The original LaTeX classes are copyright Elsevier Ltd and distributed under the LaTeX Project Public License (LPPL-1.3c).

## License

- **Content** (documentation, examples): [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)
- **Code** (template configuration): [MIT](https://opensource.org/licenses/MIT)
- **LaTeX classes** (`.cls`, `.sty`, `.bst`): [LPPL-1.3c](https://www.latex-project.org/lppl/lppl-1-3c/)
