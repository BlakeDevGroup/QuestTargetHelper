-- Pure DoT math: no WoW API calls, so tests/math_test.lua can run it in plain Lua.
local _, ns = ...
ns = ns or {}
local M = {}
ns.Math = M

local floor, max, min = math.floor, math.max, math.min

-- Finisher descriptions list damage per combo point, e.g.
--   "1 point : 243 damage over 12 sec. 2 points: 396 damage over 12 sec."
local function parseFinisher(desc, cp)
  local byPoints, highest = {}, 0
  for p, amount, secs in desc:gmatch("(%d+) points?%s*:%s*(%d+) damage over (%d+%.?%d*) sec") do
    p = tonumber(p)
    byPoints[p] = { total = tonumber(amount), duration = tonumber(secs) }
    highest = max(highest, p)
  end
  if highest == 0 then return nil end
  local e = byPoints[max(1, min(cp or 1, highest))] or byPoints[highest]
  return e.total, e.duration
end

-- Returns totalDamage, duration, tickFromDesc (or nil when nothing parses).
--   "causing 103 Shadow damage over 15 sec."           -> 103, 15
--   "27 Fire damage and then an additional 48 Fire damage over 15 sec" -> 48, 15 (last clause = periodic part)
--   "Transfers 15 health ... every 3 sec. Lasts 30 sec." -> 150, 30, 3
function M.ParseDescription(desc, model, cp)
  if type(desc) ~= "string" or desc == "" then return nil end
  desc = desc:gsub("(%d),(%d)", "%1%2")
  if model == "finisher" then
    local total, duration = parseFinisher(desc, cp)
    if total then return total, duration end
  end
  local total, duration
  for amount, secs in desc:gmatch("(%d+)[%a%s]-damage over (%d+%.?%d*) sec") do
    total, duration = tonumber(amount), tonumber(secs)
  end
  if total then return total, duration end
  local amount, every = desc:match("(%d+) health.-every (%d+%.?%d*) sec")
  local lasts = desc:match("[Ll]asts (%d+%.?%d*) sec")
  if amount and every and lasts then
    every, lasts = tonumber(every), tonumber(lasts)
    return tonumber(amount) * floor(lasts / every + 0.5), lasts, every
  end
  return nil
end

function M.NewEntry(def, total, duration, tick, now)
  tick = tick or def.tick or 3
  local ticks = max(1, floor(duration / tick + 0.5))
  return { total = total, duration = duration, tick = tick, ticks = ticks,
    start = now, model = def.model }
end

-- Share of the total that tick i (1-based) deals.
local function weight(entry, i)
  if entry.model ~= "agony" then return 1 / entry.ticks end
  -- Agony: first third at half, middle third at full, last third at 1.5x the average.
  local third = entry.ticks / 3
  local w = (i <= third and 0.5) or (i <= 2 * third and 1.0) or 1.5
  return w / entry.ticks
end

-- Damage still to come at time `now`. Counts only whole ticks not yet dealt.
function M.Remaining(entry, now)
  local elapsed = now - entry.start
  if elapsed >= entry.duration then return 0 end
  local done = min(entry.ticks, floor(elapsed / entry.tick + 1e-6))
  if entry.model ~= "agony" then
    return entry.total * (entry.ticks - done) / entry.ticks
  end
  local share = 0
  for i = done + 1, entry.ticks do share = share + weight(entry, i) end
  return entry.total * share
end

return M
