-- A stand-in for grandMA2's Lua API (gma.*), just enough to run the plugin outside MA2.
-- stub.cmds holds every gma.cmd() string; stub.objects[name] = true (or a label string) makes
-- gma.show.getobj.handle find that object ("Group 1", "Form 3", "Gel 12" ...); nothing exists
-- otherwise. stub.confirm is what gma.gui.confirm answers (true = Build), stub.vars the show
-- variables. load() runs plugins/FireSystemMA2.lua the way MA2 does: it returns Start, Cleanup.
local M = {}

function M.new()
  local stub = {cmds = {}, messages = {}, confirms = {}, vars = {}, objects = {}, amounts = {}, confirm = true}
  local G = {}
  for k, v in pairs(_G) do G[k] = v end
  G._G = G
  local handles, byHandle = {}, {}
  local function handle(name)
    if not stub.objects[name] then return nil end
    if not handles[name] then
      handles[name] = #byHandle + 1
      byHandle[#byHandle + 1] = name
    end
    return handles[name]
  end
  local function label(h)
    local name = byHandle[h]
    local o = name and stub.objects[name]
    return type(o) == "string" and o or name
  end
  G.gma = {
    cmd = function(c) stub.cmds[#stub.cmds + 1] = c end,
    echo = function() end,
    feedback = function() end,
    sleep = function() end,
    show = {
      getobj = {
        handle = handle,
        label = label,
        name = label,
        amount = function(h) return stub.amounts[byHandle[h]] or 0 end,
      },
      getvar = function(k) return stub.vars[k] end,
      setvar = function(k, v) stub.vars[k] = v end,
    },
    gui = {
      msgbox = function(_, text) stub.messages[#stub.messages + 1] = text end,
      confirm = function(_, text) stub.confirms[#stub.confirms + 1] = text return stub.confirm end,
      progress = {start = function() return 1 end, setrange = function() end, set = function() end,
                  settext = function() end, stop = function() end},
    },
  }
  stub.G = G
  return stub
end

-- Loads the plugin into a fresh stub. With groups (a list of numbers), those groups exist.
-- Returns stub, Start, Cleanup.
function M.load(groups, file)
  local stub = M.new()
  for _, g in ipairs(groups or {}) do stub.objects["Group " .. g] = "G" .. g end
  local chunk = assert(loadfile(file or "plugins/FireSystemMA2.lua", "t", stub.G))
  local Start, Cleanup = chunk()
  assert(type(Start) == "function", "FireSystemMA2.lua did not return Start")
  return stub, Start, Cleanup
end

-- The plugin keeps its helpers in locals. find(Start, "seq_no") looks one up through the
-- upvalues of Start and of every function reachable from it.
function M.find(fn, name)
  local seen = {}
  local function walk(f)
    if seen[f] then return nil end
    seen[f] = true
    local i = 1
    while true do
      local n, v = debug.getupvalue(f, i)
      if not n then break end
      if n == name then return v end
      i = i + 1
    end
    i = 1
    while true do
      local n, v = debug.getupvalue(f, i)
      if not n then break end
      if type(v) == "function" then
        local r = walk(v)
        if r ~= nil then return r end
      end
      i = i + 1
    end
    return nil
  end
  return walk(fn)
end

return M
