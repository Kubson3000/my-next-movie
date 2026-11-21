#!/bin/sh
# Builds the lab instructions: docs/labN.md -> docs/labN.pdf.
# Markdown is the source. pandoc turns it into Typst, Typst makes the PDF.
# The PDFs are committed next to the Markdown, so students get them with git pull.
# Run this after every change in docs/ and commit the PDFs too.
#
#   scripts/build-docs.sh
#
# Needs pandoc (3.x) and typst. Only the fonts bundled with Typst and the ones
# in docs/fonts are used, so the PDFs look the same on every machine and in CI.

cd "$(dirname "$0")/.." || exit 1

mkdir -p build/docs
status=0

# Diagrams first: docs/diagrams/name.typ -> docs/diagrams/name.svg.
# Files starting with _ hold the shared style. The SVGs are committed,
# so GitHub shows them in the Markdown too.
for source in docs/diagrams/[!_]*.typ; do
    typst compile --ignore-system-fonts --font-path docs/fonts --root . \
        "$source" "${source%.typ}.svg" || status=1
done

# From lab 7 on the PDFs have two columns, like an IEEE article.
# Labs 1 to 6 keep one column, the way students already have them.
first_two_column_lab=7

for source in docs/lab*.md; do
    name=$(basename "$source" .md)
    # Labs 1 to 6 keep curly quotes too. From lab 7 on the text stays plain
    # ASCII, the way students type it: "..." and straight quotes.
    columns=1
    markdown=gfm+smart
    if [ "${name#lab}" -ge "$first_two_column_lab" ]; then
        columns=2
        markdown=gfm
    fi
    echo "$source -> docs/$name.pdf ($columns)"
    pandoc "$source" --from "$markdown" --to typst --standalone \
        --metadata columns="$columns" \
        --shift-heading-level-by=-1 \
        --wrap=none \
        --template docs/pandoc.typ \
        --lua-filter docs/images.lua \
        --lua-filter docs/checklist.lua \
        --lua-filter docs/links.lua \
        --lua-filter docs/typography.lua \
        --output "build/docs/$name.typ" &&
        typst compile --ignore-system-fonts --font-path docs/fonts --root . \
            "build/docs/$name.typ" "docs/$name.pdf" || status=1
done
exit $status
