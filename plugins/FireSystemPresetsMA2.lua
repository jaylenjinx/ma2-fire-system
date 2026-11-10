-- FireSystem Presets MA2: makes the presets of the grandMA3 FireSystem on grandMA2 (3.9), for
-- groups 1-12. Presets only: no sequences, executors, macros, layouts or views.
--
-- Run it from the Plugins pool. It asks whether to replace presets that are already there
-- (Yes = make them all again, No = only make the missing ones). It only touches its own numbers.
--
-- Every pool starts at preset 1 (the same presets as FireSystem on MA3, numbered from .1;
-- MA3's All 1 pool 21 is MA2's All pool 0). The list is in the README.
-- Shutter, gobo, prism, rotation and iris values are read from each fixture type's channel sets,
-- so one preset holds the right value for every fixture type in groups 1-12.
-- MA3 builds its effects as phasers; MA2 has none, so the moving presets hold MA2 effect layers
-- (form, low, high, width, BPM) instead.

-------------------------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------------------------
local CFG = {
  GROUPS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},  -- missing groups are skipped
  PREFIX = "FS",          -- preset names start with this

  -- MA2 attribute names (the MA2 fixture library names)
  ATTR = {dim = "DIM", pan = "PAN", tilt = "TILT", zoom = "ZOOM", focus = "FOCUS"},

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
  -- Strobe G1-12 = 0.23-34, Rnd = 0.35-46, Gen = 0.47-58
  STROBE_GRP = {strobe = 22, random = 34, gen = 46},

  -- Shutter, gobo, prism and iris values come from each fixture type in the show (its channel
  -- sets and ranges), so every fixture type gets its own value in the same preset
  STROBE_HZ = 10,          -- shutter strobe speed (fast)
  STROBE_SLOW_HZ = 2,      -- Strobe Slow
  ROT_SLOW = 0.25,         -- gobo / prism rotation: share of the fixture's fastest speed
  ROT_FAST = 0.9,
  MAX_SLOTS = 10,          -- gobo slots per wheel (slot 1 = open)
  PRISMS = 4,              -- prism slots after Open
  PRISM_ATTRS = {"PRISMA1", "PRISM1", "PRISMA", "EFFECTWHEEL"},  -- the first one a fixture has
  MAX_FIXTURE_ID = 9999,   -- fixture IDs searched for their fixture type

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
  zoom = 1, focus = 6,                             -- Focus 6.1-5 zoom, 6.6-8 focus
  g1 = 1, g2 = 11, g1rot = 21, g2rot = 26,         -- Gobo 3.1-10 G1 slots, 3.11-20 G2, 3.21-25 / 3.26-30 rotation
  shutter = 1, iris = 7, prism = 10, prismrot = 15, -- Beam 5.1-6, 5.7-9, 5.10-14, 5.15-19
  strobe = 1, fly = 4, bump = 10,                  -- All 0.1-3, 0.4-9, 0.10-22 (per-group strobes 0.23+)
}
-- rotation presets: {label, direction, speed}
local ROTS = {{"Stop", "stop"}, {"> Slow", ">", "slow"}, {"> Fast", ">", "fast"}, {"< Slow", "<", "slow"}, {"< Fast", "<", "fast"}}

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

