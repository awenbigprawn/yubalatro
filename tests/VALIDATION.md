# Validation — 2026-09-08

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
