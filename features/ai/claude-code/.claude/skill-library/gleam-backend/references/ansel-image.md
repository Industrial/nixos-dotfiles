# Image Processing with Ansel

Use `ansel` for in-memory image processing (EXIF stripping, thumbnails, format conversion). Wraps libvips via Elixir's Vix.

## Prerequisites

- **Elixir** must be installed (compiles Elixir/Vix dependencies)
- **libvips**: `brew install vips` (macOS) or `apt install libvips-dev` (Linux)

## Installation

```sh
gleam add ansel
gleam add snag  # Ansel returns snag.Result for errors
```

## Core API

### Load / Export

```gleam
import ansel
import ansel/image_format.{JPEG, WebP}

// Load from memory
let assert Ok(img) = ansel.from_bit_array(upload_bytes)

// Export to memory (strips EXIF when keep_metadata: False)
let assert Ok(bytes) = ansel.to_bit_array(img, JPEG(quality: 85, keep_metadata: False))
```

### Resize

```gleam
// Proportional resize by width
let assert Ok(thumb) = ansel.scale_width(img, to: 300)

// Exact dimensions (may crop)
let assert Ok(thumb) = ansel.create_thumbnail(img, width: 300, height: 450)
```

### Other Operations

| Function | Description |
|---|---|
| `blur(Image, sigma: Float)` | Gaussian blur |
| `rotate(Image, degrees: Float)` | Rotate by angle |
| `composite(Image, overlay: Image, x: Int, y: Int)` | Overlay images |
| `get_width(Image)` / `get_height(Image)` | Get dimensions |

## Output Formats

All formats take `keep_metadata: Bool`. JPEG, WebP, AVIF, HEIC also take `quality: Int` (1-100).
PNG and TIFF are lossless (no quality parameter).

```gleam
import ansel/image_format.{JPEG, PNG, WebP, AVIF, HEIC, TIFF}
```

## Integration Pattern: Upload with EXIF Strip + Thumbnail

```gleam
import ansel
import ansel/image_format.{JPEG}
import gleam/result

/// Process an upload: strip EXIF and generate a thumbnail.
/// Returns #(clean_bytes, thumb_bytes).
pub fn process_upload(
  upload_bytes: BitArray,
) -> Result(#(BitArray, BitArray), String) {
  use img <- result.try(
    ansel.from_bit_array(upload_bytes)
    |> result.map_error(fn(_) { "Failed to decode image" }),
  )
  use clean <- result.try(
    ansel.to_bit_array(img, JPEG(quality: 85, keep_metadata: False))
    |> result.map_error(fn(_) { "Failed to strip EXIF" }),
  )
  use thumb_img <- result.try(
    ansel.scale_width(img, to: 300)
    |> result.map_error(fn(_) { "Failed to create thumbnail" }),
  )
  use thumb <- result.try(
    ansel.to_bit_array(thumb_img, JPEG(quality: 80, keep_metadata: False))
    |> result.map_error(fn(_) { "Failed to export thumbnail" }),
  )
  Ok(#(clean, thumb))
}
```

## Gotchas

1. **Error type mismatch** — Ansel returns `snag.Result`, not your `AppError`. Wrap at the boundary:
   ```gleam
   result.map_error(snag_result, fn(_) { error.internal("Image processing failed") })
   ```
2. **First build is slow** — Elixir/Vix compilation. CI needs Elixir installed.
3. **Memory** — `from_bit_array` / `to_bit_array` keeps everything in memory. Monitor usage for images >50MB.
4. **Concurrency** — libvips uses its own thread pool. Under high load, consider limiting parallel ops via an OTP actor queue.
