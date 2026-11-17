-- Compiles each file with Lua 5.4 (grandMA3 2.4+): lua tests/syntax.lua file.lua ...
-- Catches syntax errors and Lua 5.4 limits such as the 200 locals of one function or chunk.
local bad = 0
for _, f in ipairs(arg) do
  local chunk, err = loadfile(f, "t")
  if not chunk then print(err) bad = bad + 1 end
end
print(string.format("syntax: %d file(s), %d error(s)", #arg, bad))
if bad > 0 then os.exit(1) end
