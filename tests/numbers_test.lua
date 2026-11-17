-- Pool numbers: sequences, executors and macros the plugin builds must never share a number.
local ma = require("ma2_stub")
local _, Start = ma.load()
local function f(name) return assert(ma.find(Start, name), name .. " not found") end
local CFG, ROWS, H = f("CFG"), f("ROWS"), f("H")
local seq_no, exec_of, macro_no = f("seq_no"), f("exec_of"), f("macro_no")
local G8 = {}
for i = 1, 8 do G8[i] = {no = i, i = i} end

test("every row and group gets its own sequence and executor", function()
  local seqs, execs = {}, {}
  for _, row in ipairs(ROWS) do
    for _, g in ipairs(G8) do
      local s, e = seq_no(row, g), exec_of(row, g)
      t.ok(not seqs[s], "Sequence " .. s .. " used twice")
      t.ok(not execs[e], "Executor " .. e .. " used twice")
      seqs[s], execs[e] = true, true
    end
  end
end)

test("row macros never collide and stay below the header block", function()
  local seen = {}
  for _, row in ipairs(ROWS) do
    for k = 0, 8 do
      for c = 0, f("ROW_W") - 1 do
        local m = macro_no(row, k, c)
        t.ok(not seen[m], "Macro " .. m .. " used twice")
        t.ok(m >= CFG.MACRO and m < H.prep, "Macro " .. m .. " outside the row block")
        seen[m] = true
      end
    end
  end
end)

test("q quotes a name", function()
  t.eq(f("q")("FS Dim FX"), '"FS Dim FX"')
end)
