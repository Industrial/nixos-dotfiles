# EasyFind [WoW-Pro]

Follow [WoW-Pro](https://www.wow-pro.com/) leveling guides with
[EasyFind](https://www.curseforge.com/wow/addons/easyfind)'s GPS instead of TomTom.

- **The whole guide, not just the next step.** Every remaining step with a
  location becomes a stop on one EasyFind route, with flights, boats, portals
  and your hearthstone planned between them.
- **Stops stay until the step is done.** Reaching a stop clears nothing. A stop
  leaves the route only when WoW-Pro marks its step complete: the quest
  accepted, the objective finished, the quest turned in.
- **Steps at the same spot share a stop.** Turning in a quest and picking up its
  follow-up from the same NPC is one stop.
- **Your own directions come first.** Ask EasyFind for directions somewhere
  else and the guide route steps aside until you clear yours or click a guide
  step.

## Requirements

- WoW-Pro
- EasyFind, with its GPS module (EasyFind_GPS) enabled

TomTom is no longer needed. If it's installed, it stays as the fallback: with
EasyFind missing or switched off, WoW-Pro uses TomTom exactly as before.

## Commands

| Command | |
| --- | --- |
| `/wp easyfind` or `/efwp` | Status |
| `/wp easyfind off` | Back to TomTom |
| `/wp easyfind on` | EasyFind again |
| `/wp easyfind max 30` | Route through the next 30 stops only (`max 0` = the whole guide) |

The route is planned again whenever the guide moves on. For long guides on a
slow machine, `max` keeps that quick.

## How it works

This addon changes no WoW-Pro file. It wraps WoW-Pro's `WoWPro:MapPoint` and
`WoWPro:RemoveMapPoint`, and uses EasyFind only through its public API:

- `navigateTrip` sends the guide's stops as one route. Every stop is marked
  `hold`, which EasyFind documents as a stop the route never moves past on its
  own, for a guide that sends the next trip itself.
- `routeStarted` / `routeCleared` tell the guide's route apart from yours.

Run-to steps that WoW-Pro completed on arrival through TomTom's distance
callback (`R`, `r` and `N` steps tagged `CC` or `CS`) complete within 10 yards
of their spot, as they did before. For those steps, getting there is the
objective.

EasyFind drops a whole trip if it can't find a way to any one stop, such as a
spot inside a dungeon. A trip that hasn't started after 45 seconds is sent
again with half the stops.

## Known limits

- Optional (`|O|`) steps, rares and treasures are left off the route ahead,
  because WoW-Pro shows them only when their quest or item is in hand or the
  option is on. They join the route when they become the current step.
- Dismissing the guide's route in EasyFind brings it back at the next step
  change. `/wp easyfind off` switches it off properly.

## Development

Tests run outside the game with [busted](https://lunarmodules.github.io/busted/):

```
busted tests/Core_spec.lua
```

## License

MIT, see `LICENSE`. WoW-Pro and EasyFind are separate projects with their own
licenses; this addon contains no code from either.
