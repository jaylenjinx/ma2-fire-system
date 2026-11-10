-- FireSystem Presets MA2: makes the presets of the grandMA3 FireSystem on grandMA2 (3.9), for
-- groups 1-12. Presets only: no sequences, executors, macros, layouts or views.
--
-- Run it from the Plugins pool. It asks whether to replace presets that are already there
-- (Yes = make them all again, No = only make the missing ones). It only touches its own numbers.
--
-- Every pool starts at preset 1 (the same presets as FireSystem on MA3, numbered from .1;
-- MA3's All 1 pool 21 is MA2's All pool 0). The list is in the README.
-- MA3 builds its effects as phasers; MA2 has none, so the moving presets hold MA2 effect layers
-- (form, low, high, width, BPM) instead.

-------------------------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------------------------
local CFG = {
  GROUPS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},  -- missing groups are skipped
  PREFIX = "FS",          -- preset names start with this

  -- MA2 attribute names (the MA2 fixture library names)
  ATTR = {dim = "DIM", pan = "PAN", tilt = "TILT", zoom = "ZOOM", iris = "IRIS", gobo = "GOBO1",
          prism = "PRISMA1"},

  PAN_FAN = 40,               -- degrees for the pan fans
  FX_SIZE = {10, 20, 35},     -- Position FX sizes - / normal / + (degrees)
  CIRCLE_SIZE = {15, 25, 40}, -- circle radius, sizes - / normal / +
  TILT_UP = 60,               -- Bump "Tilt Up" (degrees); Tilt Down = 0

  DIM_BPM = 60,      -- Dimmer FX speed (60 BPM = 1 Hz)
  PFX_BPM = 20,      -- Position FX speed (heads can't follow 60)
  STROBE_BPM = 600,  -- strobes: 600 BPM = 10 Hz
  PULSE_BPM = 240,   -- pulse strobe

  -- Zoom presets and bumps, in % of the zoom range (MA3 uses DMX 0 / 85 / 170 / 255)
  ZOOM = {0, 33, 67, 100},

  -- Per-group strobe presets in the All pool (12 slots each, by group number):
  -- Strobe G1-12 = 0.19-30, Rnd = 0.31-42, Gen = 0.43-54
  STROBE_GRP = {strobe = 18, random = 30, gen = 42},

  LOG = true,        -- echo every command to the System Monitor
}

-------------------------------------------------------------------------------------------------
-- Preset lists (as in FireSystem.lua on MA3)
-------------------------------------------------------------------------------------------------
-- First preset of each block (every pool starts at 1)
local N = {
  dim = 1,                                         -- Dimmer 1.1-15
  pan = 1, tilt = 13, panfx = 20, tiltfx = 32,     -- Position 2.1-12, 2.13-19, 2.20-31, 2.32-43
  col = 1, pastel = 16, dark = 31,                 -- Colour 4.1-15, 4.16-30, 4.31-45
  zoom = 1,                                        -- Focus 6.1-5
  strobe = 1, fly = 4, bump = 10,                  -- All 0.1-3, 0.4-9, 0.10-18 (per-group strobes 0.19+)
}

-- Dimmer pool 1.201-215: {name, shape, width 1/n}
local DIM_FORMS = {
  {"Full", "full", 1}, {"Half", "half", 1},
  {"Sine 1", "sine", 1}, {"Sine 3", "sine", 3}, {"Sine 4", "sine", 4},
  {"Ramp Down 1", "down", 1}, {"Ramp Down 3", "down", 3}, {"Ramp Down 4", "down", 4},
  {"Ramp Up 1", "up", 1}, {"Ramp Up 3", "up", 3}, {"Ramp Up 4", "up", 4},
  {"Square 1", "square", 1}, {"Square 3", "square", 3}, {"Square 4", "square", 4},
  {"Fan", "fan", 1},
}

