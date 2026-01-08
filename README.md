# Elsevier CAS Template for MyST

A MyST Markdown template for Elsevier journal articles using the CAS (Content Acquisition System) document classes.

![](thumbnail.png)

- **Author:** Alan Lujan (Johns Hopkins University)
- **Website:** https://github.com/alanlujan91
- **Source:** [Elsevier LaTeX Instructions](https://www.elsevier.com/authors/policies-and-guidelines/latex-instructions)
- **License:** LPPL-1.3c

## Features

- Supports both **single column** (`cas-sc`) and **double column** (`cas-dc`) layouts
- Author-year or numeric citation styles
- Author metadata with ORCID, email, and CRediT roles
- Research highlights and graphical abstracts
- Keywords support

## Usage

Add to your MyST document frontmatter:

```yaml
---
title: Your Article Title
authors:
  - name: First Author
    email: author@example.com
    corresponding: true
    orcid: 0000-0000-0000-0000
    affiliations:
      - Your Institution
    roles:
      - Conceptualization
      - Methodology
keywords:
  - keyword1
  - keyword2
exports:
  - format: pdf
    template: path/to/elsevier_cas
    output: exports/article.pdf
    columns: single  # or "double"
---
```

## Template Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `columns` | choice | `single` | Layout: `single` or `double` column |
| `longmktitle` | boolean | `false` | Use if frontmatter spans multiple pages |
| `citation_style` | choice | `authoryear` | Citation style: `authoryear` or `numbers` |

## Document Parts

Define parts using MyST block syntax:

```markdown
+++ {"part": "abstract"}
Your abstract text here.
+++

+++ {"part": "highlights"}
```{raw} latex
\item First highlight
\item Second highlight
\item Third highlight
```
+++
```

## Building

```bash
myst build your-article.md --pdf
```

## Files Included

- `template.tex` - Main jtex template
- `cas-sc.cls` - Single column document class
- `cas-dc.cls` - Double column document class
- `cas-common.sty` - Shared style definitions
- `cas-model2-names.bst` - Bibliography style
- `thumbnails/` - Social media icons for author info

## Credits

Based on the official Elsevier CAS templates. The original templates are copyright Elsevier Ltd and distributed under the LaTeX Project Public License.
