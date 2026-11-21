// Style for the lab PDFs. One column looks like a LaTeX article (labs 1 to 6).
// Two columns look like an IEEE article (IEEEtran): small margins, 10 pt text,
// the title across both. scripts/build-docs.sh picks the number of columns.
// scripts/build-docs.sh turns docs/labN.md into Typst with pandoc,
// using docs/pandoc.typ, which applies this template.
//
// Fonts: New Computer Modern ships with Typst, the mono variant is in
// docs/fonts. DejaVu Sans Mono, also built in, only fills in symbols
// Computer Modern lacks, like the keyboard shortcuts ⌘ ⇧ ⌥.

#let course = "Zaawansowane programowanie na platformę iOS"

#let lab(title: none, columns: 1, body) = {
  let two-columns = columns == 2
  // No creation date in the PDF: the same source always gives the same file,
  // so git sees a change only when the content changes.
  set document(date: none)
  set document(title: title)
  // Two columns: margins and column gap close to IEEEtran on A4.
  set page(
    paper: "a4",
    margin: if two-columns {
      (x: 1.7cm, top: 1.9cm, bottom: 2.4cm)
    } else {
      (x: 3cm, top: 3cm, bottom: 3.2cm)
    },
    columns: columns,
    numbering: "1",
  )
  set std.columns(gutter: 0.5cm)
  set text(
    font: ("New Computer Modern", "DejaVu Sans Mono"),
    lang: "pl",
    size: if two-columns { 10pt } else { 11pt },
    // No widows or orphans: a paragraph never leaves a single line at the bottom
    // or the top of a page. A last line with one short word (a runt) costs extra too.
    costs: (widow: 10000%, orphan: 10000%, runt: 300%),
  )
  set par(
    justify: true,
    leading: 0.55em,
    spacing: 0.55em,
    first-line-indent: 1.5em,
  )

  // Sections unnumbered, like \section* and \subsection*.
  show heading: set text(weight: "bold")
  show heading: set block(above: 1.8em, below: 1em)
  show heading.where(level: 1): set text(size: if two-columns { 12pt } else { 14.4pt })
  show heading.where(level: 2): set text(size: if two-columns { 11pt } else { 12pt })
  show heading.where(level: 3): set text(size: if two-columns { 10pt } else { 11pt })
  show heading.where(level: 3): set block(above: 1.4em, below: 0.8em)

  set list(indent: 1em, marker: ([•], [--]))
  set enum(indent: 1em)
  // Lists here are short, so a list stays on one page: no lone item at the top.
  show list: set block(above: 0.9em, below: 0.9em, breakable: false)
  show enum: set block(above: 0.9em, below: 0.9em, breakable: false)
  // In a narrow column a justified list item with a long name or a link gets
  // wide gaps between words, so there list items are left aligned.
  show list: set par(justify: not two-columns)
  show enum: set par(justify: not two-columns)

  // Code in Computer Modern typewriter, blocks indented like verbatim.
  // Typst shrinks raw text to 0.8em, 1.25em brings it back to the body size, like \texttt.
  show raw: set text(font: ("New Computer Modern Mono", "DejaVu Sans Mono"), size: 1.25em)
  // In two columns code blocks are 7.5 pt, like listings in IEEE papers,
  // so a line of about 60 characters fits in one column.
  show raw.where(block: true): set text(size: if two-columns { 0.75em } else { 0.9em })
  // A code block is never split between pages.
  show raw.where(block: true): it => block(
    width: 100%,
    breakable: false,
    above: 1em,
    below: 1em,
    inset: (left: if two-columns { 0.6em } else { 1.5em }),
    it,
  )

  // Tables like booktabs: rules only above, below and under the header.
  set table(stroke: none, inset: (x: 6pt, y: 4pt))
  set table.hline(stroke: 0.5pt)
  show table: set align(left)
  show table: set par(justify: false, first-line-indent: 0em)
  show table.cell.where(y: 0): strong
  show table: it => block(stroke: (top: 0.8pt, bottom: 0.8pt), it)
  // A long table may continue on the next page, with its header repeated,
  // instead of leaving half a page empty.
  show figure: set block(above: 1.2em, below: 1.2em, breakable: true)

  show link: set text(fill: rgb("#1f3b8f"))

  // Title like \maketitle, across both columns when there are two.
  if two-columns {
    place(top + center, scope: "parent", float: true, block(below: 1.5em)[
      #text(size: 20pt, title)
      #v(0.6em)
      #text(size: 11pt, course)
    ])
  } else {
    align(center, block(above: 0.5em, below: 2.2em)[
      #text(size: 17.28pt, title)
      #v(0.8em)
      #text(size: 12pt, course)
    ])
  }

  body
}
