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

-- In a group the tooltip also lists party members' progress: a line with the
-- member's name (QuestPlayer) followed by *their* objectives.
local LINE_PLAYER = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestPlayer) or 18

-- Title as a plain key: no colour codes, trimmed, lower case.
function Q.Key(title)
  if type(title) ~= "string" then return "" end
  return (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower())
end

-- lines = { {type=, leftText=}, ... } as C_TooltipInfo returns them.
-- isMine(title) -> false drops a quest that isn't in our own quest log.
-- playerName: a QuestPlayer line with our own name heads *our* progress.
function Q.ParseTooltip(lines, mobName, isMine, playerName)
  local quests, current, theirs = {}, nil, false
  for _, l in ipairs(lines) do
    if l.type == LINE_TITLE and type(l.leftText) == "string" then
      theirs = false
      if isMine and not isMine(l.leftText) then
        current = nil
        theirs = true -- a teammate's quest: skip its objectives too
      else
        current = { title = l.leftText, objectives = {} }
        quests[#quests + 1] = current
      end
    elseif l.type == LINE_PLAYER then
      -- What follows is that player's progress: ours only under our own name.
      theirs = not (playerName and Q.Key(l.leftText) == Q.Key(playerName))
      if theirs and current then current.teammates = true end
    elseif l.type == LINE_OBJECTIVE and not theirs then
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
  -- Drop a quest whose only progress lines were teammates'. A quest with no
  -- countable objective at all still counts: it marks a quest mob.
  local out = {}
  for _, q in ipairs(quests) do
    if #q.objectives > 0 or not q.teammates then out[#out + 1] = q end
  end
  return out
end

-- Titles of the quests in our own log. nil when the log can't be read, in
-- which case nothing is filtered out.
Q.myTitles = nil

-- Progress from our quest log: progress[title][objective text] = {have, need}.
-- The log updates the moment an item drops; unit tooltips lag behind, so
-- tooltips only say *which* mob counts for what, and the counts come from here.
Q.progress = {}

local function addProgress(progress, title, text, have, need)
  local o = Q.ParseObjective(text)
  if not o then return end
  if type(have) == "number" and type(need) == "number" then o.have, o.need = have, need end
  local key = Q.Key(title)
  progress[key] = progress[key] or {}
  progress[key][o.text] = { have = o.have, need = o.need }
end

function Q.RefreshLog()
  local titles, progress, any = {}, {}, false
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and type(info.title) == "string" then
        titles[Q.Key(info.title)], any = true, true
        local objs = info.questID and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID)
        for _, ob in ipairs(type(objs) == "table" and objs or {}) do
          addProgress(progress, info.title, ob.text, ob.numFulfilled, ob.numRequired)
        end
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local title, _, _, isHeader = GetQuestLogTitle(i)
      if not isHeader and type(title) == "string" then
        titles[Q.Key(title)], any = true, true
        for j = 1, (GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0) do
          addProgress(progress, title, (GetQuestLogLeaderBoard(j, i)))
        end
      end
    end
  end
  -- An empty log reads the same as a failed read; only trust a log with quests.
  Q.myTitles = any and titles or nil
  Q.progress = progress
end

-- have, need for an objective seen in a tooltip, preferring the quest log.
function Q.Progress(title, o)
  local t = Q.progress[Q.Key(title)]
  local p = t and t[o.text]
  if p then return p.have, p.need end
  return o.have, o.need
end

local function isMine(title)
  return Q.myTitles == nil or Q.myTitles[Q.Key(title)] == true
end
Q.IsMine = isMine

-- Unfinished objectives this mob counts for, counts from the quest log.
function Q.OpenObjectives(entry)
  return ns.Rules.OpenObjectives(entry, Q.Progress)
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
        -- "100% Threat" is *our* threat. In a group the line can show on mobs
        -- only a teammate touched, at 0%; only a share above 0 means ours.
        if l.type == LINE_THREAT then
          local pct = tonumber(l.leftText:match("(%d+)%%"))
          if pct and pct > 0 then threat = true end
        end
      else
        lines[i] = {}
      end
    end
    quests = Q.ParseTooltip(lines, name, isMine, UnitName("player"))
  end
  e = { at = now, seen = now, name = plain(name) and name or "?", quests = quests, threat = threat }
  Q.cache[guid] = e
  return guid, e
end

-- Quest log changed: re-read our titles, and every tooltip on the next pass.
function Q.Invalidate()
  Q.RefreshLog()
  for _, e in pairs(Q.cache) do e.at = 0 end
end

-- Forget mobs not seen for a while that carry none of our DoTs.
function Q.Prune(now, tracked)
  for guid, e in pairs(Q.cache) do
    if now - e.seen > 60 and not tracked[guid] then Q.cache[guid] = nil end
  end
end

return Q