-- Colour pool 4.201-215, Pastel 4.231-245, Dark 4.261-275: {name, RGB in %}
local COLORS = {
  {"White", {100, 100, 100}}, {"Warm", {100, 85, 55}}, {"Red", {100, 0, 0}}, {"Orange", {100, 40, 0}},
  {"Yellow", {100, 100, 0}}, {"Lime", {60, 100, 0}}, {"Green", {0, 100, 0}}, {"Sea Green", {0, 100, 40}},
  {"Cyan", {0, 100, 100}}, {"Sky Blue", {0, 60, 100}}, {"Blue", {0, 0, 100}}, {"Deep Blue", {15, 0, 100}},
  {"Violet", {40, 0, 100}}, {"Magenta", {100, 0, 100}}, {"Pink", {100, 0, 60}},
}

-- Position pool: pan fans 2.201-212 {name, from, to in units of PAN_FAN, or a pattern}
local PANS = {
  {"Pan Left", -1, -1}, {"Fan Out", -1, 1}, {"Fan Out Small", -0.5, 0.5}, {"Pan Centre", 0, 0},
  {"Fan In Small", 0.5, -0.5}, {"Fan In", 1, -1}, {"Pan Right", 1, 1}, {"Wide Out", -2, 2},
  {"Wide In", 2, -2}, {"Cross", 1.5, -1.5}, {"X", "x"}, {"Cross Hatch", "hatch"},
}
-- tilts 2.221-227
local TILTS = {
  {"Tilt Back", -20}, {"Tilt Down", 0}, {"Tilt 15", 15}, {"Tilt 30", 30}, {"Tilt 45", 45},
  {"Tilt 60", 60}, {"Tilt Flat", 90},
}

-- MA2 effect forms, looked up by name in the Form pool (first match wins)
local FORMS = {
  sin  = {"Sin", "Sine"},
  cos  = {"Cos", "Cosine"},
  pwm  = {"PWM", "Square", "Pulse"},
  rup  = {"Ramp Plus", "Ramp+", "RampPlus", "Ramp Up", "Ramp"},
  rdn  = {"Ramp Minus", "Ramp-", "RampMinus", "Ramp Down"},
}

-------------------------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------------------------
local count, notes = 0, {}
local groups = {}     -- {no=, name=}
local forms = {}      -- key -> form number
local made, missing, kept = 0, {}, 0
local replace = true

local function cmd(s)
  count = count + 1
  if CFG.LOG then gma.echo("FSP> " .. s) end
  gma.cmd(s)
end

local function handle(s)
  local ok, h = pcall(gma.show.getobj.handle, s)
  if ok then return h end
  return nil
end

local function objname(h)
  if not h then return nil end
  local ok, n = pcall(gma.show.getobj.label, h)
  if ok and n then return n end
  ok, n = pcall(gma.show.getobj.name, h)
  if ok then return n end
  return nil
end

local function q(s) return '"' .. s .. '"' end
local function at(attr, v) return "Attribute " .. q(attr) .. " At " .. v end
local function num(v) return (math.floor(v) == v) and string.format("%d", v) or string.format("%.1f", v) end

local progress
local function prog_start(title, n)
  local ok, p = pcall(gma.gui.progress.start, title)
  if not ok then return end
  progress = p
  pcall(gma.gui.progress.setrange, progress, 0, n)
end
local function prog(i, text)
  if not progress then return end
  pcall(gma.gui.progress.set, progress, i)
  if text then pcall(gma.gui.progress.settext, progress, text) end
end
local function prog_stop()
  if progress then pcall(gma.gui.progress.stop, progress) end
  progress = nil
end

