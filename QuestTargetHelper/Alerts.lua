-- "Quest complete" alert, from the quest log.
local _, ns = ...

local A = {}
ns.Alerts = A

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

local known      -- nil until the first scan, so logging in doesn't alert
local announced = {} -- questID -> true: each quest is announced once per session

function A.OnQuestLog()
  if not ns.settings.alerts then known = completed() return end
  local now = completed()
  if known then
    for id, title in pairs(now) do
      -- The log can flicker while it updates (complete -> not -> complete);
      -- announcing once per quest keeps that from repeating the warning.
      if not known[id] and not announced[id] then
        announced[id] = true
        announce("Quest complete: " .. title)
      end
    end
  end
  known = now
end
