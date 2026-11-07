// Shared look of the lab diagrams: black and white, the fonts of the PDFs.
// scripts/build-docs.sh turns every docs/diagrams/*.typ (except files
// starting with _) into an SVG next to it. The labs show the SVG, so GitHub
// and the PDF show the same picture.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/chronos:0.2.1"
#import "@preview/cetz:0.3.4"

// Apple services, TMDB, OpenRouter: what the students do not write.
#let outside = luma(232)
#let note = luma(110)
#let line-width = 0.6pt

#let setup(body) = {
  set page(width: auto, height: auto, margin: 4pt, fill: white)
  set text(font: "New Computer Modern", size: 9pt, lang: "pl")
  body
}

// A UML class box: <<stereotype>> in guillemets, name, fields, methods.
#let uml(name, stereotype: "struct", fields: (), methods: (), fill: white) = {
  let header = align(center)[
    #text(size: 7.5pt)[#str.from-unicode(171)#stereotype#str.from-unicode(187)] \
    #strong(name)
  ]
  let cells = (header,)
  if fields.len() > 0 {
    cells.push(fields.join(linebreak()))
  }
  if methods.len() > 0 {
    cells.push(methods.join(linebreak()))
  }
  table(
    columns: 1,
    align: left,
    fill: fill,
    stroke: line-width,
    inset: (x: 6pt, y: 4pt),
    ..cells,
  )
}

// A database table for an ERD: name, then column, type, key.
#let db-table(name, columns, fill: white) = {
  table(
    columns: 3,
    align: left,
    fill: fill,
    stroke: (x, y) => if y == 0 { line-width } else {
      (left: if x == 0 { line-width }, right: if x == 2 { line-width },
       bottom: line-width)
    },
    inset: (x: 5pt, y: 3.5pt),
    column-gutter: 0pt,
    table.cell(colspan: 3, align: center, strong(name)),
    ..columns.flatten(),
  )
}

// For the diagrams of tables and classes: the table draws the box.
#let boxes = (
  node-inset: 0pt,
  node-shape: rect,
  edge-stroke: line-width,
)

// A database relation drawn as "1" at one end and "n" at the other.
#let one-to-many(one, many) = (
  edge(one, many, "-", label: [1], label-pos: 0.2, label-side: center, label-fill: white),
  edge(one, many, stroke: none, label: [n], label-pos: 0.7, label-side: center, label-fill: white),
)

// A box with a name and a short grey line under it.
#let named(name, detail) = [#name \ #text(fill: note, detail)]

#let flow = (
  node-stroke: line-width,
  node-shape: rect,
  node-corner-radius: 3pt,
  node-inset: 6pt,
  edge-stroke: line-width,
  spacing: (22pt, 22pt),
)
