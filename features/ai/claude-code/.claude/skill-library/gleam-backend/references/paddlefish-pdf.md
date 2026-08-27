# PDF Generation with Paddlefish

Use `paddlefish` for pure-Gleam PDF generation with no external dependencies (no headless Chrome, no system libraries). Suitable for invoices, reports, and simple documents.

## Installation

```sh
gleam add paddlefish@1
gleam add simplifile  # for writing PDF to disk
```

## Core Concepts

- **Coordinate system**: origin is bottom-left, units are points (1 point = 0.353mm)
- **Builder pattern**: all types are opaque, constructed and modified via pipe chains
- **Single module**: everything lives in `paddlefish` — no sub-modules
- **14 standard PDF fonts**: Helvetica, Times-Roman, Courier, and their Bold/Italic variants

## Types

| Type | Description |
|---|---|
| `Document` | Opaque — the full PDF being built |
| `Page` | Opaque — a single page with content |
| `Text` | Opaque — positioned text element |
| `Rectangle` | Opaque — rectangle with optional fill/stroke |
| `Path` | Opaque — open path made of line segments |
| `Shape` | Opaque — closed path that can be filled |
| `Image` | Opaque — JPEG image to draw on page |
| `PageSize` | Record — `width: Float, height: Float` in points |
| `ImageError` | `UnsupportedImageFormat(String)` or `UnknownImageFormat` |

## Quick Start

```gleam
import paddlefish as pdf
import simplifile

pub fn main() {
  let page =
    pdf.new_page()
    |> pdf.add_text(pdf.text("Hello, PDF!", x: 72.0, y: 750.0))

  let bytes =
    pdf.new_document()
    |> pdf.title("My Document")
    |> pdf.add_page(page)
    |> pdf.render

  let assert Ok(Nil) = simplifile.write_bits("output.pdf", bytes)
}
```

## Document Metadata

```gleam
pdf.new_document()
|> pdf.title("Invoice #1234")
|> pdf.author("Acme Corp")
|> pdf.subject("Monthly invoice")
|> pdf.keywords("invoice, billing")
|> pdf.creator("My Gleam App")
|> pdf.created_at(timestamp)
```

## Default Settings

Set defaults once on the document — all pages/text inherit them:

```gleam
pdf.new_document()
|> pdf.default_font("Helvetica-Bold")
|> pdf.default_text_size(12.0)
|> pdf.default_text_colour(colour.dark_grey)
|> pdf.default_page_size(pdf.size_a4 |> pdf.portrait)
```

## Page Sizes

Built-in constants: `size_a3`, `size_a4`, `size_a5`, `size_usa_letter`, `size_usa_legal`.

Orientation helpers: `portrait(PageSize) -> PageSize`, `landscape(PageSize) -> PageSize`.

Per-page override:

```gleam
pdf.new_page()
|> pdf.page_size(pdf.size_a4 |> pdf.landscape)
```

## Text

```gleam
pdf.text("Invoice Total: $500.00", x: 72.0, y: 700.0)
|> pdf.font("Helvetica-Bold")
|> pdf.text_size(16.0)
|> pdf.text_colour(colour.black)
```

Add to page with `pdf.add_text(page, text)`.

## Rectangles

```gleam
pdf.rectangle(x: 50.0, y: 600.0, width: 500.0, height: 1.0)
|> pdf.rectangle_fill_colour(colour.light_grey)
|> pdf.rectangle_stroke_colour(colour.black)
|> pdf.rectangle_line_width(0.5)
```

Add to page with `pdf.add_rectangle(page, rect)`.

## Paths and Shapes

```gleam
// Open path (line)
let line =
  pdf.path(x: 72.0, y: 500.0)
  |> pdf.line(x: 540.0, y: 500.0)
  |> pdf.path_stroke_colour(colour.black)
  |> pdf.path_line_width(1.0)

// Closed shape (triangle)
let triangle =
  pdf.path(x: 100.0, y: 100.0)
  |> pdf.line(x: 200.0, y: 100.0)
  |> pdf.line(x: 150.0, y: 200.0)
  |> pdf.shape
  |> pdf.shape_fill_colour(colour.blue)
```

Add with `pdf.add_path(page, path)` or `pdf.add_shape(page, shape)`.

`compound_shape(List(Path)) -> Shape` creates a shape from multiple paths.

## Images (JPEG only)

```gleam
let assert Ok(jpeg_bytes) = simplifile.read_bits("logo.jpg")
let assert Ok(img) = pdf.image(jpeg_bytes)

let img =
  img
  |> pdf.image_position(x: 72.0, y: 700.0)
  |> pdf.image_width(200.0)  // height scales proportionally
```

Add with `pdf.add_image(page, img)`. Setting width or height scales the other proportionally.

## Integration Pattern: Invoice Generator

```gleam
import gleam/float
import gleam/list
import paddlefish as pdf
import simplifile

pub type LineItem {
  LineItem(description: String, quantity: Int, unit_price: Float)
}

pub fn generate_invoice(
  items: List(LineItem),
  invoice_number: String,
) -> BitArray {
  let page =
    pdf.new_page()
    |> add_header(invoice_number)
    |> add_line_items(items, start_y: 650.0)

  pdf.new_document()
  |> pdf.title("Invoice " <> invoice_number)
  |> pdf.default_font("Helvetica")
  |> pdf.default_text_size(10.0)
  |> pdf.default_page_size(pdf.size_a4 |> pdf.portrait)
  |> pdf.add_page(page)
  |> pdf.render
}

fn add_header(page: pdf.Page, invoice_number: String) -> pdf.Page {
  page
  |> pdf.add_text(
    pdf.text("INVOICE", x: 72.0, y: 750.0)
    |> pdf.font("Helvetica-Bold")
    |> pdf.text_size(24.0),
  )
  |> pdf.add_text(pdf.text("#" <> invoice_number, x: 72.0, y: 720.0))
  |> pdf.add_rectangle(
    pdf.rectangle(x: 72.0, y: 670.0, width: 468.0, height: 1.0)
    |> pdf.rectangle_fill_colour(colour.black),
  )
}

fn add_line_items(
  page: pdf.Page,
  items: List(LineItem),
  start_y y: Float,
) -> pdf.Page {
  list.fold(items, #(page, y), fn(acc, item) {
    let #(page, y) = acc
    let total = int.to_float(item.quantity) *. item.unit_price
    let page =
      page
      |> pdf.add_text(pdf.text(item.description, x: 72.0, y: y))
      |> pdf.add_text(pdf.text(int.to_string(item.quantity), x: 350.0, y: y))
      |> pdf.add_text(pdf.text(float.to_string(total), x: 450.0, y: y))
    #(page, y -. 20.0)
  }).0
}
```

## Gotchas

1. **Bottom-left origin** — `y: 0.0` is the page bottom, not the top. A4 height is ~842 points, so start text near `y: 750.0`.
2. **JPEG only** — `image()` only supports JPEG. PNG/WebP will return `Error(UnsupportedImageFormat(...))`. Convert images before passing to paddlefish.
3. **No text wrapping** — text is placed at exact coordinates. You must manually calculate line breaks and y-offsets for multi-line content.
4. **No table abstraction** — build tables manually with text positioning and rectangles. Use consistent x-offsets for columns and decrement y for rows.
5. **Points, not pixels** — 72 points = 1 inch. A4 is 595 x 842 points.
6. **Font names are exact strings** — use `"Helvetica"`, `"Helvetica-Bold"`, `"Times-Roman"`, `"Courier"`, etc. Typos silently fall back to a default.
