---
title: A Comprehensive Guide to MyST Markdown with Elsevier CAS Templates
short_title: MyST & Elsevier Guide
description: A comprehensive template demonstrating MyST Markdown integration with Elsevier CAS journal templates.
date: 2026-01-08
authors:
  - id: alujan
    name: Alan Lujan
    email: alujan@jhu.edu
    url: https://alanlujan91.github.io
    corresponding: true
    orcid: 0000-0002-5289-7054
    github: alanlujan91
    affiliations:
      - jhu
    roles:
      - Conceptualization
      - Methodology
      - Software
      - Writing – original draft
  - id: ccarroll
    name: Christopher Carroll
    email: ccarroll@jhu.edu
    url: https://econ.jhu.edu/people/ccarroll
    orcid: 0000-0003-3732-9312
    github: llorracc
    affiliations:
      - jhu
    roles:
      - Supervision
      - Writing – review & editing
affiliations:
  - id: jhu
    name: Johns Hopkins University
    department: Department of Economics
    city: Baltimore
    state: MD
    country: USA
    ror: https://ror.org/00za53h95
    url: https://econ.jhu.edu
keywords:
  - MyST Markdown
  - Elsevier
  - LaTeX
  - CAS Template
  - Scientific Publishing
  - Reproducible Research
license:
  content: CC-BY-4.0
  code: MIT
open_access: true
github: https://github.com/alanlujan91/elsevier_myst_template
abstract: |
  This comprehensive article demonstrates all features available in MyST Markdown combined with Elsevier's CAS templates. We showcase typography, mathematical notation, cross-references, admonitions, proofs and theorems, tables, figures, code blocks, and more. This serves as both documentation and a test of template capabilities.
keypoints:
  - MyST Markdown enables reproducible scientific writing
  - Seamless export to multiple journal formats
  - Support for both single and double column layouts
  - Rich mathematical and scientific notation support
math:
  '\R': '\mathbb{R}'
  '\N': '\mathbb{N}'
  '\E': '\mathbb{E}'
  '\Var': '\text{Var}'
  '\Cov': '\text{Cov}'
  '\argmax': '\operatorname{argmax}'
abbreviations:
  MyST: Markedly Structured Text
  CAS: Content Acquisition System
  ORCID: Open Researcher and Contributor ID
  DOI: Digital Object Identifier
  PDF: Portable Document Format
thumbnail: images/thumbnail.png
parts:
  appendix: appendix.md
bibliography:
  - references.bib
downloads:
  - id: pdf-sc
    title: PDF (Single Column)
  - id: pdf-dc
    title: PDF (Double Column)
  - id: pdf-num
    title: PDF (Numbered References)
exports:
  - id: pdf-sc
    format: pdf
    template: ..
    output: exports/sample-sc.pdf
    columns: single
    graphical_abstract: images/sample-figure.png
  - id: pdf-dc
    format: pdf
    template: ..
    output: exports/sample-dc.pdf
    columns: double
    graphical_abstract: images/sample-figure.png
  - id: pdf-num
    format: pdf
    template: ..
    output: exports/sample-sc-numbers.pdf
    columns: single
    citation_style: numbers
    graphical_abstract: images/sample-figure.png
---

(sec-introduction)=
# Introduction

This document demonstrates the full integration of MyST Markdown {cite:p}`myst2023` with Elsevier's CAS templates. MyST provides a powerful authoring experience while maintaining compatibility with traditional LaTeX journal requirements {cite:p}`latex2004`.

## Background

Scientific publishing has traditionally relied on LaTeX for high-quality typesetting {cite:p}`elsevier2020`. However, the learning curve and complexity of LaTeX can be a barrier for many researchers. MyST Markdown bridges this gap by providing:

1. A familiar Markdown syntax based on CommonMark {cite:p}`markdown2004`
2. Rich scientific features (equations, citations, cross-references)
3. Export to multiple formats including PDF via LaTeX

Reproducible research workflows have become increasingly important, with tools like Jupyter Notebooks {cite:p}`jupyter2016` enabling literate programming approaches.

:::{note}
:class: dropdown
:open: true
**About this document**: This article serves as both a comprehensive guide and a test file for the Elsevier CAS MyST template. Every feature demonstrated here should render correctly in both the web preview and PDF exports.
:::

(sec-typography)=
# Typography Features

This section demonstrates MyST Markdown typography features and how they render in the PDF output.

## Inline Formatting

Standard inline formatting includes **bold text**, *italic text*, and `inline code`. You can also use {del}`strikethrough text` and {u}`underlined text` for special emphasis.

