# Attribution

## Emoji artwork

The emoji images in `textures/Emotes.tga` are derived from **Twemoji**.

- Source: https://github.com/jdecked/twemoji
- Graphics copyright: 2020 Twitter, Inc and other contributors
- Graphics license: **CC-BY 4.0**, https://creativecommons.org/licenses/by/4.0/

The images were downscaled and composited into a single texture atlas. No other
modifications were made.

CC-BY 4.0 permits commercial and non-commercial use, redistribution, and
modification, and requires that this attribution accompany the work. This file
ships with the addon to satisfy that requirement.

Only the emoji artwork is covered by the above. All addon code is the author's
own and is not derived from the Twemoji project.

## Replacing the artwork

The emoji atlas is described entirely by `EmoteData.lua` (a grid: texture path,
column count, cell size, and a name-to-cell map). Swapping in a different emoji
set means replacing `textures/Emotes.tga` and regenerating that table, with no code
changes. If a set with different license terms is used, this file must be
updated to match it.
