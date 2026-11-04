# FireSystem MA2: grandMA2 busking show builder

A grandMA2 (3.9) Lua plugin that builds a FireSystem-style busking show. The plugin only builds:
the show runs on plain MA2 objects, so it works on a console or onPC without the plugin.

## Install
Copy `plugins/FireSystemMA2.lua` and `plugins/FireSystemMA2.xml` to
`C:\ProgramData\MA Lighting Technologies\grandma\gma2_V_3.9.60\plugins\`, then in the Plugins pool:
Edit an empty plugin > Import > `FireSystemMA2.xml`. Run it from the pool (or `Plugin <n>`).

## What it builds (defaults in CONFIG at the top of the .lua)
- Rows for groups 1-8 (whichever exist), plus an ALL row on every page.
- Executor pages 11 Dim FX, 12 Colour, 13 Position (pan 101+, tilt 111+), 14 Position FX, 15 Bumps,
  16 Colour FX.
  One sequence per group per row (901+), one cue per look.
- Dim FX and Position FX: cue = look x 10 + phase mode (1 Same, 2 Spread, 3 Wings). Effects run at 60 BPM
  and their executors follow Speed master 1, so TAP (Learn SpecialMaster 3.1) sets the tempo.
- Colour: 13 colours from the "MA colors" swatch book plus Lee full CT orange / blue, called with `At Gel`
  (looked up by name, so CMY, RGB and wheels all work); falls back to COLORRGB1-3 when a gel isn't found.
- Colour FX: two-colour swaps (Red/Blue, Red/White, Blue/White, Cyan/Magenta, Amber/Red, Green/Blue)
  and a rainbow, as sines on COLORRGB1-3 (RGB-mixing fixtures), with Same / Spread / Wings.
- Bumps page: Flash dimmer per group (101+), Temp dimmer strobe per group (111+), Strobe All (120),
  X-Keys = dimmer full on a Toggle per group (131+), Speed master 1 on fader 1.
- Macros 3001-4400 (row buttons) and 4401-4700 (header, Bumps layout), Layouts 101-106 (Dim FX, Colour,
  Colour FX, Position, Position FX, Bumps) with the buttons in a grid.
- PREP / FIRE: in PREP a look button only remembers the cue in show variables ($FSP_row_group); FIRE plays
  them all. Fade 0/1/3/5 per page and Same/Spread/Wings on the FX pages are variables too.
  `FS INIT` resets the variables.

## First run is the test
At the end the plugin checks every sequence, macro and layout it made and lists what MA2 refused.
Every command is echoed to the System Monitor with `FS2>` so a failing one can be found.

## Tested
grandMA2 onPC 3.9.63 (CrossOver on macOS), 2026-10-31: build of 8 groups in under 30 s (13,675 commands),
Dim FX look buttons, PREP + FIRE and the layouts checked live.

## MA2 notes learned while testing
- Executors can only be assigned on a page that exists: `Store Page n` first.
- In a layout, negative y is up.
- `gma.show.getobj.handle("Executor p.e")` works; executors have no readable state from Lua.
- Swatch books are `Gel n` (by index, "MA colors" is not book 1), gels are `Gel n.m`.