For chemical formulas, use subscripts: H{sub}`2`O, CO{sub}`2`, C{sub}`6`H{sub}`12`O{sub}`6`. For ordinals and exponents, use superscripts: the 4{sup}`th` of July, 1{sup}`st` place, x{sup}`2` + y{sup}`2` = r{sup}`2`.

## Line Breaks

The world's shortest poem demonstrates line breaks:\
Fleas\
Adam\
Had 'em.

—Strickland Gillilan

## Quotations

Block quotes are useful for highlighting important passages:

> We know what we are, but know not what we may be.
>
> — William Shakespeare, Hamlet

:::{pull-quote}
The important thing is not to stop questioning. Curiosity has its own reason for existing.
:::

:::{epigraph}
In the middle of difficulty lies opportunity.

— Albert Einstein
:::

## Definition Lists

MyST supports definition lists for glossaries or term explanations:

MyST
: Markedly Structured Text, a markdown flavor for scientific writing

LaTeX
: A document preparation system for high-quality typesetting

jtex
: A Jinja-based templating system for LaTeX documents

CAS
: Content Acquisition System, Elsevier's journal template system

## Footnotes

MyST supports footnotes[^fn1] which are automatically numbered and placed at the end of the document. You can have multiple footnotes[^fn2] throughout your text.

[^fn1]: This is a footnote demonstrating the feature. Footnotes can contain **formatted text** and even `code`.

[^fn2]: Another footnote with additional information. Footnotes are essential for academic writing.

## Task Lists

Task lists can track progress (rendered as bullet points in LaTeX):

- [x] Create template structure
- [x] Add typography examples
- [x] Add math demonstrations
- [x] Add proof environments
- [ ] Submit to journal
- [ ] Celebrate publication!

# Mathematical Content

The templates support full LaTeX math with custom macros defined in frontmatter.

## Inline Mathematics

Inline math like $E = mc^2$ or $\E[X] = \mu$ works seamlessly. Using our custom macros: for $x \in \R$, we have $\Var(X) = \E[X^2] - (\E[X])^2$.

## Display Equations

The quadratic formula:

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$ (eq:quadratic)

Maxwell's equations in differential form:

```{math}
:label: eq:maxwell

\begin{aligned}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\
\nabla \cdot \mathbf{B} &= 0 \\
\nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t} \\
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J} + \mu_0 \varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
\end{aligned}
```

The Bellman equation for dynamic programming:

