-- Run from the repo root: lua tests/run_all.lua (or lua tests/math_test.lua)
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local M = H.addon({ "Math" }).Math
local T = H.suite("math")
local eq = T.eq

-- Descriptions copied from the Forever client (probe report 1).
local t, d, tick = M.ParseDescription("Corrupts the target, causing 103 Shadow damage over 15 sec.")
eq("corruption total", t, 103); eq("corruption duration", d, 15); eq("corruption tick", tick, nil)

t, d = M.ParseDescription("Burns the enemy for 27 Fire damage and then an additional 48 Fire damage over 15 sec.")
eq("immolate periodic only", t, 48); eq("immolate duration", d, 15)

t, d = M.ParseDescription("Afflicts the target with agony, causing 118 Shadow damage over 24 sec. This damage is dealt slowly at first.", "agony")
eq("agony total", t, 118); eq("agony duration", d, 24)

t, d, tick = M.ParseDescription("Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec.")
eq("siphon total", t, 150); eq("siphon duration", d, 30); eq("siphon tick", tick, 3)

t, d = M.ParseDescription("Causes 1,234 Shadow damage over 18 sec.")
eq("thousands separator", t, 1234)

local rip = "Finishing move that causes damage over time.  Damage increases per combo point:\n" ..
  "1 point : 243 damage over 12 sec.\n2 points: 396 damage over 12 sec.\n3 points: 549 damage over 12 sec."
t = M.ParseDescription(rip, "finisher", 2); eq("rip 2 cp", t, 396)
t = M.ParseDescription(rip, "finisher", 9); eq("rip clamps to highest", t, 549)
t = M.ParseDescription(rip, "finisher", nil); eq("rip no cp = 1 point", t, 243)

eq("no damage text", M.ParseDescription("Strikes fear in the enemy."), nil)
eq("empty", M.ParseDescription(""), nil)

-- Remaining damage steps down one whole tick at a time.
local e = M.NewEntry({ tick = 3 }, 103, 15, nil, 100)
eq("ticks", e.ticks, 5)
eq("at cast", M.Remaining(e, 100), 103)
eq("just before tick 1", M.Remaining(e, 102.99), 103)
eq("after tick 1", M.Remaining(e, 103), 103 * 4 / 5)
eq("after tick 4", M.Remaining(e, 112.5), 103 / 5)
eq("expired", M.Remaining(e, 115), 0)
eq("long expired", M.Remaining(e, 1e9), 0)

-- Description tick wins over the table's.
e = M.NewEntry({ tick = 2 }, 150, 30, 3, 0); eq("desc tick used", e.ticks, 10)

-- Agony ramps: 12 ticks of 2s, thirds at 0.5x / 1x / 1.5x the average.
e = M.NewEntry({ tick = 2, model = "agony" }, 120, 24, nil, 0)
eq("agony full", M.Remaining(e, 0), 120)
eq("agony after first third", M.Remaining(e, 8), 120 - 4 * 5)
eq("agony after two thirds", M.Remaining(e, 16), 4 * 15)
eq("agony last tick", M.Remaining(e, 22), 15)

return T.done()
