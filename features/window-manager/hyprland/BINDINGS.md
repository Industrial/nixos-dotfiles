# Hyprland + Caelestia binds

Primary: `hyprland.lua`. Shell: Caelestia.

## Session / shell

| Bind | Action |
|------|--------|
| SUPER+CTRL+SHIFT+R | hyprctl reload |
| SUPER+CTRL+SHIFT+Q | Caelestia session drawer |
| SUPER+CTRL+SHIFT+L | Caelestia lock |
| SUPER+CTRL+SHIFT+C | Clear notifications |
| SUPER+CTRL+SHIFT+B | Sidebar |
| SUPER+CTRL+ALT+R | Restart caelestia-shell |
| SUPER+CTRL+G | Toggle Game Mode |
| SUPER+CTRL+SHIFT+M | Toggle monitor 8K/5K |

## Windows / workspaces

| Bind | Action |
|------|--------|
| SUPER+CTRL+C/Q/Space | close / kill / float |
| SUPER+Return | alacritty |
| SUPER+CTRL+P | Caelestia launcher |
| SUPER+H/J/K/L | focus |
| SUPER+CTRL+H/J/K/L | move window |
| SUPER+1…0 | workspace 1–10 |
| SUPER+CTRL+1…0 | move to workspace |
| SUPER+mouse_down/up | next/prev workspace |
| SUPER+LMB/RMB | drag / resize |
| SUPER+S | toggle special:scratch |
| SUPER+CTRL+S | move to special:scratch |

## Media / capture

| Bind | Action |
|------|--------|
| XF86 volume/mute | wpctl |
| XF86 brightness | caelestia brightness* |
| XF86 media | caelestia media* |
| PRINT / SUPER+PRINT | screenshot / region |
| SUPER+CTRL+V | clipboard history |

## Idle (Caelestia)

300s lock → 600s dpms → 900s suspend (inhibit while audio playing).

## Layout

Master layout (ultrawide-friendly). VRR=0 by default (Caelestia flicker guidance).
