-- Smoke run: builds the show against the grandMA2 stand-in (tests/ma2_stub.lua) the way MA2
-- would: 8 groups with effect forms and swatch gels found, 1 group with nothing found, and a
-- rebuild. Any Lua error fails the run.
-- lua tests/smoke.lua
package.path = "tests/?.lua;" .. package.path
local ma = require("ma2_stub")

local failed, total, runs = 0, 0, 0
local function run(what, groups, setup)
  local stub, Start, Cleanup = ma.load(groups)
  if setup then setup(stub) end
  local ok, err = xpcall(function() Start() Cleanup() end, debug.traceback)
  if not ok then failed = failed + 1 print("FAIL " .. what .. ": " .. tostring(err)) end
  total, runs = total + #stub.cmds, runs + 1
end

local function rig(stub)
  for i, n in ipairs({"Sin", "Cos", "PWM", "Ramp Plus", "Ramp Minus"}) do stub.objects["Form " .. i] = n end
  stub.objects["Gel 12"] = "MA colors"
  stub.amounts["Gel 12"] = 3
  for j, n in ipairs({"White", "Red", "Blue"}) do stub.objects["Gel 12." .. j] = n end
end

run("8 groups, forms and gels found", {1, 2, 3, 4, 5, 6, 7, 8}, rig)
run("1 group, nothing found", {1})
run("rebuild", {1, 2}, function(stub)
  rig(stub)
  stub.vars.FSBUILT = "1"
  stub.objects["Layout 101"] = "FS Dim FX"
  stub.objects["Sequence 902"] = "FS DIM FX G1"
end)

print(string.format("smoke: %d builds, %d commands sent, %d failure(s)", runs, total, failed))
if failed > 0 then os.exit(1) end