local function store(pool, no, label, lines, sel)
  local id = pool .. "." .. no
  if skip(id) then return false end
  cmd("ClearAll")
  cmd("MAtricksReset")
  cmd(sel or group_list())
  for _, l in ipairs(lines) do cmd(l) end
  cmd("Store Preset " .. id .. " /overwrite /selective /noconfirm")
  if label ~= "" then cmd("Label Preset " .. id .. " " .. q(CFG.PREFIX .. " " .. label)) end
  cmd("ClearAll")
  cmd("MAtricksReset")
  if handle("Preset " .. id) then made = made + 1 return true end
  missing[#missing + 1] = "Preset " .. id .. " " .. label
  return false
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
-- Fixture types: wheels, shutter ranges and rotation read from the show's fixture types
-------------------------------------------------------------------------------------------------
-- T[t] = {no, name, sel = "Fixture 2101 Thru 2118", attrs = {GOBO1 = {attr, mode, div, funcs}}}
-- funcs = {sub, name, wheel, from, to, dfrom, dto, pfrom, pto, ms, me, sets}
-- sets  = {name, from, to, dfrom, dto, slot, pfrom, pto}
-- Values are what MA2 takes after "At" (the From / To of the profile); DMX for the mode ranges.
local T, types, gtypes = {}, {}, {}   -- types = the type numbers used in the groups; gtypes[g] = {t...}

local function props(h)
  local t = {}
  local ok, n = pcall(gma.show.property.amount, h)
  if not ok or not n then return t end
  for i = 0, n - 1 do
    local ok2, k = pcall(gma.show.property.name, h, i)
    local ok3, v = pcall(gma.show.property.get, h, i)
    if ok2 and k then t[k] = ok3 and v or nil end
  end
  return t
end

local function kids(h)
  local l = {}
  local ok, n = pcall(gma.show.getobj.amount, h)
  if not ok or not n then return l end
  for i = 0, n - 1 do
    local ok2, c = pcall(gma.show.getobj.child, h, i)
    if ok2 and c then l[#l + 1] = c end
  end
  return l
end

local function class(h)
  local ok, c = pcall(gma.show.getobj.class, h)
  return ok and c or ""
end

local function nb(v) return tonumber(tostring(v or ""):match("^%s*(%-?[%d%.]+)")) end

local function read_type(t)
  local h = handle("FixtureType " .. t)
  if not h then return nil end
  local ft = {no = t, name = objname(h) or ("Type " .. t), attrs = {}, fix = {}}
  local function walk(x, depth)
    for _, c in ipairs(kids(x)) do
      local cl = class(c)
      if cl == "CMD_CHANNEL_TYPE" then
        local p = props(c)
        local attr = tostring(p.Attrib or ""):match("^(%S+)")
        if attr and not ft.attrs[attr] then  -- the first module wins (main fixture before its cells)
          local ct = {attr = attr, mode = tostring(p.Mode or ""), funcs = {}, div = 1}
          local maxd = 0
          for _, fh in ipairs(kids(c)) do
            local fp = props(fh)
            local f = {sub = tostring(fp.SubAttrib or ""), name = tostring(fp.Name or ""), wheel = tostring(fp.Wheel or "None"),
                       from = nb(fp.From), to = nb(fp.To), dfrom = nb(fp["From|DMX"]), dto = nb(fp["To|DMX"]),
                       pfrom = nb(fp["From|Phys"]), pto = nb(fp["To|Phys"]), ms = nb(fp["Mode|Start"]), me = nb(fp["Mode|End"]),
                       sets = {}}
            if f.from and f.to then
              maxd = math.max(maxd, f.dto or 0)
              for _, sh in ipairs(kids(fh)) do
                local sp = props(sh)
                local s = {name = tostring(sp.Name or ""), from = nb(sp.From), to = nb(sp.To), dfrom = nb(sp["From|DMX"]),
                           dto = nb(sp["To|DMX"]), slot = nb(sp["Slot|No"]), pfrom = nb(sp["From|Phys"]), pto = nb(sp["To|Phys"])}
                if s.from and s.to then f.sets[#f.sets + 1] = s end
              end
              ct.funcs[#ct.funcs + 1] = f
            end
          end
          ct.div = maxd > 65535 and 65536 or maxd > 255 and 256 or 1
          ft.attrs[attr] = ct
        end
      elseif depth < 3 and (cl == "CMD_DMX_MODULE_COLLECT" or cl == "CMD_DMX_MODULE") then
        walk(c, depth + 1)
      end
    end
  end
  walk(h, 0)
  return ft
end

-- "1 Thru 4 + 7"
local function fix_list(ids)
  table.sort(ids)
  local out, i = {}, 1
  while i <= #ids do
    local j = i
    while j < #ids and ids[j + 1] == ids[j] + 1 do j = j + 1 end
    out[#out + 1] = (j > i) and (ids[i] .. " Thru " .. ids[j]) or tostring(ids[i])
    i = j + 1
  end
  return "Fixture " .. table.concat(out, " + Fixture ")
end

local function sel_count()
  local ok, n = pcall(gma.show.getvar, "SELECTEDFIXTURESCOUNT")
  return ok and tonumber(n) or nil
end

local function find_types()
  T, types, gtypes = {}, {}, {}
  local fixtures = {}
  local miss = 0
  for id = 1, CFG.MAX_FIXTURE_ID do
    local h = handle("Fixture " .. id)
    if h then
      local t = nb(props(h)["Fixture Type"])
      if t then
        fixtures[t] = fixtures[t] or {}
        table.insert(fixtures[t], id)
      end
    end
  end
  for t, ids in pairs(fixtures) do
    local ft = read_type(t)
    if ft then
      ft.sel = fix_list(ids)
      T[t] = ft
      local used = false
      for _, g in ipairs(groups) do
        cmd("ClearAll")
        cmd("Group " .. g.no .. " If " .. ft.sel)
        local n = sel_count()
        if n == nil or n > 0 then
          used = true
          gtypes[g.no] = gtypes[g.no] or {}
          table.insert(gtypes[g.no], t)
        end
      end
      if used then types[#types + 1] = t end
    end
  end
  cmd("ClearAll")
  table.sort(types)
  if #types == 0 then notes[#notes + 1] = "No fixture types found in the groups: shutter, gobo, prism and iris presets skipped" end
end

-- does group g hold a fixture type with this attribute?
local function group_has(g, attr)
  if not gtypes[g] then return true end  -- unknown: try it
  for _, t in ipairs(gtypes[g]) do if T[t].attrs[attr] then return true end end
  return false
end

local function mid(s) return (s.from + s.to) / 2 end
local function val(v) local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "") return s end

-- value of function / set f at the physical value p (Hz, rpm), else at fraction frac of its range
local function at_phys(f, p, frac)
  if p and f.pfrom and f.pto and f.pfrom ~= f.pto then
    local k = (p - f.pfrom) / (f.pto - f.pfrom)
    k = math.max(0.02, math.min(0.98, k))  -- inside the range: its ends touch the next function
    return f.from + k * (f.to - f.from)
  end
  return f.from + (frac or 0.5) * (f.to - f.from)
end

local function is_rot(f)
  if f.sub:upper():find("ROT") then return true end
  for _, s in ipairs(f.sets) do
    local n = s.name:lower()
    if n:find("rotat") or n:find("<<<") or n:find(">>>") then return true end
  end
  return false
end

-- the attribute that rotates wheel attribute `attr` and its function for the wheel's DMX value d8
local function rot_func(ft, attr, d8)
  for _, ct in pairs(ft.attrs) do
    if ct.mode == attr then
      for _, f in ipairs(ct.funcs) do
        if f.ms and f.me and d8 >= f.ms and d8 <= f.me then return ct, is_rot(f) and f or nil end
      end
    end
  end
  -- a separate index / rotate channel without modes (GOBO1_POS with its own rotate range)
  local ct = ft.attrs[attr .. "_POS"]
  if ct and ct.mode == "" then
    for _, f in ipairs(ct.funcs) do if is_rot(f) then return ct, f end end
  end
  return nil
end

local function stop_value(f)
  local best
  for _, s in ipairs(f.sets) do
    local n = s.name:lower():gsub("%s+$", "")
    if n == "stop" then return mid(s) end
    if not best and n:find("^stop") then best = mid(s) end
  end
  if best then return best end
  for _, s in ipairs(f.sets) do if s.pfrom == 0 and s.pto == 0 then return mid(s) end end
  return nil
end

local function wheel_sets(ft, attr)
  local ct = ft.attrs[attr]
  if not ct then return {} end
  local l = {}
  for _, f in ipairs(ct.funcs) do
    if f.wheel ~= "None" and f.wheel ~= "" then
      for _, s in ipairs(f.sets) do
        if s.slot then l[#l + 1] = {s = s, f = f, d8 = ((s.dfrom + s.dto) / 2) / ct.div} end
      end
    end
  end
  return l, ct
end

local function clean(n) return (n:gsub("<>", ""):gsub("%*", ""):gsub("%s*%(%d+%)$", ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- lines that put wheel `attr` of type ft on slot k; a slot that can rotate is taken in its
-- rotating range with the rotation stopped, so the rotation presets can turn it
local function slot_lines(ft, attr, k)
  local cands = wheel_sets(ft, attr)
  local pick, rf, rct
  for _, c in ipairs(cands) do
    if c.s.slot == k then
      local ct, f = rot_func(ft, attr, c.d8)
      if f and ct.mode == attr and stop_value(f) then pick, rf, rct = c, f, ct break end
      pick = pick or c
    end
  end
  if not pick then return nil end
  local l = {at(attr, val(mid(pick.s)))}
  if rf then l[#l + 1] = at(rct.attr, val(stop_value(rf))) end
  return l, clean(pick.s.name)
end

local function max_slot(attr)
  local m = 0
  for _, t in ipairs(types) do
    for _, c in ipairs(wheel_sets(T[t], attr)) do m = math.max(m, c.s.slot) end
  end
  return m
end

-- rotation of wheel `attr`: dir "stop", ">" or "<", speed "slow" or "fast"
local function rot_lines(ft, attr, dir, speed)
  local f, ct
  for _, c in ipairs(wheel_sets(ft, attr)) do
    local cct, cf = rot_func(ft, attr, c.d8)
    if cf then f, ct = cf, cct break end
  end
  if not f then
    local cct, cf = rot_func(ft, attr, -1)
    f, ct = cf, cct
  end
  if not f then return nil end
  if dir == "stop" then
    local v = stop_value(f)
    return v and {at(ct.attr, val(v))} or nil
  end
  -- speed ranges by direction: sign of the physical speed, else the order of the "rotate" sets
  local ranges = {}
  for _, s in ipairs(f.sets) do
    if s.pfrom and s.pto and s.pfrom ~= s.pto then
      local sign = (s.pfrom + s.pto > 0) and ">" or "<"
      ranges[#ranges + 1] = {s = s, dir = sign, max = math.max(math.abs(s.pfrom), math.abs(s.pto))}
    end
  end
  if #ranges == 0 then
    local n = 0
    for _, s in ipairs(f.sets) do
      local nm = s.name:lower()
      if math.abs(s.to - s.from) > 2 then
        if nm:find(">>>") then ranges[#ranges + 1] = {s = s, dir = ">"}
        elseif nm:find("<<<") then ranges[#ranges + 1] = {s = s, dir = "<"}
        elseif nm:find("rotat") then
          n = n + 1
          ranges[#ranges + 1] = {s = s, dir = (n == 1) and ">" or "<"}
        end
      end
    end
  end
  for _, r in ipairs(ranges) do
    if r.dir == dir then
      local s = r.s
      if r.max then
        local target = r.max * (speed == "slow" and CFG.ROT_SLOW or CFG.ROT_FAST)
        local p0, p1 = math.abs(s.pfrom), math.abs(s.pto)
        local k = (p0 == p1) and 0.5 or (target - p0) / (p1 - p0)
        k = math.max(0, math.min(1, k))
        return {at(ct.attr, val(s.from + k * (s.to - s.from)))}
      end
      local k = (speed == "slow") and CFG.ROT_SLOW or CFG.ROT_FAST
      return {at(ct.attr, val(s.from + k * (s.to - s.from)))}
    end
  end
  return nil
end

local function find_func(ct, test)
  if not ct then return nil end
  for _, f in ipairs(ct.funcs) do if test(f) then return f end end
end

local function find_set(ct, pattern, subtest)
  if not ct then return nil end
  for _, f in ipairs(ct.funcs) do
    if not subtest or subtest(f) then
      for _, s in ipairs(f.sets) do if s.name:lower():find(pattern) then return s end end
    end
  end
end

-- shutter lines of type ft: kind open / closed / strobe / slow / random / pulse
local function shutter_lines(ft, kind)
  local ct = ft.attrs.SHUTTER
  if not ct then return nil end
  local v
  local function shut(f) return f.sub:upper() == "SHUTTER" end
  if kind == "open" then
    local s = find_set(ct, "^open", shut)
    if s then v = mid(s) else
      local f = find_func(ct, function(f) return shut(f) and f.pfrom == 1 and f.pto == 1 end)
      v = f and (f.from + f.to) / 2
    end
  elseif kind == "closed" then
    local s = find_set(ct, "^clos", shut)
    v = s and mid(s)
  else
    local sub = ({strobe = "^STROBE$", slow = "^STROBE$", random = "^STROBE_RANDOM", pulse = "^STROBE_PULSE"})[kind]
    local f = find_func(ct, function(f) return f.sub:upper():find(sub) ~= nil end)
    if f then v = at_phys(f, kind == "slow" and CFG.STROBE_SLOW_HZ or CFG.STROBE_HZ, kind == "slow" and 0.2 or 0.8) end
  end
  return v and {at(ct.attr, val(v))} or nil
end

local function iris_lines(ft, kind)
  local ct = ft.attrs.IRIS
  if not ct then return nil end
  local open, closed = find_set(ct, "open"), find_set(ct, "clos")
  local o, c = open and mid(open), closed and mid(closed)
  if not (o and c) then
    local f = ct.funcs[1]
    if not f then return nil end
    if f.pfrom and f.pto and f.pfrom < f.pto then o, c = o or f.to, c or f.from else o, c = o or f.from, c or f.to end
  end
  local v = (kind == "open") and o or (kind == "closed") and c or (o + c) / 2
  return {at(ct.attr, val(v))}
end

local function prism_attr(ft)
  for _, a in ipairs(CFG.PRISM_ATTRS) do if ft.attrs[a] then return a end end
end

-- stores one preset made of each fixture type's own lines (sel = group selection, default all
-- groups); fallback = lines for the types fn gives nothing (nil: those types are left out)
local function store_types(pool, no, label, fn, fallback, sel)
  local l, any = {}, false
  local gno = sel and tonumber(sel:match("^Group (%d+)$"))
  local only = gno and gtypes[gno]
  for _, t in ipairs(only or types) do
    local x = fn(T[t])
    if x then any = true elseif fallback then x = fallback() end
    if x then
      l[#l + 1] = "ClearSelection"
      l[#l + 1] = (sel or group_list()) .. " If " .. T[t].sel
      add(l, x)
    end
  end
  if not any then return false, false end
  return true, store(pool, no, label, l, sel)
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
   if group_has(g.no, A.pan) then
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
  for i, f in ipairs({{"Focus Min", 0}, {"Focus Mid", 50}, {"Focus Max", 100}}) do
    store(6, N.focus + i - 1, f[1], {at(A.focus, f[2])})
  end
end

-- Gobo pool: each wheel's slots (slot 1 = open), then the rotation of the wheel
local function gobos()
  for w, attr in ipairs({"GOBO1", "GOBO2"}) do
    local tag = "G" .. w
    local n = math.min(max_slot(attr), CFG.MAX_SLOTS)
    for k = 1, n do
      local name
      local _, ok = store_types(3, N["g" .. w] + k - 1, "", function(ft)
        local l, nm = slot_lines(ft, attr, k)
        if l and not name then name = nm end
        return l
      end)
      -- named after the first fixture type that has the slot
      if ok then
        local lb = (k == 1) and (tag .. " Open") or (tag .. "." .. (k - 1) .. " " .. (name or ""))
        cmd("Label Preset 3." .. (N["g" .. w] + k - 1) .. " " .. q(CFG.PREFIX .. " " .. lb))
      end
    end
    for i, r in ipairs(ROTS) do
      store_types(3, N["g" .. w .. "rot"] + i - 1, tag .. " Rot " .. r[1], function(ft) return rot_lines(ft, attr, r[2], r[3]) end)
    end
  end
end

-- Beam pool: shutter, iris, prism and prism rotation
local function beam()
  for i, k in ipairs({{"Shutter Open", "open"}, {"Shutter Closed", "closed"}, {"Strobe Fast", "strobe"},
                      {"Strobe Slow", "slow"}, {"Strobe Rnd", "random"}, {"Strobe Pulse", "pulse"}}) do
    store_types(5, N.shutter + i - 1, k[1], function(ft) return shutter_lines(ft, k[2]) end)
  end
  for i, k in ipairs({{"Iris Open", "open"}, {"Iris Mid", "mid"}, {"Iris Closed", "closed"}}) do
    store_types(5, N.iris + i - 1, k[1], function(ft) return iris_lines(ft, k[2]) end)
  end
  for k = 1, CFG.PRISMS + 1 do
    local name
    local _, ok = store_types(5, N.prism + k - 1, "", function(ft)
      local a = prism_attr(ft)
      if not a then return nil end
      local l, nm = slot_lines(ft, a, k)
      if l and not name then name = nm end
      return l
    end)
    if ok then
      cmd("Label Preset 5." .. (N.prism + k - 1) .. " " ..
        q(CFG.PREFIX .. " " .. ((k == 1) and "Prism Open" or ("Prism " .. (k - 1) .. " " .. (name or "")))))
    end
  end
  for i, r in ipairs(ROTS) do
    store_types(5, N.prismrot + i - 1, "Prism Rot " .. r[1], function(ft)
      local a = prism_attr(ft)
      return a and rot_lines(ft, a, r[2], r[3])
    end)
  end
end

-- strobe lines for a selection without a shutter strobe: a dimmer effect
local function dim_strobe(kind)
  if kind == "pulse" then
    return forms.rdn and fx(A.dim, forms.rdn, 0, 100, CFG.PULSE_BPM) or nil
  end
  if not forms.pwm then return nil end
  if kind == "random" then
    return add({"ShuffleSelection"}, fx(A.dim, forms.pwm, 0, 100, CFG.STROBE_BPM, 50, "0 Thru 360"))
  end
  return fx(A.dim, forms.pwm, 0, 100, CFG.STROBE_BPM, 50)
end

-- MA3's strobes: the shutter's own strobe where the fixture has one, else a dimmer effect
local function strobe_preset(no, label, kind, sel)
  local function fn(ft) return shutter_lines(ft, kind) end
  local function fb() return dim_strobe(kind) end
  if #types == 0 or not store_types(0, no, label, fn, fb, sel) then
    local l = dim_strobe(kind)
    if l then store(0, no, label, l, sel) end
  end
end

local function strobes()
  for i, k in ipairs({{"Strobe", "strobe"}, {"Pulse Strb", "pulse"}, {"Rnd Strobe", "random"}}) do
    strobe_preset(N.strobe + i - 1, k[1], k[2])
  end
  for _, g in ipairs(groups) do
    for _, k in ipairs({{"strobe", "Strobe"}, {"random", "Rnd"}, {"gen", "Gen"}}) do
      -- the group only: its own selection, not every group
      strobe_preset(CFG.STROBE_GRP[k[1]] + g.no, k[2] .. " " .. g.name, k[1] == "gen" and "random" or k[1], "Group " .. g.no)
    end
  end
end

-- Bump options (All pool 0.10-22, MA3's 21.281-293), each fixture type's own values
local function bump_opts()
  local Z = CFG.ZOOM
  local function slot(attr, k) return function(ft) local a = attr or prism_attr(ft) return a and (slot_lines(ft, a, k)) end end
  local opts = {
    {"Dim 0", {at(A.dim, 0)}},
    {"Prism Open", slot(nil, 1)}, {"Prism 1", slot(nil, 2)}, {"Prism 2", slot(nil, 3)},
    {"Gobo 1", slot("GOBO1", 2)}, {"Gobo Open", slot("GOBO1", 1)},
    {"Iris Close", function(ft) return iris_lines(ft, "closed") end},
    {"Iris Open", function(ft) return iris_lines(ft, "open") end},
    {"Zoom Small", {at(A.zoom, Z[1])}},
    {"Zoom Big", {at(A.zoom, Z[4])}},
    {"Tilt Up", without(A.pan, {at(A.tilt, CFG.TILT_UP)})},
    {"Tilt Down", without(A.pan, {at(A.tilt, 0)})},
    {"Shutter Open", function(ft) return shutter_lines(ft, "open") end},
  }
  for i, o in ipairs(opts) do
    if type(o[2]) == "function" then store_types(0, N.bump + i - 1, "Bump " .. o[1], o[2])
    else store(0, N.bump + i - 1, "Bump " .. o[1], o[2]) end
  end
end

-------------------------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------------------------
local STEPS = {
  {"Dimmer", dimmer}, {"Colour", colors}, {"Position", position}, {"Position FX", position_fx},
  {"Fly In / Out", fly}, {"Zoom and Focus", focus}, {"Gobos", gobos}, {"Shutter, Iris, Prism", beam},
  {"Strobes", strobes}, {"Bump options", bump_opts},
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
    "\n\nPresets from .1 in Dimmer 1, Position 2, Gobo 3, Colour 4, Beam 5, Focus 6 and All 0." ..
    "\nPresets already there that aren't FireSystem's are left alone.\nThe programmer is cleared."
  if not gma.gui.confirm("FireSystem Presets", msg) then return end
  replace = gma.gui.confirm("FireSystem Presets",
    "Replace FireSystem presets that are already there?\n\nOK = make them all again\nCancel = only make the missing ones")

  prog_start("FireSystem Presets", #STEPS + 1)
  prog(0, "Reading fixture types")
  local ok, err = pcall(find_types)
  if not ok then notes[#notes + 1] = "Reading fixture types stopped: " .. tostring(err) end
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
