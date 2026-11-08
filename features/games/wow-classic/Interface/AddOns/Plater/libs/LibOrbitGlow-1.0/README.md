# LibOrbitGlow-1.0

## Description
The API reference for the shipped runtime: engine options, registry glows and their `Proc` lifecycle, the glow-pack
definition format, the raw flipbook sink and status-bar glows.

## Purpose
Give host and pack authors the exact option names and defaults the Lua honours, so the wrapper README can stay a map.

## Implementation
Top-level verbs are dot calls (`lib.Show`, `lib.Hide`, `lib.Apply`, `lib.Remove`, `lib.PreLoad`); the registry and the
`Proc`, `Button`, `Flipbook` and `StatusBar` namespaces are colon calls. `PreLoad` takes engine types only.

**Engine options** for `lib.Show(frame, "Classic" | "Thin" | "Thick" | "Medium", options)`:

| Field | Default | Meaning |
|---|---|---|
| `key` | `"Default"` | Tracking id; omit it and every glow on the frame shares one bucket |
| `color` | white | `{ r, g, b, a }` or an accessible `Color` object |
| `frameLevel` | `8` | Relative level above the parent; native Classic reads it only when building |
| `desaturated` / `force` | `true` / `false` | Flipbook engines: desaturate before tinting / rebuild when unchanged |
| `scale` / `frequency` | `1.4` / `0.25` | Flipbook width and height multiplier / native Classic ant speed |
| `owned` | `false` | Build from host-created objects, not the shared pools; required in secure aura hierarchies |
| `hostWidth` / `hostHeight` | measured | Flipbook engines: known layout size used instead of a secret host rect |

**Registry.** `lib:RegisterGlow(name, def)` returns `false` on a malformed def (it warns only when the def names no art
source) and warns when another `source` re-registers a name; `UnregisterGlow`, `IsGlowRegistered`, `GetGlowInfo`,
`GetGlowList` (sorted; group by `source`) and `GetResolvedPaths(name [, shape])` complete it. `lib.Apply` and
`lib.Remove` route engine types and registered names and, like `Show`/`Hide`, raise on any other name; `loop = true`
plays the loop with no intro; `Remove` still plays any end phase and `Proc:Clear` cuts instantly.

**Proc lifecycle.** `o` is `{ glow, shape, color, key, frameLevel, scale, padding, offsetScale, offsetX, offsetY,
owned, hostWidth, hostHeight, startDuration = 0.28, loopDuration = 1.0, endDuration = 0.20 }`; an unknown `glow`
resolves to `blizzard` and the host maps its border style to a `def.shapes` entry (default `square`). An `engine` def
such as `classic` receives only `key`, `color`, `frameLevel`, `scale` and `def.options`, never `owned` or host sizes.

| Method | Plays |
|---|---|
| `lib.Proc:Start(frame, o)` | one-shot start, then the looping body (straight to the loop without a start phase) |
| `lib.Proc:Stop(frame, o)` | one-shot end, then release (straight to release without an end phase) |
| `lib.Proc:Loop(frame, o)` | the loop only, forever |
| `lib.Proc:Clear(frame, o)` | stop immediately, no end animation |

**Pack definition.** One of `path`, `resolve`, `atlas` or `engine` is required:

| Field | Default | Purpose |
|---|---|---|
| `path` | — | File prefix; resolves to `<path>-<phase>[-<shape>]<layer><ext>` |
| `resolve` | — | `function(phase, shape, layer)` returning a path, or `nil` for art you do not ship |
| `atlas` | — | A Blizzard atlas name (single layer) |
| `engine` | — | Delegate to `Classic`, `Thin`, `Thick` or `Medium`; sizing goes through `options` |
| `layered` / `core` | `false` / `true` | Tinted BLEND body plus near-white ADD core / include that `-core` layer |
| `blendMode` | `"ADD"` | Blend for a single-layer `path` or `atlas` def |
| `bodyBlend` / `coreBlend` | `"BLEND"` / `"ADD"` | Per-layer blends for a `layered` def |
| `phases` / `loopOnly` | all / `false` | Art phases provided, e.g. `{ loop = true }`; `loopOnly` is that shorthand |
| `shaped` | `true` | Include the `-<shape>` segment in default names |
| `ext` | `".tga"` | Extension for `path` resolution |
| `rows` / `cols` / `frames` | `6` / `5` / `30` | Flipbook grid, one cell per frame over `loopDuration` |
| `shapes` | `{ square = true }` | Corner shapes the art ships |
| `scale` | engine default | Size multiplier for `path` and `atlas` defs |
| `desaturated` | `true` | `atlas` defs: desaturate before tinting |
| `options` | — | `engine` defs: extra engine options such as `scale` or `frequency` |
| `source` | `"Unknown"` | Group label for consumer pickers; use the pack name |

```lua
lib:RegisterGlow("myproc", { layered = true, path = ROOT .. "myproc", shapes = { square = true }, source = "MyPack" })
lib:RegisterGlow("spark", { path = ROOT .. "spark", loopOnly = true, shaped = false, rows = 4, cols = 4, frames = 16 })
```

