# Changelog

## 0.1.0

First release.

- WoW-Pro guides route through EasyFind's GPS instead of TomTom: the whole
  remaining guide as one EasyFind trip.
- Every stop is held: reaching it clears nothing. A stop leaves the route only
  when WoW-Pro completes its step.
- Run-to steps that WoW-Pro completed on arrival through TomTom (r/R/N tagged
  CC or CS) complete within 10 yards of their spot.
- Your own EasyFind directions pause the guide route until you clear them or
  click a guide step.
- A trip EasyFind cannot plan is retried with half the stops.
- `/wp easyfind on | off | max <n>` (also `/efwp`). Off, or without EasyFind,
  WoW-Pro uses TomTom exactly as before.
