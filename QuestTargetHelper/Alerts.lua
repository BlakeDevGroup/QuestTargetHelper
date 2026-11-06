-- "Quest complete" and "nothing left here" alerts, from the quest log.
local _, ns = ...
local Quest = ns.Quest

local A = {}
ns.Alerts = A

local SEEN_FOR = 30   -- a quest mob seen this recently counts as "here"
local SETTLE = 2.5    -- let tooltips be re-read after the log changes

local function plain(v) return v ~= nil and not ns.IsSecret(v) end

-- questID -> title for every quest in the log that is ready to turn in.
local function completed()
  local out = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and plain(info.questID) then
        local id = info.questID
        local done = (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id))
          or (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id))
        if done == true then out[id] = info.title or "?" end
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() do
      local title, _, _, isHeader, _, isComplete, _, id = GetQuestLogTitle(i)
      if not isHeader and isComplete == 1 and id then out[id] = title end
    end
  end
  return out
end

local function announce(text)
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.8, b = 0 })
  end
  print("|cff55ff55QTH|r " .. text)
  if ns.settings.alertSound and PlaySound and SOUNDKIT then
    PlaySound(SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING or 8960)
  end
end

local known -- nil until the first scan, so logging in doesn't alert

function A.OnQuestLog()
  if not ns.settings.alerts then known = completed() return end
  local now = completed()
  if known then
    local any = false
    for id, title in pairs(now) do
      if not known[id] then
        announce("Quest complete: " .. title)
        any = true
      end
    end
    if any then C_Timer.After(SETTLE, function() ns.SafeCall("alerts", A.CheckAreaDone) end) end
  end
  known = now
end

-- Nothing left here: no quest mob seen in the last SEEN_FOR seconds still
-- counts for an unfinished objective.
function A.CheckAreaDone()
  local t = GetTime()
  local sawAny = false
  for _, e in pairs(Quest.cache) do
    if t - e.seen < SEEN_FOR then
      sawAny = true
      if Quest.OpenObjectives(e) > 0 then return end
    end
  end
  if sawAny then announce("Nothing left to kill here, go turn in") end
end
