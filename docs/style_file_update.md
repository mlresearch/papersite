# PMLR Style File Documentation Update

## Summary

Updated the PMLR FAQ to provide clear, comprehensive instructions for using the CTAN jmlr package for both single-column and double-column formats.

## Issue

The user reported that a link to `http://www.jmlr.org/papers/format/pmlr-v1.sty` was broken (404 error). While I couldn't locate this specific link in the current codebase, the FAQ's instructions about style files were improved to provide clearer guidance.

## CTAN jmlr Package Information

The `jmlr` LaTeX package on CTAN provides **both** single-column and double-column formats:

### Package Links
- **Main package page**: https://ctan.org/pkg/jmlr
- **Direct archive access**: https://ctan.org/tex-archive/macros/latex/contrib/jmlr

### Usage

**For double-column format (PMLR style):**
```latex
\documentclass[pmlr,twocolumn]{jmlr}
```
This is used for some PMLR proceedings (e.g., AISTATS volumes).

**For single-column format (PMLR style):**
```latex
\documentclass[pmlr]{jmlr}
```
This is the default single-column PMLR format.

**For single-column format (standard JMLR style):**
```latex
\documentclass{jmlr}
```
This is similar to the standard Journal of Machine Learning Research style.

The `pmlr` option sets the header to "Proceedings of Machine Learning Research". The `twocolumn` option enables two-column layout when needed.

### Installation

The package is included in most modern LaTeX distributions (TeX Live, MiKTeX) by default. For manual installation:
- Download from CTAN
- Use your TeX distribution's package manager
- Available through MikTeX Package Manager or TeX Live Manager

## Changes Made

### Updated File: `/Users/neil/mlresearch/mlresearch.github.io/faq.html`

**Section: "What is the Style File for the Proceedings?"**

Enhanced this section to include:
1. Clear statement that the jmlr class supports both single and double-column formats
2. Direct links to CTAN (both package page and archive)
3. Explicit usage instructions with code examples for both formats
4. Installation guidance
5. Note about automatic header configuration
6. **New:** Links to downloadable sample LaTeX files

### Created Sample Files

**File:** `/Users/neil/mlresearch/mlresearch.github.io/assets/examples/pmlr-sample-single-column.tex`
- Complete working example of single-column PMLR format
- Includes examples of: title/authors, abstract, equations, figures, tables, algorithms, bibliography
- Uses `\documentclass[pmlr]{jmlr}`

**File:** `/Users/neil/mlresearch/mlresearch.github.io/assets/examples/pmlr-sample-double-column.tex`
- Complete working example of double-column PMLR format
- Includes examples of: single-column and double-column figures/tables, equations, algorithms
- Uses `\documentclass[pmlr,twocolumn]{jmlr}`
- Demonstrates use of `figure*` and `table*` for spanning both columns

## Benefits

✅ **Clearer instructions**: Users now have explicit LaTeX code examples  
✅ **Both formats documented**: Single and double-column usage is clearly explained  
✅ **Working links**: All links point to the active CTAN repository  
✅ **Installation help**: Guidance on how to obtain the package  
✅ **Self-contained**: Users don't need to hunt for documentation elsewhere  

## Next Steps

1. ✅ Documentation updated in FAQ
2. Consider if additional documentation updates are needed in:
   - spec.html (submission format specification)
   - Pull request templates
   - Volume repository READMEs

## Additional Notes

- The old link `http://www.jmlr.org/papers/format/pmlr-v1.sty` was not found in the current codebase
- It may have existed in older versions or on external documentation
- The CTAN package is the official, maintained source for the jmlr/PMLR styles
- Package is maintained by Nicola Talbot since 2010

## References

- CTAN jmlr package: https://ctan.org/pkg/jmlr
- Package author: Nicola Talbot (http://theoval.cmp.uea.ac.uk/~nlct/)
- PMLR website: https://proceedings.mlr.press/

