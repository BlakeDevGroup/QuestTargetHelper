-- Which quests a mob counts for, read from its tooltip (plain in combat on
-- Forever): a quest title line followed by objective lines such as
-- "0/4 Zhevra Hooves" or "Zhevra Runner slain: 1/8".
local _, ns = ...
ns = ns or {}
local Q = { cache = {} } -- cache[guid] = { at, name, quests = { {title, objectives} } }
ns.Quest = Q

local LINE_OBJECTIVE = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective) or 8
local LINE_TITLE = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestTitle) or 17
-- "100% Threat": only on mobs you're in combat with (plain in combat on Forever).
local LINE_THREAT = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitThreat) or 7
local TTL = 2 -- seconds before a mob's tooltip is read again

-- "0/4 Zhevra Hooves" -> { text = "Zhevra Hooves", have = 0, need = 4, kill = false }
-- "Zhevra Runner slain: 1/8" -> { text = "Zhevra Runner slain", have = 1, need = 8, kill = true }
function Q.ParseObjective(line, mobName)
  if type(line) ~= "string" then return nil end
  local have, need = line:match("(%d+)%s*/%s*(%d+)")
  if not have then return nil end
  local text = line:gsub("%d+%s*/%s*%d+", ""):gsub("^[%s%-:]+", ""):gsub("[%s%-:]+$", "")
  local kill = text:find("[Ss]lain") ~= nil or (mobName ~= nil and text == mobName)
  return { text = text, have = tonumber(have), need = tonumber(need), kill = kill }
end

-- lines = { {type=, leftText=}, ... } as C_TooltipInfo returns them.
function Q.ParseTooltip(lines, mobName)
  local quests, current = {}, nil
  for _, l in ipairs(lines) do
    if l.type == LINE_TITLE and type(l.leftText) == "string" then
      current = { title = l.leftText, objectives = {} }
      quests[#quests + 1] = current
    elseif l.type == LINE_OBJECTIVE then
      local o = Q.ParseObjective(l.leftText, mobName)
      if o then
        if not current then
          current = { title = "", objectives = {} }
          quests[#quests + 1] = current
        end
        current.objectives[#current.objectives + 1] = o
      end
    end
  end
  return quests
end

-- Unfinished objectives this mob counts for (2+ = one kill, two objectives).
function Q.OpenObjectives(entry)
  local n = 0
  for _, q in ipairs(entry.quests) do
    for _, o in ipairs(q.objectives) do
      if o.have < o.need then n = n + 1 end
    end
  end
  return n
end

local function plain(v) return v ~= nil and not ns.IsSecret(v) end

-- Quest info for the mob behind `unit`, cached per GUID. Returns guid, entry
-- (entry.quests is empty for mobs that count for nothing).
function Q.ForUnit(unit, now)
  local guid = UnitGUID(unit)
  if not plain(guid) then return nil end
  local e = Q.cache[guid]
  if e and now - e.at < TTL then e.seen = now return guid, e end
  local name = UnitName(unit)
  local tip = C_TooltipInfo and C_TooltipInfo.GetUnit(unit)
  local quests, threat = {}, false
  if type(tip) == "table" and type(tip.lines) == "table" and plain(name) then
    local lines = {}
    for i, l in ipairs(tip.lines) do
      if plain(l.type) and plain(l.leftText) then
        lines[i] = l
        if l.type == LINE_THREAT then threat = true end
      else
        lines[i] = {}
      end
    end
    quests = Q.ParseTooltip(lines, name)
  end
  e = { at = now, seen = now, name = plain(name) and name or "?", quests = quests, threat = threat }
  Q.cache[guid] = e
  return guid, e
end

-- Quest log changed: re-read every tooltip on the next pass.
function Q.Invalidate()
  for _, e in pairs(Q.cache) do e.at = 0 end
end

-- Forget mobs not seen for a while that carry none of our DoTs.
function Q.Prune(now, tracked)
  for guid, e in pairs(Q.cache) do
    if now - e.seen > 60 and not tracked[guid] then Q.cache[guid] = nil end
  end
end

return Q
