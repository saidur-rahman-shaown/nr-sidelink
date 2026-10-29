# LaTeX version of the study report

`main.tex` is the report (title page, executive summary, Parts A-C, limits, glossary, references);
`figures/` holds every figure it includes, copied from `../figures/study/`.

Build (needs a TeX distribution, e.g. MacTeX):

    pdflatex main.tex && pdflatex main.tex     # twice, for the contents and cross-references

The title page shows `figures/wici.jpg` if that file exists, and a red placeholder otherwise.