$$
V(s) = \max_a \left\{ R(s, a) + \gamma \sum_{s'} P(s' | s, a) V(s') \right\}
$$ (eq:bellman)

Equations can be cross-referenced: see {eq}`eq:quadratic` for the quadratic formula and {eq}`eq:maxwell` for Maxwell's equations.

# Proofs and Theorems

MyST supports formal mathematical environments using proof directives. These are essential for mathematical and theoretical papers.

## Definitions

:::{prf:definition} Convergent Sequence
:label: def-convergent

A sequence $(a_n)$ in $\R$ is said to be *convergent* if there exists a number $L \in \R$ such that for every $\varepsilon > 0$, there exists $N \in \N$ such that for all $n > N$:
$$
|a_n - L| < \varepsilon
$$
We write $\lim_{n \to \infty} a_n = L$.
:::

:::{prf:definition} Continuous Function
:label: def-continuous

A function $f: \R \to \R$ is *continuous* at a point $c$ if for every $\varepsilon > 0$, there exists $\delta > 0$ such that:
$$
|x - c| < \delta \implies |f(x) - f(c)| < \varepsilon
$$
:::

## Theorems

:::{prf:theorem} Squeeze Theorem
:label: thm-squeeze

Let $(a_n)$, $(b_n)$, and $(c_n)$ be sequences such that $a_n \leq b_n \leq c_n$ for all $n \geq N_0$. If
$$
\lim_{n \to \infty} a_n = \lim_{n \to \infty} c_n = L
$$
then $\lim_{n \to \infty} b_n = L$.
:::

:::{prf:theorem} Fundamental Theorem of Calculus
:label: thm-ftc

Let $f$ be continuous on $[a, b]$ and let $F$ be defined by $F(x) = \int_a^x f(t) \, dt$. Then:
1. $F$ is continuous on $[a, b]$
2. $F$ is differentiable on $(a, b)$ and $F'(x) = f(x)$
3. $\int_a^b f(x) \, dx = F(b) - F(a)$
:::

## Proofs

:::{prf:proof}
:label: prf-squeeze
:nonumber:

*Proof of {prf:ref}`thm-squeeze`.*
Let $\varepsilon > 0$ be given. Since $a_n \to L$ and $c_n \to L$, there exist $N_1, N_2 \in \N$ such that:
- $|a_n - L| < \varepsilon$ for all $n > N_1$
- $|c_n - L| < \varepsilon$ for all $n > N_2$

Let $N = \max\{N_0, N_1, N_2\}$. For $n > N$, we have:
$$
L - \varepsilon < a_n \leq b_n \leq c_n < L + \varepsilon
$$
Thus $|b_n - L| < \varepsilon$, completing the proof.
:::

## Lemmas and Corollaries

:::{prf:lemma} Triangle Inequality
:label: lem-triangle

For all $x, y \in \R$, we have $|x + y| \leq |x| + |y|$.
:::

:::{prf:corollary}
:label: cor-bounded

If $(b_n)$ is squeezed between two sequences converging to zero, then $b_n \to 0$.
:::

## Remarks and Examples

:::{prf:remark}
:label: rem-notation

The proof directives ({prf:ref}`def-convergent`, {prf:ref}`thm-squeeze`) are automatically numbered and can be cross-referenced throughout the document.
:::

:::{prf:example} Convergent Sequence
:label: ex-convergent

The sequence $a_n = \frac{1}{n}$ converges to $0$. For any $\varepsilon > 0$, choose $N > \frac{1}{\varepsilon}$. Then for $n > N$:
$$
\left| \frac{1}{n} - 0 \right| = \frac{1}{n} < \frac{1}{N} < \varepsilon
$$
:::

# Admonitions

Admonitions (callouts) are useful for highlighting important information. MyST supports many types:

:::{note}
This is a note admonition. Use it to highlight supplementary information that readers should be aware of.
:::

:::{warning}
This is a warning. Use it to alert readers about potential pitfalls or important caveats in your methodology.
:::

:::{tip}
Tips can provide helpful suggestions for readers applying your methods.
:::

:::{important}
Important information that readers must not miss should go in this type of admonition.
:::

:::{hint}
:class: dropdown

Hints can be hidden in dropdowns! Click to reveal.

This hint contains the secret formula: $e^{i\pi} + 1 = 0$
:::

:::{caution}
Caution: Proceed carefully when implementing this algorithm with large datasets.
:::

:::{attention}
Attention: New methodology introduced in this section differs from previous work.
:::

:::{danger}
**Danger**: Do not run this code in production without proper testing!
:::

:::{error}
Error: This approach will fail if the input matrix is singular.
:::

:::{seealso}
For more information on MyST Markdown features, visit the [MyST documentation](https://mystmd.org/guide).
:::

# Code Blocks

Code blocks with syntax highlighting are supported:

```{code-block} python
:caption: Example Python implementation of the quadratic formula
:label: code-quadratic
:linenos:
:emphasize-lines: 7-9

import numpy as np
from typing import Tuple

def quadratic_formula(a: float, b: float, c: float) -> Tuple[float, float]:
    """Solve ax^2 + bx + c = 0 using the quadratic formula."""
    discriminant = b**2 - 4*a*c
    if discriminant < 0:
        raise ValueError("No real solutions")
    x1 = (-b + np.sqrt(discriminant)) / (2*a)
    x2 = (-b - np.sqrt(discriminant)) / (2*a)
    return x1, x2

# Example usage
roots = quadratic_formula(1, -5, 6)
print(f"Roots: {roots}")  # Output: (3.0, 2.0)
```

As shown in {ref}`code-quadratic`, code can be captioned, numbered, and cross-referenced.

Multiple languages are supported:

```{code-block} julia
:caption: Julia implementation
:label: code-julia

function quadratic_formula(a, b, c)
    discriminant = b^2 - 4*a*c
    x1 = (-b + sqrt(discriminant)) / (2*a)
    x2 = (-b - sqrt(discriminant)) / (2*a)
    return x1, x2
end
```

# Tables

## Markdown Tables

MyST tables convert cleanly to LaTeX:

:::{table} Comparison of numerical methods
:label: tbl:methods

| Method | Accuracy | Speed | Memory |
|--------|----------|-------|--------|
| Baseline | 85.2% | Fast | Low |
| Proposed | **92.1%** | Medium | Medium |
| Ensemble | 94.3% | Slow | High |
| Oracle | 98.5% | N/A | N/A |
:::

Results are summarized in {ref}`tbl:methods`.

## List Tables

List tables provide an alternative syntax useful for complex content:

```{list-table} Dataset characteristics
:header-rows: 1
:label: tbl:dataset

* - Dataset
  - Training Samples
  - Test Samples
  - Features
  - Classes
* - MNIST
  - 60,000
  - 10,000
  - 784
  - 10
* - CIFAR-10
  - 50,000
  - 10,000
  - 3,072
  - 10
* - ImageNet
  - 1,281,167
  - 50,000
  - 150,528
  - 1,000
```

## CSV Tables

```{csv-table} Experimental results
:header-rows: 1
:label: tbl:csv

Model,Accuracy,Precision,Recall,F1-Score
Logistic Regression,0.82,0.81,0.83,0.82
Random Forest,0.89,0.88,0.90,0.89
Neural Network,0.94,0.93,0.95,0.94
Transformer,0.97,0.96,0.97,0.97
```

## Raw LaTeX Tables

For complex tables requiring advanced features, use raw LaTeX blocks. The CAS templates include `booktabs`, `multirow`, `makecell`, `array`, and `dcolumn` packages:

```{raw} latex
\begin{table}[h]
\centering
\caption{Comprehensive table showcasing CAS template features}
\label{tbl:complex}
\begin{tabular}{@{}l l c D{.}{.}{2.2} r @{}}
\toprule
\multicolumn{2}{c}{\textbf{Category}} & \multicolumn{3}{c}{\textbf{Measurements}} \\
\cmidrule(lr){1-2} \cmidrule(lr){3-5}
Type & \makecell{Description\\(details)} & Status & \multicolumn{1}{c}{Value} & Count \\
\midrule
\multirow{3}{*}{Group A} 
  & Item 1 & Yes & 12.34 & 100 \\
  & Item 2 & Yes & 5.67 & 250 \\
  & Item 3 & -- & 89.01 & 50 \\
\midrule
\multirow{2}{*}{Group B}
  & Item 4 & Yes & 23.45 & 175 \\
  & Item 5 & -- & 6.78 & 320 \\
\bottomrule
\end{tabular}

\vspace{1ex}
\small\textit{Features: \texttt{booktabs} rules, \texttt{multirow} row spanning, \texttt{makecell} line breaks, \texttt{dcolumn} decimal alignment, \texttt{array} column formatting.}
\end{table}
```

# Figures and Images

```{figure} images/sample-figure.png
:name: fig-sample
:width: 80%
:align: center

A sample figure demonstrating image support in the template. This figure shows a placeholder image that would typically contain research results or visualizations. Figures are automatically numbered and can be cross-referenced.
```

As shown in {ref}`fig-sample`, the template properly handles figure placement and captions.

# Cross-References Summary

This document demonstrates various cross-reference capabilities:

- **Equations**: {eq}`eq:quadratic`, {eq}`eq:maxwell`, {eq}`eq:bellman`
- **Figures**: {ref}`fig-sample`
- **Tables**: {ref}`tbl:methods`, {ref}`tbl:dataset`, {ref}`tbl:csv`
- **Code**: {ref}`code-quadratic`, {ref}`code-julia`
- **Theorems**: {prf:ref}`thm-squeeze`, {prf:ref}`thm-ftc`
- **Definitions**: {prf:ref}`def-convergent`, {prf:ref}`def-continuous`
- **Lemmas**: {prf:ref}`lem-triangle`
- **Corollaries**: {prf:ref}`cor-bounded`
- **Examples**: {prf:ref}`ex-convergent`
- **Sections**: [Introduction](#sec-introduction), [Typography](#sec-typography)

# Discussion

This approach enables researchers to write in MyST Markdown while producing publication-ready documents that meet Elsevier's submission requirements.

## Advantages

1. **Reproducibility**: Source files are plain text and version-controllable
2. **Flexibility**: Single source exports to HTML, PDF, and other formats
3. **Modern tooling**: Integration with Jupyter, VS Code, and other tools
4. **Rich features**: Full LaTeX math, cross-references, and citations

## Limitations

:::{warning}
Some MyST features render only in HTML output. For PDF, consider using LaTeX-compatible alternatives.
:::

# Conclusion

The Elsevier CAS MyST template provides a modern workflow for scientific writing while maintaining compatibility with traditional journal submission systems. This document has demonstrated:

- Typography: formatting, footnotes, definition lists
- Mathematics: inline, display, custom macros
- Formal environments: definitions, theorems, proofs, examples
- All admonition types
- Multiple table formats
- Code blocks with syntax highlighting
- Figures with cross-referencing
- Citations and bibliography

For questions or contributions, please visit the template repository.
