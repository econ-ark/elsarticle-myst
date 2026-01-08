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
abstract: |
  This is a sample article demonstrating the use of MyST Markdown with Elsevier's CAS templates. The template supports both single-column and double-column layouts, making it suitable for various Elsevier journals. We demonstrate the key features including author metadata, affiliations, keywords, and structured content.
keypoints:
  - MyST Markdown enables reproducible scientific writing
  - Seamless export to multiple journal formats
  - Support for both single and double column layouts
parts:
  appendix: appendix.md
bibliography:
  - references.bib
exports:
  - format: pdf
    template: ..
    output: exports/sample-sc.pdf
    columns: single
    graphical_abstract: images/sample-figure.png
  - format: pdf
    template: ..
    output: exports/sample-dc.pdf
    columns: double
    graphical_abstract: images/sample-figure.png
  - format: pdf
    template: ..
    output: exports/sample-sc-numbers.pdf
    columns: single
    citation_style: numbers
    graphical_abstract: images/sample-figure.png
---

# Introduction

This document demonstrates the integration of {abbr}`MyST (Markedly Structured Text)` Markdown {cite:p}`myst2023` with Elsevier's {abbr}`CAS (Content Acquisition System)` templates. MyST provides a powerful authoring experience while maintaining compatibility with traditional LaTeX journal requirements {cite:p}`latex2004`.

## Background

Scientific publishing has traditionally relied on LaTeX for high-quality typesetting {cite:p}`elsevier2020`. However, the learning curve and complexity of LaTeX can be a barrier for many researchers. MyST Markdown bridges this gap by providing:

1. A familiar Markdown syntax based on CommonMark {cite:p}`markdown2004`
2. Rich scientific features (equations, citations, cross-references)
3. Export to multiple formats including PDF via LaTeX

Reproducible research workflows have become increasingly important, with tools like Jupyter Notebooks {cite:p}`jupyter2018` enabling literate programming approaches.

# Typography Features

This section demonstrates MyST Markdown typography features and how they render in the PDF output.

## Inline Formatting

Standard inline formatting includes **bold text**, *italic text*, and `inline code`. You can also use {del}`strikethrough text` and {u}`underlined text` for special emphasis.

For chemical formulas, use subscripts: H{sub}`2`O, CO{sub}`2`. For ordinals, use superscripts: the 4{sup}`th` of July, 1{sup}`st` place.

## Quotations

Block quotes are useful for highlighting important passages:

> We know what we are, but know not what we may be.
>
> -- William Shakespeare, Hamlet

## Definition Lists

MyST supports definition lists for glossaries or term explanations:

MyST
: Markedly Structured Text, a markdown flavor for scientific writing

LaTeX
: A document preparation system for high-quality typesetting

jtex
: A Jinja-based templating system for LaTeX documents

## Footnotes

MyST supports footnotes[^fn1] which are automatically numbered and placed at the end of the document. You can have multiple footnotes[^fn2] throughout your text.

[^fn1]: This is a footnote demonstrating the feature. Footnotes can contain **formatted text** and even `code`.

[^fn2]: Another footnote with additional information.

## Task Lists

Task lists can track progress (rendered as bullet points in LaTeX):

- [x] Create template structure
- [x] Add typography examples
- [ ] Submit to journal

# Proofs and Theorems

MyST supports formal mathematical environments using proof directives. These are essential for mathematical and theoretical papers.

## Definitions and Theorems

:::{prf:definition} Convergent Sequence
:label: def-convergent

A sequence $(a_n)$ in $\mathbb{R}$ is said to be *convergent* if there exists a number $L \in \mathbb{R}$ such that for every $\varepsilon > 0$, there exists $N \in \mathbb{N}$ such that for all $n > N$:
$$
|a_n - L| < \varepsilon
$$
We write $\lim_{n \to \infty} a_n = L$.
:::

:::{prf:theorem} Squeeze Theorem
:label: thm-squeeze

Let $(a_n)$, $(b_n)$, and $(c_n)$ be sequences such that $a_n \leq b_n \leq c_n$ for all $n \geq N_0$. If
$$
\lim_{n \to \infty} a_n = \lim_{n \to \infty} c_n = L
$$
then $\lim_{n \to \infty} b_n = L$.
:::

## Proofs and Corollaries

:::{prf:proof}
:label: prf-squeeze

Let $\varepsilon > 0$ be given. Since $a_n \to L$ and $c_n \to L$, there exist $N_1, N_2 \in \mathbb{N}$ such that:
- $|a_n - L| < \varepsilon$ for all $n > N_1$
- $|c_n - L| < \varepsilon$ for all $n > N_2$

Let $N = \max\{N_0, N_1, N_2\}$. For $n > N$, we have:
$$
L - \varepsilon < a_n \leq b_n \leq c_n < L + \varepsilon
$$
Thus $|b_n - L| < \varepsilon$, completing the proof.
:::

:::{prf:corollary}
:label: cor-bounded

If $(b_n)$ is squeezed between two sequences converging to zero, then $b_n \to 0$.
:::

## Lemmas and Remarks

:::{prf:lemma} Triangle Inequality
:label: lem-triangle

For all $x, y \in \mathbb{R}$, we have $|x + y| \leq |x| + |y|$.
:::

:::{prf:remark}
:label: rem-notation

The proof directives ({prf:ref}`def-convergent`, {prf:ref}`thm-squeeze`) are automatically numbered and can be cross-referenced throughout the document.
:::

# Methods

We use the standard CAS template structure provided by Elsevier, adapted for use with the `jtex` templating system.

## Mathematical Content

The templates support full LaTeX math. For example, the quadratic formula:

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$ (eq:quadratic)

And inline math like $E = mc^2$. Equations can be cross-referenced: see {eq}`eq:quadratic`.

## Tables

MyST tables convert cleanly to LaTeX:

| Method | Accuracy | Speed |
|--------|----------|-------|
| Baseline | 85.2% | Fast |
| Proposed | **92.1%** | Medium |
| Oracle | 98.5% | Slow |

: Comparison of different methods {#tbl:comparison}

# Results

The template successfully renders:

- Author information with ORCID
- Multiple affiliations  
- CRediT author contributions
- Keywords
- Abstract and highlights
- Full document content

```{figure} images/sample-figure.png
:name: fig-sample
:width: 80%

A sample figure demonstrating image support in the template. This figure shows a placeholder image that would typically contain research results or visualizations.
```

As shown in {ref}`fig-sample`, the template properly handles figure placement and captions.

# Discussion

This approach enables researchers to write in MyST Markdown while producing publication-ready documents that meet Elsevier's submission requirements.

# Conclusion

The Elsevier CAS MyST template provides a modern workflow for scientific writing while maintaining compatibility with traditional journal submission systems.