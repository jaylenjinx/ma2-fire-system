# FireSystem MA2: grandMA2 busking show builder

A grandMA2 (3.9) Lua plugin that builds a FireSystem-style busking show. The plugin only builds:
the show runs on plain MA2 objects, so it works on a console or onPC without the plugin.

## Install
Copy `plugins/FireSystemMA2.lua` and `plugins/FireSystemMA2.xml` to
`C:\ProgramData\MA Lighting Technologies\grandma\gma2_V_3.9.60\plugins\`, then in the Plugins pool:
Edit an empty plugin > Import > `FireSystemMA2.xml`. Run it from the pool (or `Plugin <n>`).

## What it builds (defaults in CONFIG at the top of the .lua)
- Rows for groups 1-8 (whichever exist), plus an ALL row on every page.
- Executor pages 11 Dim FX, 12 Colour, 13 Position (pan 101+, tilt 111+), 14 Position FX, 15 Bumps.
  One sequence per group per row (901+), one cue per look.
- Dim FX and Position FX: cue = look x 10 + phase mode (1 Same, 2 Spread, 3 Wings). Effects run at 60 BPM
  and their executors follow Speed master 1, so TAP (Learn SpecialMaster 3.1) sets the tempo.
- Colour: 13 colours from the "MA colors" swatch book plus Lee full CT orange / blue, called with `At Gel`
  (looked up by name, so CMY, RGB and wheels all work); falls back to COLORRGB1-3 when a gel isn't found.
- Bumps page: Flash dimmer per group (101+), Temp dimmer strobe per group (111+), Strobe All (120),
  Speed master 1 on fader 1.
- Macros 3001+ (buttons) and 4001+ (header), Layouts 101-104 with the buttons in a grid.
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

## FireSystem Presets MA2 (presets only)
`plugins/FireSystemPresetsMA2.lua` / `.xml` is a second, separate plugin. It only makes the presets that
FireSystem on grandMA3 makes, for groups 1-12 (missing groups are skipped). No sequences, executors,
macros, layouts or views. Install it the same way (import `FireSystemPresetsMA2.xml`) and run it from the pool.
It asks whether to replace presets that are already there (OK = make them all again, Cancel = only the missing ones).

Every pool starts at preset 1 (MA3's All 1 pool 21 is MA2's All pool 0). Presets already there that
aren't FireSystem's (their name doesn't start with "FS ") are left alone and listed at the end.

| Pool | Presets |
| --- | --- |
| Dimmer 1.1-15 | Full, Half, Sine 1/3/4, Ramp Down 1/3/4, Ramp Up 1/3/4, Square 1/3/4, Fan |
| Position 2.1-12 | Pan Left, Fan Out, Fan Out Small, Pan Centre, Fan In Small, Fan In, Pan Right, Wide Out, Wide In, Cross, X, Cross Hatch |
| Position 2.13-19 | Tilt Back, Tilt Down, Tilt 15/30/45/60, Tilt Flat |
| Position 2.20-31 | Pan Swing / Left / Right / Wide, sizes - / normal / + |
| Position 2.32-43 | Tilt Swing / Up / Down, Circle, sizes - / normal / + |
| Colour 4.1-15, 4.16-30, 4.31-45 | 15 colours, then their Pastel and Dark versions |
| Focus 6.1-5 | Zoom Narrow / Mid / Wide / Full, Zoom Sine |
| Focus 6.6-8 | Focus Min / Mid / Max |
| Gobo 3.1-10, 3.11-20 | Gobo 1 and Gobo 2 wheel slots (Open, then each gobo, read from each fixture type) |
| Gobo 3.21-25, 3.26-30 | Gobo 1 / Gobo 2 rotation: Stop, > Slow, > Fast, < Slow, < Fast |
| Beam 5.1-6 | Shutter Open, Closed, Strobe, Strobe Slow, Rnd Strobe, Pulse |
| Beam 5.7-9 | Iris Open / Mid / Closed |
| Beam 5.10-14, 5.15-19 | Prism Open + prism slots, then prism rotation Stop / > Slow / > Fast / < Slow / < Fast |
| All 0.1-3 | Strobe, Pulse Strb, Rnd Strobe |
| All 0.4-9 | Fly In, Fly Out, sizes - / normal / + |
| All 0.10-22 | Bump options: Dim 0, Prism Open / 1 / 2, Gobo 1, Gobo Open, Iris Close / Open, Zoom Small / Big, Tilt Up / Down, Shutter Open |
| All 0.23-34, 0.35-46, 0.47-58 | Strobe, Rnd and Gen per group (slot = group number) |

Differences from MA3:
- MA2 has no phasers, so the moving presets hold MA2 effect layers (form, low, high, width, BPM). The
  Position FX are meant as relative effects around where the heads point.
- Shutter, gobo, prism, iris and rotation values are read from each fixture type's channel sets, so one
  preset holds the right value for every type in the groups. Gobos and prisms on a rotating wheel are
  stored with rotation stopped, so the rotation presets work on top of them.
- Strobes use each fixture's shutter strobe range; fixtures without one get a dimmer effect (PWM 10 Hz,
  Ramp Minus pulse, shuffled PWM for random).
- Colours use the MA2 mix attributes COLORRGB1-3, White 5, Warm white 6, Cool white 7 (the others go to 0).
- Zoom values are % of the zoom range (`ZOOM` in CONFIG). Focus is 0 / 50 / 100 % of the focus range.

Untested on a console yet: check the effect presets, the X / Cross Hatch fans (stepped with `Next`) and the gobo / prism rotation directions first.
