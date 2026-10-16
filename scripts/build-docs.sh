#!/bin/sh
# Builds the lab instructions: docs/labN.md -> build/docs/labN.pdf.
# Markdown is the only source. pandoc turns it into Typst, Typst makes the PDF.
#
#   scripts/build-docs.sh
#
# Needs pandoc (3.x) and typst. Only the fonts bundled with Typst and the ones
# in docs/fonts are used, so the PDFs look the same on every machine and in CI.

cd "$(dirname "$0")/.." || exit 1

mkdir -p build/docs
status=0
for source in docs/lab*.md; do
    name=$(basename "$source" .md)
    echo "$source -> build/docs/$name.pdf"
    pandoc "$source" --from gfm+smart --to typst --standalone \
        --shift-heading-level-by=-1 \
        --template docs/pandoc.typ \
        --lua-filter docs/links.lua \
        --output "build/docs/$name.typ" &&
        typst compile --ignore-system-fonts --font-path docs/fonts --root . \
            "build/docs/$name.typ" "build/docs/$name.pdf" || status=1
done
exit $status
