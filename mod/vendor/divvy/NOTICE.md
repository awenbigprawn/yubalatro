# Divvy's Simulation for Balatro

Source: https://github.com/DivvyCr/Balatro-Simulation
Revision: `271fa1bba35815fcd9b2cad4cb35976fe07376c6`
Author: DivvyCr. License: GNU GPL v3, included in `LICENCE`.

Bundled on 2026-09-08. Includes the vanilla simulator only.
Local changes to Engine.lua: provide poker-hand context for boss checks; retain
card sort IDs for Hook discards; ignore debuffed joker editions; skip individual
effects on debuffed played cards. See source comments marked Yubalatro.
Local changes to Jokers/_Vanilla.lua: use rank checks for Mail-In Rebate and
Hit the Road when the Hook discards held cards.

The Yubalatro integration supplies its own UI, exception-safe state restoration,
and independent LuaJIT random generator. The full Mod's source is included and
licensed under GPL-3.0 (see ../../LICENSE).
