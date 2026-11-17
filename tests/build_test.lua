-- What a build sends to MA2 (checked through the stand-in's command list).
local ma = require("ma2_stub")

local function build(groups, setup)
  local stub, Start = ma.load(groups)
  if setup then setup(stub) end
  Start()
  return stub, ma.find(Start, "CFG"), ma.find(Start, "H"), ma.find(Start, "ROWS")
end

local function grep(stub, pattern)
  local out = {}
  for _, c in ipairs(stub.cmds) do
    local n = c:match(pattern)
    if n then out[#out + 1] = tonumber(n) end
  end
  return out
end

-- rows: SEQ + 20 per row; bumps SEQ + 101-108, strobes SEQ + 121-128, Strobe All SEQ + 140
test("cues only go into its sequence ranges", function()
  local stub, CFG, _, ROWS = build({1, 2})
  local cues = grep(stub, "^Store Cue %d+ Sequence (%d+)")
  t.ok(#cues > 0, "no cues stored")
  t.ok(#ROWS * 20 <= 100, "rows run into the bump sequences")
  for _, s in ipairs(cues) do
    local o = s - CFG.SEQ
    t.ok((o > 0 and o <= #ROWS * 20) or (o > 100 and o <= 108) or (o > 120 and o <= 128) or o == 140, "Sequence " .. s)
  end
end)

test("macros only go into the range the confirm dialog announces", function()
  local stub, CFG, H = build({1, 2})
  local macros = grep(stub, "^Store Macro 1%.(%d+)$")
  t.ok(#macros > 0, "no macros stored")
  for _, m in ipairs(macros) do t.ok(m >= CFG.MACRO and m <= H.phase + 60, "Macro " .. m) end
  t.ok(stub.confirms[1]:find("macros " .. CFG.MACRO .. "%-" .. (H.phase + 60)), "range not announced")
end)

test("only the groups that exist get rows", function()
  local stub = build({1, 3})
  local text = table.concat(stub.cmds, "\n")
  t.ok(text:find('"FS DIM FX G1"', 1, true), "no row for group 1")
  t.ok(text:find('"FS DIM FX G3"', 1, true), "no row for group 3")
  t.ok(not text:find('"FS DIM FX G2"', 1, true), "row for missing group 2")
end)

test("no groups: it says so and builds nothing", function()
  local stub = build({})
  t.eq(#stub.cmds, 0)
  t.ok(stub.messages[1] and stub.messages[1]:find("No groups found"), "no message")
end)

test("Cancel in the confirm dialog builds nothing", function()
  local stub = build({1}, function(s) s.confirm = false end)
  t.eq(#stub.cmds, 0)
end)

test("someone else's layout in its range is named in the confirm dialog", function()
  local stub = build({1}, function(s) s.objects["Layout 101"] = "My stage plot" end)
  t.ok(stub.confirms[1]:find("OVERWRITTEN") and stub.confirms[1]:find("My stage plot", 1, true),
    "foreign layout not listed")
end)

test("effect forms are found by name", function()
  local stub = build({1}, function(s)
    for i, n in ipairs({"Sin", "Cos", "PWM", "Ramp Plus", "Ramp Minus"}) do s.objects["Form " .. i] = n end
  end)
  t.ok(not stub.messages[1]:find("No effect form"), "forms reported missing")
end)
