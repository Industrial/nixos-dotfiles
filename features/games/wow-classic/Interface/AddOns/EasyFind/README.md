# EasyFind

EasyFind is WoW's Raycast/Spotlight/Alfred: a fast command palette that lets you search most things in World of Warcraft.

[![Donate](https://img.shields.io/badge/Donate-1a1a1e?style=for-the-badge&logo=buymeacoffee&logoColor=white)](https://buymeacoffee.com/easyfind)
[![Community](https://img.shields.io/badge/Community-1a1a1e?style=for-the-badge&logo=discord&logoColor=5865F2)](https://discord.gg/3pdfmD493B)


## How to Use

Press `Ctrl+Space` (the default Search Bar keybind, changeable during the tutorial or in EasyFind options) to show and focus the search bar, type what you want, then select a result. Press the keybind again or click anywhere outside EasyFind to close it.

## Features

### Main Search

Search across:

- UI panels, tabs, options, addon settings, and Blizzard settings.
- Achievements, statistics, titles, reputations, currencies, talents, abilities, and spellbook entries.
- Mounts, pets, toys, transmogs, outfits, heirlooms, gear sets, macros, bosses, loot, bag items, and housing decor.
- Zones, dungeons, raids, delves, services, travel points, rares, and other map destinations.

Supported results can do more than just open a panel:

- Mount up, summon pets, use toys, equip outfits, run macros, and cast or use abilities directly from search.
- Switch specialization and load talent loadouts directly from search results.
- Shift-click supported abilities from results to drag them to action bars.
- Use consumables, equip gear, or Ctrl-click supported bag items to open and highlight the item in your bags.
- Open boss and loot entries in the Encounter Journal.
- Guide to collection entries, favorite pets, rename pets, and open supported collection tools.
- Open map destinations in the Map Search tab and track or preview them from the world map.

### Map Search Tab

Search from the world map with nested results built for location-first browsing:

- **"This Zone"** shows matches on the map currently being viewed.
- **"Across the World"** groups broader matches by continent and zone.
- Hover map results for POI previews, navigate between zones, place pins, and track destinations.
- The same map results can also be found from the main search bar, just without the nested map layout.

### Search Tools

- **Right-click menu**: Every result has a context menu.
  - On every result:
    - **Pin**: Keep it visible before typing.
    - **Shortkey**: Bind a key that opens or uses the result instantly, without opening the search bar or taking up action bar slots.
    - **Add Alias**: Add your own search terms. Aliases are shared between normal search and map search where applicable.
    - **Blacklist**: Keep a result out of every search. Restore it any time from the Blacklist tab in the options menu.
    - **Forget this pick**: Only on a result search put on top because you picked it for that text before. Sends it back to its natural place.
  - On most results:
    - **Guide**: Walk to the result with step-by-step highlights.
    - **Send**: Share a clickable link in chat (Say, Yell, Party, Instance, Raid, Guild, or a whisper), or copy it to your clipboard.
    - **EasyFind link**: Send the result to chat as a link other EasyFind users can click to open it exactly as you would from your own results; everyone else sees plain text. Fastest: press Ctrl+Shift+C on the row and paste into chat with Ctrl+V. Ctrl+click a received link to see where the result lives, Shift+click to pass it on. Not offered for catalog items, where the item link already shows everything.
    - **Wowhead**: Copy the result's Wowhead URL to your clipboard.
  - Row-specific extras, for example:
    - **Achievements**: objective tracking.
    - **Currencies**: backpack pinning and currency transfer.
    - **Reputations**: watched-faction toggle.
    - **Pets**: summon, rename, favorite, cage or release.
    - **Transmog sets**: favorite toggle.
    - **Bag items**: destroy.
- **Guide mode and direct open**: Learn where things live with step-by-step highlights, or open supported destinations directly.
- **Quick filters**: Type `@` to search within a category such as pets, mounts, bags, macros, abilities, achievements, statistics, bosses, gear, currencies, reputations, talents, titles, collections, or map results.
- **Slash-command results**: Type `/` in the search bar to search slash commands: EasyFind commands such as `/reset` and `/options`, WoW commands such as `/reload`, and emotes such as `/hug`.
- **Extensions button**: A dot-grid button on the search bar opens the extensions menu; Calculator, Icon Search, and Snippets live there, and the extensions that ship as addons of their own on CurseForge (GPS, Chat, Questie, Auctionator) join it once installed, with more on the way.
- **Extension buttons**: Drag any extension out of the extensions menu to make it a round button on screen, park it on the minimap ring, or drop it on the micro menu to make it a micro button. Click to open, click again to close; right-click for lock, border, shortkey, and size.
- **Calculator**: Type math directly into search, including arithmetic, trig functions, and factorials, or open the full calculator from the extensions menu or with `Alt+C`. Ships as its own "EasyFind [Calculator]" addon so it can be disabled entirely.
- **Icon Search**: Browse and filter every game icon in a grid via `@icons`, the extensions menu, or searching "Icon Search". Icons are found by file name or by the name of an ability that uses them. Ctrl+C over an icon copies its ID, and a click offers its name, its path, or a new macro with that icon. The same search engine also appears inside the game's own macro icon picker. Ships as its own "EasyFind [Icons]" addon so it can be disabled entirely.
- **Snippets**: Save text you type often and expand it anywhere with its keyword: type `\keyword` in chat or the macro editor and it expands as you type. Placeholders such as `{target}` and `{date}` fill in at use, and call-form keywords like `\greet(name)` take arguments. Manage them from the extensions menu, by searching "Snippets", or with the `@snip` quick filter. Ships as its own "EasyFind [Snippets]" addon so it can be disabled entirely.
- **Share codes**: Export aliases, shortkeys, blacklist entries, and snippets as codes and import codes others share. Every import shows what the code holds before anything applies, and warns when it puts commands on keys or into macros.
- **Macro window search**: The game's macro window gains a search bar that filters your macros by name or body as you type.
- **Copy with Ctrl+C**: Ctrl+C on a result copies a snippet's entire message, a link, or an inline answer to your clipboard, ready to paste wherever you want with Ctrl+V. Pasted into chat, an item, spell, or achievement comes back as the live link.
- **Keyboard control**: Use arrows, Enter, Tab, Alt+number row shortcuts, or Alt+H/J/K/L navigation.

### Options

Configure:

- Themes, window opacity, icon visibility (all, general only, or specific only), and the blacklist.
- Search behavior, visibility mode (auto-hide, hover show, or always show with combat options), result placement, visible row count, window border, fonts and font size, and Alt+number hints.
- Map Search behavior, map pins, icon sizing, tracking, recent searches, and result categories.
- Aliases, keybindings, indicator style/color, search window sizing, and reset tools.
- Profiles: each character remembers its own, spec profiles switch with your specialization, and any profile exports as a code with a preview on import.

## Examples

- `talents` opens or guides to the Talents panel.
- `3v3` finds Rated Arena.
- `@pets beetle` searches pets only.
- `calculator` shows the full calculator launcher.
- `sin30 + 12/3` shows an inline calculator result.
- `@snip` lists your snippets; `\greet` in chat expands the snippet with that keyword.
- `nexus` can find map results and open the Map Search tab.

## Commands

- `/ef` or `/ef o`: open EasyFind options.
- `/ef clear` or `/ef c`: clear active highlights, guides, pins, and map indicators.
- `/ef reset` or `/ef r`: reset the search position and size after confirmation.
- `/ef setup`: run the tutorial again.
- `/ef bug`: show the bug-report link.
- `/ef feature`: show the feature-request link.

Search-bar commands are also available by typing `/` directly in the EasyFind search bar.

## Keybinds

Two binds ship enabled by default, account-wide: `Ctrl+Space` (Search Bar) and `Ctrl+M` (Map Search Tab). If one of these keys is already bound to something else, EasyFind's bind takes precedence while it is set; your existing bind is not cleared and works again as soon as you rebind or remove EasyFind's.

Change or remove them in EasyFind options. Available binds:

- Search Bar
- Map Search Tab
- Clear All

## Languages

Fully translated into English, German, French, Italian, Spanish (EU and Latin America), Korean, Portuguese, Russian, and Chinese (Simplified and Traditional). The addon follows your game client's language automatically; anything missing a translation falls back to English. Translation fixes are welcome through GitHub issues.

## Feedback

- GitHub issues: https://github.com/fallenguards/EasyFind/issues/new/choose
- CurseForge: https://www.curseforge.com/wow/addons/easyfind

## Links

- GitHub: https://github.com/fallenguards/EasyFind
- Changelog: https://github.com/fallenguards/EasyFind/blob/main/CHANGELOG.md