**Flipbook sink.** `lib.Flipbook:Show(frame, opts)` takes `atlas` (or a file path with `isTexture = true`),
`rows`/`cols`/`frames`, `speed`, `blendMode`, `color`, `key`, and `once = true` with `onFinished` for a one-shot;
`lib.Flipbook:Hide(frame, key)` releases it.

**Status-bar glows.** `lib.StatusBar:Show(bar, { glow, key, color, width, height, contour, shape, duration })` creates
body and optional core textures on the host and returns `{ body, core, shape }`; `glow` is `tracer`, `pinneon` or a
registered name. `Show` reuses the textures it created for that host and `key` for the host's lifetime and
`lib.StatusBar:Hide(bar, key)` only stops and hides them, so drive glows with a bounded set of keys; re-showing with a
new colour or size re-tints and resizes without restarting the animation, while a different sheet (path, grid or frame
count) or `duration` restarts it. `lib.StatusBar:Resolve(name, width, height, shape, contour)` returns the texture
path, definition and shape for previews; pass `nil` as `shape` to select from a contour, and four-argument calls keep
their behaviour. Selection is explicit `shape`, then `contour`, then square; the closest aspect ratio is chosen first,
then the nearest corner size among registered geometry of the requested kind. Only that kind and the square fallback
participate; equal corner errors prefer the larger fraction, then the alphabetically first shape, and equal aspect
errors keep definition order. Contours need `lib.statusBarMinor >= 12` (`notch`/`blade` 14) and use host logical units:

| `contour` | Outline | Bundled 2.5:1 and 4:1 shapes (% of the content's shorter side) |
|---|---|---|
| `{ kind = "square" }` | Square corners | `square` |
| `{ kind = "rounded", radius = 8 }` | Circular corners | `soft-small` 6.25, `soft` 12.5, `soft-large` 17.5, `softer` 25, `round` 35, `round-large` 50 |
| `{ kind = "chamfer", cut = 5 }` | Straight cuts along both adjoining edges | `chamfer-small` 6.25, `chamfer` 12.5, `chamfer-large` 25 |
| `{ kind = "notch", radius = 5 }` | Concave quarter circles centred on every corner | `notch-small` 6.25, `notch` 12.5, `notch-large` 25 |
| `{ kind = "blade", cut = 7 }` | Straight cuts on the top-left and bottom-right only | `blade-small` 8.75, `blade` 17.5, `blade-large` 35 |

`lib:RegisterStatusBarGlow(name, def)` takes `label`, `source`, `variants` (a `{ ratio, path }` list of grayscale RGBA
sheets), `shapes` (name to suffix, needing `square`; default `{ square = "" }`), optional `contours` (shape to
`{ kind, radiusFraction }` for rounded or notch, or `{ kind, cutFraction }` for chamfer or blade, 0 to 0.5 of that
shorter side excluding the overhang halo), `rows`/`cols`/`frames`, `duration` (1), `overhang` (0.125 of the host
dimension per edge), `core` (true), `coreAlpha` (0.85), `bodyBlend` (`BLEND`), `coreBlend` (`ADD`) and `ext` (`.tga`);
sheet paths resolve to `variant.path .. shapes[shape] .. ext`. `UnregisterStatusBarGlow`, `IsStatusBarGlowRegistered`,
`GetStatusBarGlowInfo` and `GetStatusBarGlowList` mirror the icon registry; `lib.statusBarRevision` counts changes.

## Gotchas
- Omitting `shape` and `contour` selects square, including when updating an existing glow; an explicit `shape` skips
  contour validation and falls back to square when unavailable; zero radius or cut is square and oversized values clamp
  to half the shorter side. Tracer is the fallback for unknown status-bar names and survives unregistration.
- Both registries replace an existing name on success, so namespace names by pack. Malformed status-bar registrations
  return `false` and keep the old definition; geometry is copied at registration, contour metadata must name an existing
  shape, and `square` cannot take corner geometry. `GetGlowInfo` and `GetStatusBarGlowInfo` return the live
  registry entry: treat it as read-only and re-register to change it.
- Returned regions are host-owned and may feed native sinks such as `AddPandemicRegion`; once a sink owns them, let it
  drive visibility and run later presentation changes in an accessible styling window. The native flipbooks use no
  scripts, pools, reparenting or per-frame work.
- `StatusBar:Show` measures the host when `width`/`height` are omitted and creates its textures on the host, so a bar
  beneath other frame layers needs the glow mounted on a caller-owned overlay at the desired frame level; the library
  never reads, creates, replaces or removes the consumer's masks. Status-bar names resolve only through `lib.StatusBar`
  in `StatusBarGlows.lua` (icon `Apply`/`Proc` and `GetGlowList` stay separate), and pre-contour string-only shape
  registrations remain valid: shapes without `contours` metadata are never assigned inferred geometry.

## References
[Wrapper README](../README.md) (install, gotchas, secrets, releases), [LICENSE](LICENSE), `../tests/test_glows.py`.
