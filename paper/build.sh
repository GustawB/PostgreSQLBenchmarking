#!/bin/sh
# Builds paper.pdf (two-column) from paper.md. Requires pandoc and TeX Live.
cd "$(dirname "$0")"
pandoc paper.md -o paper.pdf \
  --lua-filter=twocolumn.lua \
  -V documentclass=article -V classoption=twocolumn \
  -V geometry:margin=2cm -V fontsize=10pt -V colorlinks=true \
  -H preamble.tex
