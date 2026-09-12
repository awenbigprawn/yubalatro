# Validation — 2026-09-08

Space fast-forward update — 2026-09-12: Windows / Lovely gameplay tests replay
three seeded inputs at normal speed, with Space held, and with Space toggled
every 0.2 seconds. All nine runs match the simulator and the same-input baseline:
glass retriggers 1760, lucky/bloodstone/misprint 51944, Hook/steel 35. With base
speed 4, measured normal vs held durations are 4.905 vs 2.202 s, 6.407 vs 3.704 s,
and 3.704 vs 1.902 s. Event/frame overhead means wall time is not exactly divided
by four. The harness checks the applied speed each frame and that saved speed
remains 4; LuaJIT checks cover release, focus loss, menus, pause and text input.
Input/focus are simulated by the disposable driver; Linux Proton was not played.

Custom discards update — 2026-09-12: Windows Lovely runtime verifies the red
deck's default of 4, +/- editing, a new run with 6 discards, retaining 6 per
round / 4 remaining on continue despite a new setting of 20, zero discards,
and reset to vanilla. LuaJIT checks cover 0–99 boundaries, persistence, old
configs without the new field, deck and challenge defaults. The four-field
settings layout is checked after edits and reset by the UI regression driver.

Balatro 1.0.1o-FULL, Windows, Lovely 0.9.0.

The settings runtime test confirms the overlay and buttons retain their object identity, the room jiggle value is unchanged, and editing, saving and reset remain functional.

The UI layout regression reproduced offscreen titles/labels after the first plus
click in the previous version. With per-field, fixed-width cursors, the real
Lovely-loaded game passes visibility checks after plus/minus, 9 to 10, all three
fields, reset, typing nine digits, 999999998 to 999999999, and 40 repeated clicks.
Overlay/button identity and unchanged room jiggle are checked; screenshots were
also inspected. These are Windows runtime checks, not a Linux Proton playtest.

The following 24 scenarios compare a preview against a real played hand. Each also checks repeated predictions, RNG preservation, card abilities, money, hand levels, blind state, and restoration after an injected simulation error. Tests use the separate YubalatroQA profile.

| Scenario | Preview = actual score |
| --- | ---: |
| high card | 16 |
| pair | 40 |
| flush | 260 |
| add then multiply | 240 |
| multiply then add | 112 |
| glass retriggers | 1760 |
| steel baron mime | 35 |
| blueprint photograph | 400 |
| brainstorm triboulet | 60 |
| card editions | 2415 |
| debuffed joker edition | 16 |
| debuffed played face | 5 |
| lucky bloodstone misprint | 51944 |
| flint | 70 |
| psychic blocked hand | 0 |
| eye repeated hand | 0 |
| arm hand level | 52 |
| hook steel discard | 35 |
| plasma deck | 100 |
| hiker retrigger | 43 |
| stone splash | 66 |
| last hand dusk acrobat | 75 |
| hook hit the road | 14 |
| hook mail bootstraps | 315 |

These are representative integration checks, not exhaustive tests of all joker combinations.
