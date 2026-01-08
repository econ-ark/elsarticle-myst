---
title: A Sample Article for Elsevier CAS Template
short_title: Sample Article
authors:
  - name: Alan Lujan
    email: alujan@jhu.edu
    corresponding: true
    orcid: 0000-0000-0000-0000
    affiliations:
      - Johns Hopkins University
    roles:
      - Conceptualization
      - Methodology
      - Software
  - name: Jane Doe
    affiliations:
      - MIT
    roles:
      - Validation
      - Writing - Review & Editing
affiliations:
  - id: jhu
    name: Johns Hopkins University
    city: Baltimore
    state: MD
    country: USA
  - id: mit  
    name: Massachusetts Institute of Technology
    city: Cambridge
    state: MA
    country: USA
keywords:
  - MyST Markdown
  - Elsevier
  - LaTeX
  - CAS Template
exports:
  - format: pdf
    template: ..
    output: exports/sample-sc.pdf
    columns: single
  - format: pdf
    template: ..
    output: exports/sample-dc.pdf
    columns: double
---

+++ {"part": "abstract"}
This is a sample article demonstrating the use of MyST Markdown with Elsevier's CAS templates. The template supports both single-column and double-column layouts, making it suitable for various Elsevier journals. We demonstrate the key features including author metadata, affiliations, keywords, and structured content.
+++

+++ {"part": "highlights"}
```{raw} latex
\item MyST Markdown enables reproducible scientific writing
\item Seamless export to multiple journal formats
\item Support for both single and double column layouts
```
+++

# Introduction

This document demonstrates the integration of MyST Markdown with Elsevier's CAS (Content Acquisition System) templates. MyST provides a powerful authoring experience while maintaining compatibility with traditional LaTeX journal requirements.

## Background

Scientific publishing has traditionally relied on LaTeX for high-quality typesetting. However, the learning curve and complexity of LaTeX can be a barrier for many researchers. MyST Markdown bridges this gap by providing:

1. A familiar Markdown syntax
2. Rich scientific features (equations, citations, cross-references)
3. Export to multiple formats including PDF via LaTeX

# Methods

We use the standard CAS template structure provided by Elsevier, adapted for use with the `jtex` templating system.

## Mathematical Content

The templates support full LaTeX math. For example, the quadratic formula:

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$

And inline math like $E = mc^2$.

# Results

The template successfully renders:

- Author information with ORCID
- Multiple affiliations
- CRediT author contributions
- Keywords
- Abstract and highlights
- Full document content

# Discussion

This approach enables researchers to write in MyST Markdown while producing publication-ready documents that meet Elsevier's submission requirements.

# Conclusion

The Elsevier CAS MyST template provides a modern workflow for scientific writing while maintaining compatibility with traditional journal submission systems.

+++ {"part": "appendix"}

# Supplementary Methods

This appendix provides additional methodological details that support the main text.

## Data Processing

The data was processed using standard procedures as described in the literature.

# Additional Tables

| Parameter | Value | Unit |
|-----------|-------|------|
| Alpha | 0.05 | - |
| Beta | 1.23 | m/s |
| Gamma | 456 | kg |

+++