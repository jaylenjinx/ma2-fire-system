-- FireSystem MA2: builds a FireSystem-style busking show on grandMA2 (3.9, onPC or console).
-- The plugin only BUILDS. The show it makes runs on plain MA2 objects (sequences on executors,
-- macros with show variables, layouts), so a console without the plugin plays it the same.
--
-- Run it once from the Plugins pool. Run it again to rebuild (it only touches its own numbers).

-------------------------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------------------------
local CFG = {
  GROUPS = {1, 2, 3, 4, 5, 6, 7, 8},  -- groups to build rows for (missing ones are skipped)

  -- Executor pages (one per FireSystem page). Each group's sequence sits on executor EXEC + n
  -- (n = the group's place in GROUPS), tilt on EXEC + 10 + n.
  PAGE = {dim = 11, col = 12, pos = 13, pfx = 14, bump = 15, cfx = 16},
  EXEC = 100,

  SEQ = 901,        -- sequences 901+ (row block of 20 per row)
  MACRO = 3001,     -- macros 3001-3999 for the rows, 4001+ for the header buttons
  LAYOUT = 101,     -- layouts 101-106 (Dim FX, Colour, Colour FX, Position, Position FX, Bumps)

  SPEED_MASTER = 1, -- SpecialMaster 3.<n>: effects follow it, TAP learns it
  FX_BPM = 60,      -- effect speed in the cues (60 BPM = 1:1 with the speed master)
  STROBE_BPM = 600, -- dimmer strobe (600 BPM = 10 Hz)
  PFX_SIZE = 25,    -- Position FX size (pan/tilt degrees each side)

  -- Layout grid: element spacing in layout units, and whether rows go down (negative y)
  GRID_X = 1.1,
  GRID_Y = 1.1,
  Y_DOWN = false,  -- MA2 layouts: negative y is up

  LOG = true,       -- echo every command to the System Monitor
}

-------------------------------------------------------------------------------------------------
-- Looks
-------------------------------------------------------------------------------------------------
-- Name, RGB for the button colour (and the fallback when the gel is missing), swatch book, gel name.
-- Gels are looked up by name, so CMY, RGB and colour wheels all get the right colour.
local COLOURS = {
  {"White", 100, 100, 100}, {"Red", 100, 0, 0}, {"Orange", 100, 50, 0}, {"Yellow", 100, 100, 0},
  {"Fern Green", 50, 100, 0}, {"Green", 0, 100, 0}, {"Sea Green", 0, 100, 50}, {"Cyan", 0, 100, 100},
  {"Lavender", 0, 50, 100}, {"Blue", 0, 0, 100}, {"Violet", 50, 0, 100}, {"Magenta", 100, 0, 100},
  {"Pink", 100, 0, 50},
  {"CTO", 100, 75, 45, "Lee", "full CT orange"}, {"CTB", 75, 85, 100, "Lee", "full CT blue"},
}
for _, c in ipairs(COLOURS) do c[5] = c[5] or "MA colors"; c[6] = c[6] or c[1] end

-- Effect forms are looked up by name in the Form pool (first match wins).
local FORMS = {
  sin  = {"Sin", "Sine"},
  cos  = {"Cos", "Cosine"},
  pwm  = {"PWM", "Square", "Pulse"},
  rup  = {"Ramp Plus", "Ramp+", "RampPlus", "Ramp Up", "Ramp"},
  rdn  = {"Ramp Minus", "Ramp-", "RampMinus", "Ramp Down"},
}

local DIM_FX = {
  {"SINE", "sin"}, {"SQUARE", "pwm"}, {"RAMP UP", "rup"}, {"RAMP DN", "rdn"},
}

local PFX = {
  {"CIRCLE", {{"PAN", "sin", 0}, {"TILT", "cos", 0}}},
  {"PAN", {{"PAN", "sin", 0}}},
  {"TILT", {{"TILT", "sin", 0}}},
  {"FIG 8", {{"PAN", "sin", 0}, {"TILT", "sin", 90}}},
}

-- Phase modes: cue = look * 10 + mode
local PHASES = {{"SAME", false, false}, {"SPREAD", true, false}, {"WINGS", true, true}}

local PANS = {
  {"LEFT", "-60"}, {"HALF L", "-30"}, {"CENTRE", "0"}, {"HALF R", "30"}, {"RIGHT", "60"},
  {"FAN IN", "30 Thru -30"}, {"FAN OUT", "-30 Thru 30"}, {"FAN WIDE", "-60 Thru 60"},
  {"CROSS", "45 Thru -45", true},
}
local TILTS = {
  {"-30", "-30"}, {"0", "0"}, {"20", "20"}, {"40", "40"}, {"60", "60"}, {"80", "80"},
  {"100", "100"}, {"120", "120"}, {"FAN", "0 Thru 90"},
}

-- Colour FX: two colours (RGB 0-100) swapped by a sine on the mix attributes; "rainbow" runs R, G, B
-- 120 degrees apart. Needs fixtures with COLORRGB1-3 (RGB mixing).
local CFX = {
  {"RED BLUE", {100, 0, 0}, {0, 0, 100}}, {"RED WHITE", {100, 0, 0}, {100, 100, 100}},
  {"BLUE WHITE", {0, 0, 100}, {100, 100, 100}}, {"CYAN MAG", {0, 100, 100}, {100, 0, 100}},
  {"AMBER RED", {100, 50, 0}, {100, 0, 0}}, {"GREEN BLUE", {0, 100, 0}, {0, 0, 100}},
  {"RAINBOW"},
}

local FADES = {0, 1, 3, 5}

-------------------------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------------------------
local count, errors = 0, {}

local function echo(s) gma.echo("FS2: " .. s) end

local function cmd(s)
  count = count + 1
  if CFG.LOG then gma.echo("FS2> " .. s) end
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

local function amount(h)
  local ok, n = pcall(gma.show.getobj.amount, h)
  if ok then return n end
  return nil
end

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

local function q(s) return '"' .. s .. '"' end

-------------------------------------------------------------------------------------------------
-- Show lookups
-------------------------------------------------------------------------------------------------
local groups = {}     -- {no=, name=, i=}
local forms = {}      -- key -> form number
local gels = {}       -- colour name -> "Gel x.y" or nil

local function find_groups()
  for _, g in ipairs(CFG.GROUPS) do
    local h = handle("Group " .. g)
    if h then
      local i = #groups + 1
      groups[i] = {no = g, name = objname(h) or ("G" .. g), i = i}
    end
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
    if not forms[key] then errors[#errors + 1] = "No effect form named " .. names[1] end
  end
end

local function find_gels()
  -- swatch books by name, then each colour's gel by name inside its book
  local books, cache = {}, {}
  for i = 1, 40 do
    local n = objname(handle("Gel " .. i))
    if n then books[n:lower()] = i end
  end
  for _, c in ipairs(COLOURS) do
    local b = books[c[5]:lower()]
    if b then
      if not cache[b] then
        cache[b] = {}
        for j = 1, amount(handle("Gel " .. b)) or 0 do
          local n = objname(handle("Gel " .. b .. "." .. j))
          if n then cache[b][n:lower()] = cache[b][n:lower()] or j end
        end
      end
      local j = cache[b][c[6]:lower()]
      if j then gels[c[1]] = "Gel " .. b .. "." .. j end
    end
  end
end

-------------------------------------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------------------------------------
-- key: row number used in variable names; lay: layout index; col0: first column in the layout
local ROWS = {
  {key = 1, id = "dim",  title = "DIM FX",   page = "dim", off = 0,  lay = 1, col0 = 0,  fx = true, fade = 1},
  {key = 2, id = "col",  title = "COLOUR",   page = "col", off = 0,  lay = 2, col0 = 0,  fade = 2},
  {key = 6, id = "cfx",  title = "COLOUR FX", page = "cfx", off = 0, lay = 3, col0 = 0,  fx = true, fade = 6},
  {key = 3, id = "pan",  title = "PAN",      page = "pos", off = 0,  lay = 4, col0 = 0,  fade = 3},
  {key = 4, id = "tilt", title = "TILT",     page = "pos", off = 10, lay = 4, col0 = 13, fade = 3},
  {key = 5, id = "pfx",  title = "POS FX",   page = "pfx", off = 0,  lay = 5, col0 = 0,  fx = true, fade = 5},
}
local LAYOUTS = {"FS Dim FX", "FS Colour", "FS Colour FX", "FS Position", "FS Position FX", "FS Bumps"}
local BUMP_LAYOUT = 6
-- fade buttons per page, phase buttons per FX row
local FADE_KEYS, PHASE_KEYS = {}, {}
for _, row in ipairs(ROWS) do
  local seen = false
  for _, k in ipairs(FADE_KEYS) do if k == row.fade then seen = true end end
  if not seen then FADE_KEYS[#FADE_KEYS + 1] = row.fade end
  if row.fx then PHASE_KEYS[#PHASE_KEYS + 1] = row.key end
end
local ROW_W = 20  -- macros per group row (name, X, up to 18 looks)

local function looks(row)
  if row.id == "dim" then return DIM_FX end
  if row.id == "col" then return COLOURS end
  if row.id == "pan" then return PANS end
  if row.id == "tilt" then return TILTS end
  if row.id == "cfx" then return CFX end
  return PFX
end

local function seq_no(row, g) return CFG.SEQ + (row.key - 1) * 20 + g.i end
local function exec_of(row, g) return CFG.PAGE[row.page] .. "." .. (CFG.EXEC + row.off + g.i) end
-- k = 0 for the ALL row, else the group's place; c = 0 name, 1 X, 2.. looks
local function macro_no(row, k, c) return CFG.MACRO + (row.key - 1) * 200 + k * ROW_W + c end

local HDR = CFG.MACRO + 1400  -- header block (rows use 200 macros each, keys 1-7)
local H = {
  prep = HDR, fire = HDR + 1, init = HDR + 2, tap = HDR + 3, alloff = HDR + 4, strobe = HDR + 5,
  nav = HDR + 10,            -- + layout index
  fade = HDR + 20,           -- + fade row key * 10 + fade index
  phase = HDR + 100,         -- + phase row key * 10 + mode
  bump = HDR + 200,          -- Bumps layout: + group * 10 + 1 X-Key, + 2 strobe
  last = HDR + 299,
}

-------------------------------------------------------------------------------------------------
-- Cues
-------------------------------------------------------------------------------------------------
local function fx_lines(attr, form, low, high, bpm, phase0, spread, width)
  local l = {
    "Attribute " .. q(attr) .. " At EffectForm " .. form,
    "Attribute " .. q(attr) .. " At EffectLow " .. low,
    "Attribute " .. q(attr) .. " At EffectHigh " .. high,
    "Attribute " .. q(attr) .. " At EffectBPM " .. bpm,
  }
  if width then l[#l + 1] = "Attribute " .. q(attr) .. " At EffectWidth " .. width end
  if spread then
    l[#l + 1] = "Attribute " .. q(attr) .. " At EffectPhase " .. phase0 .. " Thru " .. (phase0 + 360)
  else
    l[#l + 1] = "Attribute " .. q(attr) .. " At EffectPhase " .. phase0
  end
  return l
end

local function store_cue(row, g, cue, label, values, wings)
  local s = seq_no(row, g)
  cmd("ClearAll")
  cmd("MAtricksReset")
  cmd("Group " .. g.no)
  if wings then cmd("MAtricksWings 2") end
  for _, v in ipairs(values) do cmd(v) end
  cmd("Store Cue " .. cue .. " Sequence " .. s .. " /overwrite /noconfirm")
  cmd("Label Cue " .. cue .. " Sequence " .. s .. " " .. q(label))
end

-- Executors can only be assigned on a page that exists.
local function make_pages()
  local names = {dim = "FS Dim FX", col = "FS Colour", cfx = "FS Colour FX", pos = "FS Position",
                 pfx = "FS Position FX", bump = "FS Bumps"}
  for k, n in pairs(names) do
    if not handle("Page " .. CFG.PAGE[k]) then cmd("Store Page " .. CFG.PAGE[k] .. " /noconfirm") end
    if not handle("Page " .. CFG.PAGE[k]) then errors[#errors + 1] = "Store Page " .. CFG.PAGE[k] .. " made nothing" end
    cmd("Label Page " .. CFG.PAGE[k] .. " " .. q(n))
  end
end

local function build_row_cues(row, g)
  local s = seq_no(row, g)
  cmd("Delete Sequence " .. s .. " /noconfirm")
  if row.id == "dim" then
    for i, lk in ipairs(DIM_FX) do
      if forms[lk[2]] then
        for m, ph in ipairs(PHASES) do
          store_cue(row, g, i * 10 + m, lk[1] .. " " .. ph[1],
            fx_lines("DIM", forms[lk[2]], 0, 100, CFG.FX_BPM, 0, ph[2]), ph[3])
        end
      end
    end
  elseif row.id == "col" then
    for i, c in ipairs(COLOURS) do
      local v
      if gels[c[1]] then
        v = {"At " .. gels[c[1]]}
      else
        v = {"Attribute " .. q("COLORRGB1") .. " At " .. c[2],
             "Attribute " .. q("COLORRGB2") .. " At " .. c[3],
             "Attribute " .. q("COLORRGB3") .. " At " .. c[4]}
      end
      store_cue(row, g, i, c[1], v)
    end
  elseif row.id == "pan" or row.id == "tilt" then
    local attr = row.id == "pan" and "PAN" or "TILT"
    for i, lk in ipairs(looks(row)) do
      store_cue(row, g, i, lk[1], {"Attribute " .. q(attr) .. " At " .. lk[2]}, lk[3])
    end
  elseif row.id == "cfx" then
    if forms.sin then
      for i, lk in ipairs(CFX) do
        for m, ph in ipairs(PHASES) do
          local v = {}
          for a = 1, 3 do
            local attr = "COLORRGB" .. a
            local low, high, p0 = 0, 100, (a - 1) * 120
            if lk[2] then low, high, p0 = lk[2][a], lk[3][a], 0 end
            -- equal low/high stays a flat effect so the cue overwrites what tracks in from earlier cues
            for _, l in ipairs(fx_lines(attr, forms.sin, low, high, CFG.FX_BPM, p0, ph[2])) do v[#v + 1] = l end
          end
          store_cue(row, g, i * 10 + m, lk[1] .. " " .. ph[1], v, ph[3])
        end
      end
    end
  elseif row.id == "pfx" then
    for i, lk in ipairs(PFX) do
      for m, ph in ipairs(PHASES) do
        local v, ok = {}, true
        local parts, used = {}, {}
        for _, part in ipairs(lk[2]) do parts[#parts + 1] = part; used[part[1]] = true end
        -- the other axis gets a flat effect, so a PAN look stops a TILT that tracks in from a CIRCLE
        for _, a in ipairs({"PAN", "TILT"}) do
          if not used[a] then parts[#parts + 1] = {a, "sin", 0, true} end
        end
        for _, part in ipairs(parts) do
          if not forms[part[2]] then ok = false break end
          local size = part[4] and 0 or CFG.PFX_SIZE
          for _, l in ipairs(fx_lines(part[1], forms[part[2]], -size, size,
                                      CFG.FX_BPM, part[3], ph[2])) do
            v[#v + 1] = l
          end
        end
        if ok then store_cue(row, g, i * 10 + m, lk[1] .. " " .. ph[1], v, ph[3]) end
      end
    end
  end
  cmd("Label Sequence " .. s .. " " .. q("FS " .. row.title .. " " .. g.name))
  cmd("Assign Sequence " .. s .. " At Executor " .. exec_of(row, g))
  if row.fx then
    cmd("Assign Executor " .. exec_of(row, g) .. " /speedmaster=" .. CFG.SPEED_MASTER)
  end
end

-- Bumps page: Flash = dimmer full, Temp = dimmer strobe, plus Strobe All and the speed fader.
local function build_bumps()
  local p = CFG.PAGE.bump
  local bump, strobe = CFG.SEQ + 200, CFG.SEQ + 220  -- (rows use SEQ + 0-139)
  -- v0.1 kept its strobes at SEQ + 121-140
  for s = CFG.SEQ + 121, CFG.SEQ + 140 do
    local n = objname(handle("Sequence " .. s))
    if n and n:sub(1, 9) == "FS Strobe" then cmd("Delete Sequence " .. s .. " /noconfirm") end
  end
  for _, g in ipairs(groups) do
    local s = bump + g.i
    cmd("Delete Sequence " .. s .. " /noconfirm")
    cmd("ClearAll"); cmd("MAtricksReset"); cmd("Group " .. g.no); cmd("At 100")
    cmd("Store Cue 1 Sequence " .. s .. " /overwrite /noconfirm")
    cmd("Label Sequence " .. s .. " " .. q("FS Bump " .. g.name))
    cmd("Assign Sequence " .. s .. " At Executor " .. p .. "." .. (CFG.EXEC + g.i))
    cmd("Assign Flash At Executor " .. p .. "." .. (CFG.EXEC + g.i))

    s = strobe + g.i
    cmd("Delete Sequence " .. s .. " /noconfirm")
    cmd("ClearAll"); cmd("MAtricksReset"); cmd("Group " .. g.no)
    if forms.pwm then
      for _, l in ipairs(fx_lines("DIM", forms.pwm, 0, 100, CFG.STROBE_BPM, 0, false, 50)) do cmd(l) end
    end
    cmd("Store Cue 1 Sequence " .. s .. " /overwrite /noconfirm")
    cmd("Label Sequence " .. s .. " " .. q("FS Strobe " .. g.name))
    cmd("Assign Sequence " .. s .. " At Executor " .. p .. "." .. (CFG.EXEC + 10 + g.i))
    cmd("Assign Temp At Executor " .. p .. "." .. (CFG.EXEC + 10 + g.i))
  end
  -- X-Keys: dimmer full on a toggle (on until pressed again)
  local xk = CFG.SEQ + 260
  for _, g in ipairs(groups) do
    local s = xk + g.i
    cmd("Delete Sequence " .. s .. " /noconfirm")
    cmd("ClearAll"); cmd("MAtricksReset"); cmd("Group " .. g.no); cmd("At 100")
    cmd("Store Cue 1 Sequence " .. s .. " /overwrite /noconfirm")
    cmd("Label Sequence " .. s .. " " .. q("FS X-Key " .. g.name))
    cmd("Assign Sequence " .. s .. " At Executor " .. p .. "." .. (CFG.EXEC + 30 + g.i))
    cmd("Assign Toggle At Executor " .. p .. "." .. (CFG.EXEC + 30 + g.i))
  end
  -- Strobe All
  local s = strobe + 20
  cmd("Delete Sequence " .. s .. " /noconfirm")
  cmd("ClearAll"); cmd("MAtricksReset")
  local sel = {}
  for _, g in ipairs(groups) do sel[#sel + 1] = g.no end
  cmd("Group " .. table.concat(sel, " + "))
  if forms.pwm then
    for _, l in ipairs(fx_lines("DIM", forms.pwm, 0, 100, CFG.STROBE_BPM, 0, false, 50)) do cmd(l) end
  end
  cmd("Store Cue 1 Sequence " .. s .. " /overwrite /noconfirm")
  cmd("Label Sequence " .. s .. " " .. q("FS Strobe All"))
  cmd("Assign Sequence " .. s .. " At Executor " .. p .. "." .. (CFG.EXEC + 20))
  cmd("Assign Temp At Executor " .. p .. "." .. (CFG.EXEC + 20))
  -- Speed master on fader 1 of the bump page
  cmd("Assign SpecialMaster 3." .. CFG.SPEED_MASTER .. " At Executor " .. p .. ".1")
  cmd("ClearAll"); cmd("MAtricksReset")
end

-------------------------------------------------------------------------------------------------
-- Macros
-------------------------------------------------------------------------------------------------
local all_macros = {}

local function macro(no, label, lines, rgb)
  for _, l in ipairs(lines) do
    if l:find('"', 1, true) then error("macro line has a quote: " .. l) end
  end
  all_macros[#all_macros + 1] = no
  cmd("Delete Macro 1." .. no .. " /noconfirm")
  cmd("Store Macro 1." .. no)
  cmd("Label Macro 1." .. no .. " " .. q(label))
  for i, l in ipairs(lines) do
    cmd("Store Macro 1." .. no .. "." .. i)
    cmd("Assign Macro 1." .. no .. "." .. i .. " /cmd=" .. q(l))
  end
  if rgb then
    cmd("Appearance Macro " .. no .. " /r=" .. rgb[1] .. " /g=" .. rgb[2] .. " /b=" .. rgb[3])
  end
end

local GREY, DIMGREY, LIVE, PREP = {45, 45, 45}, {25, 25, 25}, {100, 85, 0}, {100, 40, 0}
local function ap(no, rgb) return "Appearance Macro " .. no .. " /r=" .. rgb[1] .. " /g=" .. rgb[2] .. " /b=" .. rgb[3] end

-- Lines that play (or, in PREP, remember) cue `cue` of `row` for group g, plus the button lights.
local function look_lines(row, g, cue, c, l)
  local e = exec_of(row, g)
  local var = "$FSP_" .. row.key .. "_" .. g.i
  local n = #looks(row)
  if cue == "off" then
    l[#l + 1] = "[$FSMODE==0] Off Executor " .. e
    l[#l + 1] = "[$FSMODE==1] SetVar " .. var .. " = -1"
  else
    l[#l + 1] = "[$FSMODE==0] Goto Cue " .. cue .. " Executor " .. e .. " Fade $FSF_" .. row.fade
    l[#l + 1] = "[$FSMODE==1] SetVar " .. var .. " = " .. cue
  end
  local first, last = macro_no(row, g.i, 1), macro_no(row, g.i, n + 1)
  if row.id == "col" then
    -- the group's name button takes the colour picked
    if cue == "off" then
      l[#l + 1] = ap(macro_no(row, g.i, 0), GREY)
    else
      l[#l + 1] = "Appearance Macro " .. macro_no(row, g.i, 0) .. " At Macro " .. macro_no(row, g.i, c)
    end
  else
    l[#l + 1] = ap(first, GREY):gsub("Macro " .. first, "Macro " .. first .. " Thru " .. last)
    if cue ~= "off" then
      l[#l + 1] = "[$FSMODE==0] " .. ap(macro_no(row, g.i, c), LIVE)
      l[#l + 1] = "[$FSMODE==1] " .. ap(macro_no(row, g.i, c), PREP)
    end
  end
end

local function build_row_macros(row)
  local lk = looks(row)
  for k = 0, #groups do
    local gs = k == 0 and groups or {groups[k]}
    local gname = k == 0 and "ALL" or groups[k].name
    -- name button selects the group(s)
    local sel = {}
    for _, g in ipairs(gs) do sel[#sel + 1] = g.no end
    macro(macro_no(row, k, 0), gname, {"Group " .. table.concat(sel, " + ")}, k == 0 and {80, 80, 80} or GREY)
    -- X
    local l = {}
    for _, g in ipairs(gs) do look_lines(row, g, "off", 1, l) end
    macro(macro_no(row, k, 1), "X", l, {100, 0, 0})
    -- looks
    for i, item in ipairs(lk) do
      l = {}
      local cue = tostring(i)
      if row.fx then
        l[1] = "SetVar $FSC = $FSPH_" .. row.key
        l[2] = "AddVar $FSC = " .. (i * 10)
        cue = "$FSC"
      end
      for _, g in ipairs(gs) do look_lines(row, g, cue, i + 1, l) end
      local rgb = row.id == "col" and {item[2], item[3], item[4]} or GREY
      macro(macro_no(row, k, i + 1), item[1], l, rgb)
    end
  end
end

local function build_header()
  -- PREP toggle
  macro(H.prep, "PREP", {
    "[$FSMODE==1] SetVar $FSN = 0",
    "[$FSMODE==0] SetVar $FSN = 1",
    "SetVar $FSMODE = $FSN",
    "[$FSMODE==1] " .. ap(H.prep, PREP),
    "[$FSMODE==0] " .. ap(H.prep, GREY),
  }, GREY)
  -- FIRE: play everything remembered in PREP
  local l = {}
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(groups) do
      local var, e = "$FSP_" .. row.key .. "_" .. g.i, exec_of(row, g)
      l[#l + 1] = "[" .. var .. ">0] Goto Cue " .. var .. " Executor " .. e .. " Fade $FSF_" .. row.fade
      l[#l + 1] = "[" .. var .. "==-1] Off Executor " .. e
      l[#l + 1] = "SetVar " .. var .. " = 0"
    end
  end
  macro(H.fire, "FIRE", l, {100, 0, 0})
  -- TAP
  macro(H.tap, "TAP", {"Learn SpecialMaster 3." .. CFG.SPEED_MASTER}, {0, 60, 100})
  -- ALL OFF
  l = {}
  for _, k in ipairs({"dim", "col", "cfx", "pos", "pfx", "bump"}) do
    l[#l + 1] = "Off Executor " .. CFG.PAGE[k] .. "." .. (CFG.EXEC + 1) .. " Thru " .. CFG.PAGE[k] .. "." .. (CFG.EXEC + 40)
  end
  macro(H.alloff, "ALL OFF", l, {100, 0, 0})
  -- STROBE ALL (on / off; hold the executor on the bump page for a flash)
  macro(H.strobe, "STROBE ALL", {"Toggle Executor " .. CFG.PAGE.bump .. "." .. (CFG.EXEC + 20)}, {100, 100, 100})
  -- Page buttons
  for i, n in ipairs(LAYOUTS) do
    macro(H.nav + i, n:gsub("^FS ", ""):upper(), {"Layout " .. (CFG.LAYOUT + i - 1)}, {30, 30, 60})
  end
  -- Fade per page and phase per FX row
  for _, fk in ipairs(FADE_KEYS) do
    local first, last = H.fade + fk * 10 + 1, H.fade + fk * 10 + #FADES
    for i, f in ipairs(FADES) do
      macro(H.fade + fk * 10 + i, "FADE " .. f, {
        "SetVar $FSF_" .. fk .. " = " .. f,
        ap(first, GREY):gsub("Macro " .. first, "Macro " .. first .. " Thru " .. last),
        ap(H.fade + fk * 10 + i, LIVE),
      }, i == 1 and LIVE or GREY)
    end
  end
  for _, rk in ipairs(PHASE_KEYS) do
    local first, last = H.phase + rk * 10 + 1, H.phase + rk * 10 + #PHASES
    for m, ph in ipairs(PHASES) do
      macro(H.phase + rk * 10 + m, ph[1], {
        "SetVar $FSPH_" .. rk .. " = " .. m,
        ap(first, GREY):gsub("Macro " .. first, "Macro " .. first .. " Thru " .. last),
        ap(H.phase + rk * 10 + m, LIVE),
      }, m == 2 and LIVE or GREY)
    end
  end
  -- INIT: default variables (also run at the end of the build)
  l = {"SetVar $FSMODE = 0", "SetVar $FSN = 0", "SetVar $FSC = 0", ap(H.prep, GREY)}
  for _, fk in ipairs(FADE_KEYS) do l[#l + 1] = "SetVar $FSF_" .. fk .. " = 0" end
  for _, rk in ipairs(PHASE_KEYS) do l[#l + 1] = "SetVar $FSPH_" .. rk .. " = 2" end
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(groups) do l[#l + 1] = "SetVar $FSP_" .. row.key .. "_" .. g.i .. " = 0" end
  end
  macro(H.init, "FS INIT", l, {0, 60, 0})
  -- Bumps layout buttons: X-Key and strobe toggles per group (hold-to-flash stays on the executors)
  local p = CFG.PAGE.bump
  macro(H.bump + 1, "ALL KEYS", {"Toggle Executor " .. p .. "." .. (CFG.EXEC + 31) .. " Thru " .. p .. "." .. (CFG.EXEC + 30 + #groups)}, {80, 80, 80})
  macro(H.bump + 2, "ALL STROBE", {"Toggle Executor " .. p .. "." .. (CFG.EXEC + 20)}, {100, 100, 100})
  for _, g in ipairs(groups) do
    macro(H.bump + g.i * 10 + 1, g.name, {"Toggle Executor " .. p .. "." .. (CFG.EXEC + 30 + g.i)}, GREY)
    macro(H.bump + g.i * 10 + 2, "STROBE", {"Toggle Executor " .. p .. "." .. (CFG.EXEC + 10 + g.i)}, {100, 100, 100})
  end
end

-------------------------------------------------------------------------------------------------
-- Layouts
-------------------------------------------------------------------------------------------------
local function place(no, lay, x, y)
  local yy = (CFG.Y_DOWN and -y or y) * CFG.GRID_Y
  cmd(string.format("Assign Macro %d Layout %d /x=%g /y=%g", no, lay, x * CFG.GRID_X, yy + 0.0))
end

local function build_layouts()
  for i, n in ipairs(LAYOUTS) do
    local lay = CFG.LAYOUT + i - 1
    cmd("ClearAll")
    cmd("Delete Layout " .. lay .. " /noconfirm")
    cmd("Store Layout " .. lay .. " /noconfirm")
    if not handle("Layout " .. lay) then errors[#errors + 1] = "Store Layout " .. lay .. " made nothing" end
    cmd("Label Layout " .. lay .. " " .. q(n))
    -- header row 0: page buttons, PREP, FIRE, TAP, STROBE ALL, ALL OFF
    local x = 0
    for j = 1, #LAYOUTS do place(H.nav + j, lay, x, 0); x = x + 1 end
    x = x + 1
    for _, m in ipairs({H.prep, H.fire, H.tap, H.strobe, H.alloff}) do place(m, lay, x, 0); x = x + 1 end
    -- row 1: fade (and phase on FX pages)
    local rows = {}
    for _, row in ipairs(ROWS) do if row.lay == i then rows[#rows + 1] = row end end
    if i == BUMP_LAYOUT then
      for k = 0, #groups do
        place(H.bump + k * 10 + 1, lay, 0, 2 + k)
        place(H.bump + k * 10 + 2, lay, 1, 2 + k)
      end
    else
    x = 0
    local fk = rows[1].fade
    for f = 1, #FADES do place(H.fade + fk * 10 + f, lay, x, 1); x = x + 1 end
    if rows[1].fx then
      x = x + 1
      for m = 1, #PHASES do place(H.phase + rows[1].key * 10 + m, lay, x, 1); x = x + 1 end
    end
    -- group rows from row 3
    for _, row in ipairs(rows) do
      for k = 0, #groups do
        for c = 0, #looks(row) + 1 do
          place(macro_no(row, k, c), lay, row.col0 + c, 3 + k)
        end
      end
    end
    end
  end
  cmd("Layout " .. CFG.LAYOUT)
end

-------------------------------------------------------------------------------------------------
-- Checks
-------------------------------------------------------------------------------------------------
local function ours(h)
  local n = objname(h)
  return n == nil or n == "" or n:sub(1, 3) == "FS " or n:sub(1, 3) == "FS_"
end

-- Lists pool objects in our ranges that hold someone else's work.
local function foreign()
  local f = {}
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(groups) do
      local h = handle("Sequence " .. seq_no(row, g))
      if h and not ours(h) then f[#f + 1] = "Sequence " .. seq_no(row, g) .. " (" .. objname(h) .. ")" end
    end
  end
  -- macros: skipped once FireSystem has built here (show variable FSBUILT)
  local ok, built = pcall(gma.show.getvar, "FSBUILT")
  local nm = 0
  for m = CFG.MACRO, (ok and built) and CFG.MACRO - 1 or H.last do
    local h = handle("Macro 1." .. m)
    if h and not ours(h) then nm = nm + 1 end
  end
  if nm > 0 then f[#f + 1] = nm .. " macros in " .. CFG.MACRO .. "-" .. (H.last) end
  for i = 1, #LAYOUTS do
    local h = handle("Layout " .. (CFG.LAYOUT + i - 1))
    if h and not ours(h) then f[#f + 1] = "Layout " .. (CFG.LAYOUT + i - 1) .. " (" .. objname(h) .. ")" end
  end
  return f
end

local function verify()
  local missing = {}
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(groups) do
      local s = seq_no(row, g)
      local h = handle("Sequence " .. s)
      if not h then
        missing[#missing + 1] = "Sequence " .. s
      else
        local n = amount(h)
        if n and n < 2 then missing[#missing + 1] = "cues in Sequence " .. s .. " (" .. n .. ")" end
      end
      if not handle("Executor " .. exec_of(row, g)) then missing[#missing + 1] = "Executor " .. exec_of(row, g) end
    end
  end
  local nm = 0
  for _, m in ipairs(all_macros) do
    if not handle("Macro 1." .. m) then
      nm = nm + 1
      if nm <= 10 then missing[#missing + 1] = "Macro " .. m end
    end
  end
  if nm > 10 then missing[#missing + 1] = "... " .. (nm - 10) .. " more macros" end
  for i = 1, #LAYOUTS do
    if not handle("Layout " .. (CFG.LAYOUT + i - 1)) then missing[#missing + 1] = "Layout " .. (CFG.LAYOUT + i - 1) end
  end
  return missing
end

-------------------------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------------------------
local function Start()
  count, errors, groups, forms, gels, all_macros = 0, {}, {}, {}, {}, {}
  find_groups()
  if #groups == 0 then
    gma.gui.msgbox("FireSystem MA2", "No groups found. Store groups " .. table.concat(CFG.GROUPS, ", ") .. " first.")
    return
  end
  find_forms()
  find_gels()

  local f = foreign()
  local msg = "Build FireSystem for " .. #groups .. " groups?\n\nExecutor pages " .. CFG.PAGE.dim .. "-" .. CFG.PAGE.cfx ..
    ", sequences " .. CFG.SEQ .. "+, macros " .. CFG.MACRO .. "-" .. (H.last) .. ", layouts " .. CFG.LAYOUT .. "-" ..
    (CFG.LAYOUT + #LAYOUTS - 1) .. ".\nThe programmer is cleared."
  if #f > 0 then msg = msg .. "\n\nThese are not FireSystem's and will be OVERWRITTEN:\n" .. table.concat(f, "\n") end
  if not gma.gui.confirm("FireSystem MA2", msg) then return end

  local steps = #ROWS * #groups + #ROWS + 3
  prog_start("FireSystem MA2", steps)
  local step = 0
  -- clear our variables so the macro lines are stored with $names, not their values
  for _, v in ipairs({"FSMODE", "FSN", "FSC"}) do cmd("SetVar $" .. v .. " =") end
  for _, k in ipairs(FADE_KEYS) do cmd("SetVar $FSF_" .. k .. " =") end
  for _, k in ipairs(PHASE_KEYS) do cmd("SetVar $FSPH_" .. k .. " =") end
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(groups) do cmd("SetVar $FSP_" .. row.key .. "_" .. g.i .. " =") end
  end
  make_pages()
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(groups) do
      step = step + 1
      prog(step, row.title .. " " .. g.name)
      build_row_cues(row, g)
    end
  end
  -- a rebuild clears our whole macro range first, so buttons from an older layout don't stay behind
  local ok, built = pcall(gma.show.getvar, "FSBUILT")
  if ok and built then cmd("Delete Macro " .. CFG.MACRO .. " Thru " .. H.last .. " /noconfirm") end
  step = step + 1; prog(step, "Bumps")
  build_bumps()
  for _, row in ipairs(ROWS) do
    step = step + 1; prog(step, "Buttons " .. row.title)
    build_row_macros(row)
  end
  step = step + 1; prog(step, "Header")
  build_header()
  step = step + 1; prog(step, "Layouts")
  build_layouts()
  cmd("ClearAll")
  cmd("Macro " .. H.init)
  cmd("SetVar $FSBUILT = 1")
  prog_stop()

  local missing = verify()
  local out = "Done: " .. count .. " commands, " .. #groups .. " groups.\n"
  if #errors > 0 then out = out .. "\nWarnings:\n" .. table.concat(errors, "\n") .. "\n" end
  local nogel = {}
  for _, c in ipairs(COLOURS) do if not gels[c[1]] then nogel[#nogel + 1] = c[1] end end
  if #nogel > 0 then out = out .. "\nGel not found (used RGB instead): " .. table.concat(nogel, ", ") .. "\n" end
  if #missing > 0 then
    out = out .. "\nMA2 did not make:\n" .. table.concat(missing, "\n")
  else
    out = out .. "\nEverything checked is there. Open a Layout View on layout " .. CFG.LAYOUT .. "."
  end
  echo(out)
  gma.gui.msgbox("FireSystem MA2", out)
end

local function Cleanup()
  prog_stop()
end

return Start, Cleanup
