-- Tiny test runner: lua tests/run.lua tests/foo_test.lua ...
-- A test file gets `test(name, fn)` and the helpers in `t` (t.eq, t.ok, t.near, t.err) as globals.
package.path = "tests/?.lua;" .. package.path

local t = {}
local function fmt(v)
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local o = {}
  for _, k in ipairs(keys) do o[#o + 1] = tostring(k) .. "=" .. fmt(v[k]) end
  return "{" .. table.concat(o, ", ") .. "}"
end
t.fmt = fmt

local function deepeq(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not deepeq(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function t.eq(got, want, msg)
  if not deepeq(got, want) then
    error((msg and (msg .. ": ") or "") .. "expected " .. fmt(want) .. ", got " .. fmt(got), 2)
  end
end
function t.ok(v, msg) if not v then error(msg or "expected a true value", 2) end end
function t.near(got, want, eps, msg)
  eps = eps or 1e-6
  if type(got) ~= "number" or math.abs(got - want) > eps then
    error((msg and (msg .. ": ") or "") .. "expected ~" .. tostring(want) .. ", got " .. fmt(got), 2)
  end
end
function t.err(fn, pattern, msg)
  local ok, e = pcall(fn)
  if ok then error((msg or "expected an error") , 2) end
  if pattern and not tostring(e):find(pattern) then error("error " .. tostring(e) .. " does not match " .. pattern, 2) end
end

local cases = {}
local env = setmetatable({test = function(name, fn) cases[#cases + 1] = {name, fn} end, t = t}, {__index = _G})

local passed, failed = 0, 0
for _, file in ipairs(arg) do
  cases = {}
  local chunk, err = loadfile(file, "t", env)
  if not chunk then
    print("FAIL " .. file .. ": " .. err) failed = failed + 1
  else
    local ok, e = pcall(chunk)
    if not ok then print("FAIL " .. file .. ": " .. tostring(e)) failed = failed + 1 end
    for _, c in ipairs(cases) do
      local ok2, e2 = xpcall(c[2], debug.traceback)
      if ok2 then passed = passed + 1
      else failed = failed + 1 print("FAIL " .. file .. " > " .. c[1] .. "\n  " .. tostring(e2):gsub("\n", "\n  ")) end
    end
  end
end
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