local function find_groups()
  for _, g in ipairs(CFG.GROUPS) do
    local h = handle("Group " .. g)
    if h then groups[#groups + 1] = {no = g, name = objname(h) or ("G" .. g), i = #groups + 1} end
  end
end

local function find_forms()
  local byname = {}
  for i = 1, 60 do
    local n = objname(handle("Form " .. i))
    if n then byname[n:lower()] = byname[n:lower()] or i end
  end
  for key, names in pairs(FORMS) do
    for _, n in ipairs(names) do
      if byname[n:lower()] then forms[key] = byname[n:lower()]; break end
    end
    if not forms[key] then notes[#notes + 1] = "No effect form named " .. names[1] .. " (its presets are skipped)" end
  end
end

local function group_list()
  local t = {}
  for _, g in ipairs(groups) do t[#t + 1] = tostring(g.no) end
  return "Group " .. table.concat(t, " + ")
end

-- effect layer lines for one attribute
local function fx(attr, form, low, high, bpm, width, phase)
  local l = {
    at(attr, "EffectForm " .. form),
    at(attr, "EffectLow " .. num(low)),
    at(attr, "EffectHigh " .. num(high)),
    at(attr, "EffectBPM " .. num(bpm)),
    at(attr, "EffectWidth " .. num(width or 100)),
  }
  l[#l + 1] = at(attr, "EffectPhase " .. (phase or "0"))
  return l
end

local function add(l, more) for _, x in ipairs(more) do l[#l + 1] = x end return l end

-- Stores the programmer (after `lines`, with every group selected first) into Preset pool.no.
-- A preset that is already there is kept unless the run replaces them.
-- true when Preset id must be left alone: someone else's preset (its name doesn't start with
-- the prefix), or one of ours that is already there when the run only makes the missing ones
local foreign = {}
local function skip(id)
  local h = handle("Preset " .. id)
  if not h then return false end
  local n = objname(h) or ""
  if n ~= "" and n:sub(1, #CFG.PREFIX + 1) ~= CFG.PREFIX .. " " then
    foreign[#foreign + 1] = "Preset " .. id .. " (" .. n .. ")"
    return true
  end
  if not replace then kept = kept + 1 return true end
  return false
end

local function store(pool, no, label, lines)
  local id = pool .. "." .. no
  if skip(id) then return end
  cmd("ClearAll")
  cmd("MAtricksReset")
  cmd(group_list())
  for _, l in ipairs(lines) do cmd(l) end
  cmd("Store Preset " .. id .. " /overwrite /selective /noconfirm")
  cmd("Label Preset " .. id .. " " .. q(CFG.PREFIX .. " " .. label))
  cmd("ClearAll")
  cmd("MAtricksReset")
  if handle("Preset " .. id) then made = made + 1 else missing[#missing + 1] = "Preset " .. id .. " " .. label end
end

-- every group on its own (values set per group, e.g. a fan within each group)
local function per_group(fn)
  local l = {}
  for _, g in ipairs(groups) do
    l[#l + 1] = "ClearSelection"
    l[#l + 1] = "Group " .. g.no
    add(l, fn(g))
  end
  return l
end

-- Pan and Tilt: knock the other attribute out before storing
local function without(attr, lines)
  lines[#lines + 1] = group_list()
  lines[#lines + 1] = "Off Attribute " .. q(attr)
  return lines
end

-------------------------------------------------------------------------------------------------
-- Presets
-------------------------------------------------------------------------------------------------
local A = CFG.ATTR

-- width of the shape in % of the cycle: MA3 adds n-1 empty steps after the 2-step shape
local function width(n) return math.floor(200 / (n + 1) + 0.5) end

local function dimmer()
  for i, f in ipairs(DIM_FORMS) do
    local shape, n, l = f[2], f[3], nil
    if shape == "full" then l = {at(A.dim, 100)}
    elseif shape == "half" then l = {at(A.dim, 50)}
    elseif shape == "fan" then l = per_group(function() return {at(A.dim, "0 Thru 100")} end)
    else
      local key = ({sine = "sin", down = "rdn", up = "rup", square = "pwm"})[shape]
      if forms[key] then l = fx(A.dim, forms[key], 0, 100, CFG.DIM_BPM, width(n)) end
    end
    if l then store(1, N.dim + i - 1, f[1], l) end
  end
end

-- {R, G, B, W} in % for a colour and tint (0 = colour, 1 = pastel, 2 = dark), as on MA3
local function tint(rgb, w, t)
  if t == 1 then
    local function p(v) return math.floor(v * 0.5 + 50 + 0.5) end
    return {p(rgb[1]), p(rgb[2]), p(rgb[3]), math.max(w, 25)}
  elseif t == 2 then
    local function d(v) return math.floor(v * 0.35 + 0.5) end
    return {d(rgb[1]), d(rgb[2]), d(rgb[3]), math.floor(w * 0.35)}
  end
  return {rgb[1], rgb[2], rgb[3], w}
end

-- MA2 mix colour attributes: COLORRGB1-3 = R G B (C M Y on CMY fixtures), 5 = White,
-- 6 = Warm white, 7 = Cool white; the other emitters (Amber, UV, Lime ...) go to 0
local function color_lines(c)
  local l = {at("COLORRGB1", c[1]), at("COLORRGB2", c[2]), at("COLORRGB3", c[3])}
  for _, e in ipairs({5, 6, 7}) do l[#l + 1] = at("COLORRGB" .. e, c[4]) end
  for e = 4, 22 do
    if e < 5 or e > 7 then l[#l + 1] = at("COLORRGB" .. e, 0) end
  end
  return l
end

local function colors()
  for i, c in ipairs(COLORS) do
    local rgb = c[2]
    local white = (rgb[1] >= 100 and rgb[2] >= 100 and rgb[3] >= 100) and 100 or 0
    store(4, N.col + i - 1, c[1], color_lines(tint(rgb, white, 0)))
    store(4, N.pastel + i - 1, c[1] .. " Pastel", color_lines(tint(rgb, white, 1)))
    store(4, N.dark + i - 1, c[1] .. " Dark", color_lines(tint(rgb, white, 2)))
  end
end

-- X / Cross Hatch: each fixture of the group (in its selection order) gets +F or -F.
-- X: left half +F, right half -F, the middle one 0; hatch: alternating
local function pan_pattern(kind, F)
  local l = {}
  for _, g in ipairs(groups) do
    cmd("ClearAll"); cmd("MAtricksReset"); cmd("Group " .. g.no)
    local ok, n = pcall(gma.show.getvar, "SELECTEDFIXTURESCOUNT")
    n = ok and tonumber(n) or nil
    if not n or n < 1 then
      notes[#notes + 1] = "Pan " .. kind .. ": couldn't count the fixtures of group " .. g.no .. " (fanned instead)"
      l[#l + 1] = "ClearSelection"; l[#l + 1] = "Group " .. g.no
      l[#l + 1] = at(A.pan, F .. " Thru " .. -F)
    else
      l[#l + 1] = "ClearSelection"; l[#l + 1] = "Group " .. g.no
      for i = 1, n do
        local v
        if kind == "x" then
          v = (n % 2 == 1 and i == (n + 1) / 2) and 0 or ((i <= n / 2) and F or -F)
        else
          v = (i % 2 == 1) and F or -F
        end
        l[#l + 1] = "Next"
        l[#l + 1] = at(A.pan, v)
      end
      l[#l + 1] = "MAtricksReset"
    end
  end
  cmd("ClearAll")
  return l
end

local function position()
  local F = CFG.PAN_FAN
  for i, p in ipairs(PANS) do
    local l
    if type(p[2]) == "string" then
      l = pan_pattern(p[2], F)
    else
      local a, b = p[2] * F, p[3] * F
      local v = (a == b) and num(a) or (num(a) .. " Thru " .. num(b))
      l = per_group(function() return {at(A.pan, v)} end)
    end
    store(2, N.pan + i - 1, p[1], without(A.tilt, l))
  end
  for i, t in ipairs(TILTS) do
    store(2, N.tilt + i - 1, t[1], without(A.pan, {at(A.tilt, t[2])}))
  end
end

-- Position FX in three sizes, relative effects around wherever the heads point
local function position_fx()
  if not (forms.sin and forms.cos) then return end
  local B = CFG.PFX_BPM
  for s, Z in ipairs(CFG.FX_SIZE) do
    local tag = ({" -", "", " +"})[s]
    local pan = {{"Pan Swing", -Z, Z}, {"Pan Left", -2 * Z, 0}, {"Pan Right", 0, 2 * Z}, {"Pan Wide", -2 * Z, 2 * Z}}
    for i, p in ipairs(pan) do
      store(2, N.panfx + (i - 1) * 3 + (s - 1), p[1] .. tag, without(A.tilt, fx(A.pan, forms.sin, p[2], p[3], B)))
    end
    local tilt = {{"Tilt Swing", -Z, Z}, {"Tilt Up", 0, Z}, {"Tilt Down", -Z, 0}}
    for i, t in ipairs(tilt) do
      store(2, N.tiltfx + (i - 1) * 3 + (s - 1), t[1] .. tag, without(A.pan, fx(A.tilt, forms.sin, t[2], t[3], B)))
    end
    local R = CFG.CIRCLE_SIZE[s] or Z
    store(2, N.tiltfx + 9 + (s - 1), "Circle" .. tag,
      add(fx(A.pan, forms.sin, -R, R, B), fx(A.tilt, forms.cos, -R, R, B)))
  end
end

-- Fly In / Out (All pool 0.4-9): the tilt sweeps while the dimmer snaps on and fades out
local function fly()
  if not (forms.rup and forms.rdn) then return end
  local B = CFG.PFX_BPM
  for s, Z in ipairs(CFG.FX_SIZE) do
    local tag = ({" -", "", " +"})[s]
    for fi, f in ipairs({{"Fly In", forms.rdn}, {"Fly Out", forms.rup}}) do
      local l = add(fx(A.tilt, f[2], -Z, Z, B), fx(A.dim, forms.rdn, 0, 100, B, 60))
      store(0, N.fly + (fi - 1) * 3 + (s - 1), f[1] .. tag, without(A.pan, l))
    end
  end
end

local function focus()
  for i, n in ipairs({"Zoom Narrow", "Zoom Mid", "Zoom Wide", "Zoom Full"}) do
    store(6, N.zoom + i - 1, n, {at(A.zoom, CFG.ZOOM[i])})
  end
  if forms.sin then store(6, N.zoom + 4, "Zoom Sine", fx(A.zoom, forms.sin, CFG.ZOOM[1], CFG.ZOOM[4], CFG.DIM_BPM)) end
end

-- strobe lines for a selection: a dimmer effect (MA2 can't call a shutter's strobe range by name)
local function strobe_lines(kind)
  if kind == "pulse" then
    return forms.rdn and fx(A.dim, forms.rdn, 0, 100, CFG.PULSE_BPM) or nil
  end
  if not forms.pwm then return nil end
  if kind == "random" then
    return add({"ShuffleSelection"}, fx(A.dim, forms.pwm, 0, 100, CFG.STROBE_BPM, 50, "0 Thru 360"))
  end
  return fx(A.dim, forms.pwm, 0, 100, CFG.STROBE_BPM, 50)
end

local function strobes()
  for i, k in ipairs({{"Strobe", "strobe"}, {"Pulse Strb", "pulse"}, {"Rnd Strobe", "random"}}) do
    local l = strobe_lines(k[2])
    if l then
      if k[2] == "random" then l = per_group(function() return strobe_lines("random") end) end
      store(0, N.strobe + i - 1, k[1], l)
    end
  end
  for _, g in ipairs(groups) do
    for _, k in ipairs({{"strobe", "Strobe"}, {"random", "Rnd"}, {"gen", "Gen"}}) do
      local l = strobe_lines(k[1] == "gen" and "random" or k[1])
      if l then
        -- the group only: its own selection, not every group
        local no = CFG.STROBE_GRP[k[1]] + g.no
        if not skip("0." .. no) then
          cmd("ClearAll"); cmd("MAtricksReset")
          for _, x in ipairs(add({"Group " .. g.no}, l)) do cmd(x) end
          cmd("Store Preset 0." .. no .. " /overwrite /selective /noconfirm")
          cmd("Label Preset 0." .. no .. " " .. q(CFG.PREFIX .. " " .. k[2] .. " " .. g.name))
          cmd("ClearAll"); cmd("MAtricksReset")
          if handle("Preset 0." .. no) then made = made + 1 else missing[#missing + 1] = "Preset 0." .. no end
        end
      end
    end
  end
end

-- Bump options (All pool 0.10-18, MA3's 21.281-293). Prism 1 / Prism 2 / Gobo 1 come from each
-- fixture's own wheel on MA3; MA2's Lua can't read the wheels, so those three are not made.
local function bump_opts()
  local Z = CFG.ZOOM
  local opts = {
    {"Dim 0", {at(A.dim, 0)}},
    {"Prism Open", {at(A.prism, 0)}},
    {"Gobo Open", {at(A.gobo, 0)}},
    {"Iris Close", {at(A.iris, 100)}},
    {"Iris Open", {at(A.iris, 0)}},
    {"Zoom Small", {at(A.zoom, Z[1])}},
    {"Zoom Big", {at(A.zoom, Z[4])}},
    {"Tilt Up", without(A.pan, {at(A.tilt, CFG.TILT_UP)})},
    {"Tilt Down", without(A.pan, {at(A.tilt, 0)})},
  }
  for i, o in ipairs(opts) do store(0, N.bump + i - 1, "Bump " .. o[1], o[2]) end
end

-------------------------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------------------------
local STEPS = {
  {"Dimmer", dimmer}, {"Colour", colors}, {"Position", position}, {"Position FX", position_fx},
  {"Fly In / Out", fly}, {"Zoom", focus}, {"Strobes", strobes}, {"Bump options", bump_opts},
}

local function Start()
  count, notes, groups, forms, made, missing, kept, foreign = 0, {}, {}, {}, 0, {}, 0, {}
  find_groups()
  if #groups == 0 then
    gma.gui.msgbox("FireSystem Presets", "No groups found. Store groups " .. table.concat(CFG.GROUPS, ", ") .. " first.")
    return
  end
  find_forms()
  local names = {}
  for _, g in ipairs(groups) do names[#names + 1] = g.no .. " " .. g.name end
  local msg = "Make FireSystem presets for " .. #groups .. " groups?\n" .. table.concat(names, ", ") ..
    "\n\nPresets from .1 in Dimmer 1, Position 2, Colour 4, Focus 6 and All 0." ..
    "\nPresets already there that aren't FireSystem's are left alone.\nThe programmer is cleared."
  if not gma.gui.confirm("FireSystem Presets", msg) then return end
  replace = gma.gui.confirm("FireSystem Presets",
    "Replace FireSystem presets that are already there?\n\nOK = make them all again\nCancel = only make the missing ones")

  prog_start("FireSystem Presets", #STEPS)
  for i, s in ipairs(STEPS) do
    prog(i, s[1])
    local ok, err = pcall(s[2])
    if not ok then notes[#notes + 1] = s[1] .. " stopped: " .. tostring(err) end
  end
  cmd("ClearAll")
  cmd("MAtricksReset")
  prog_stop()

  local out = "Done: " .. made .. " presets made" .. (kept > 0 and (", " .. kept .. " kept") or "") ..
    " for " .. #groups .. " groups (" .. count .. " commands).\n"
  if #foreign > 0 then
    out = out .. "\nLeft alone (not FireSystem's, move them or rename them \"" .. CFG.PREFIX .. " ...\" to replace):\n" ..
      table.concat(foreign, "\n", 1, math.min(#foreign, 15)) .. (#foreign > 15 and ("\n... and " .. (#foreign - 15) .. " more") or "") .. "\n"
  end
  if #notes > 0 then out = out .. "\nNotes:\n" .. table.concat(notes, "\n") .. "\n" end
  if #missing > 0 then
    out = out .. "\nMA2 did not make:\n" .. table.concat(missing, "\n", 1, math.min(#missing, 15))
    if #missing > 15 then out = out .. "\n... and " .. (#missing - 15) .. " more" end
  end
  gma.echo("FSP: " .. out)
  gma.gui.msgbox("FireSystem Presets", out)
end

local function Cleanup()
  prog_stop()
end

return Start, Cleanup
