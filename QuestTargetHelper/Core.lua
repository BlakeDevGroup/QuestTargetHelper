local ADDON, ns = ...
local Tracker, Frames, Overlay = ns.Tracker, ns.Frames, ns.Overlay

local PREFIX = "|cff55ff55QTH|r "
local function say(msg) print(PREFIX .. msg) end

-- WoW only rereads a TOC's file list when the client starts, so after an
-- update that adds files a /reload runs new Core.lua without its modules.
if not (Tracker and Frames and Overlay and ns.Math and ns.Spells and ns.RegisterSettings and ns.ShowFeedback and ns.Panel and ns.Quest and ns.Targeting and ns.Markers and ns.Alerts and ns.Loot) then
  C_Timer.After(3, function()
    say("|cffff5555files missing: fully restart WoW (a /reload is not enough after an update that adds files).|r")
  end)
  return
end

ns.settings = ns.DEFAULTS

-- Redraw every visible bar. Runs 10x/s, but only while some mob has our DoTs
-- (plus one extra pass to hide the zones after the last one ends).
local hadAny = false
local function draw(unit, bar, now, visible)
  if not bar then return end
  local guid = visible and Tracker.GuidFor(unit)
  Overlay.Update(bar, unit, guid and Tracker.Remaining(guid, now) or 0)
end

local function refresh()
  local any = next(Tracker.byGuid) ~= nil
  if not any and not hadAny then return end
  hadAny = any
  local s, now = ns.settings, GetTime()
  local frames = s.enabled and s.unitFrames
  draw("target", Frames.TargetBar(), now, frames)
  draw("focus", Frames.FocusBar(), now, frames)
  for unit in pairs(Frames.plates) do
    draw(unit, Frames.PlateBar(unit), now, s.enabled and s.plates)
  end
end

-- Nameplate range (CVar nameplateMaxDistance). Out of combat only; says what
-- the game actually accepted, since it caps the value.
local lastRange
function ns.ApplyPlateRange(announce)
  local v = ns.settings.plateRange
  if not v or v <= 0 or InCombatLockdown() then return end
  SetCVar("nameplateMaxDistance", v)
  local got = tonumber(GetCVar("nameplateMaxDistance"))
  if announce and got ~= lastRange then say("nameplate range " .. tostring(got) .. " yd") end
  lastRange = got
end

function ns.OnSettingsChanged()
  local s = ns.settings
  ns.ApplyPlateRange(true)
  local c = ns.COLORS[s.color] or ns.COLORS[1]
  Overlay.SetStyle({ pad = s.pad, r = c[2], g = c[3], b = c[4], a = s.opacity / 100,
    skull = s.skull, skullSize = s.skullSize })
  hadAny = true -- one pass even with no DoTs, to hide zones that were switched off
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, a1, a2, a3)
  ns.SafeCall(event, function()
    if event == "UNIT_SPELLCAST_SENT" then
      Tracker.OnCastSent(a2, a3) -- unit, targetName, castGUID
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      Tracker.OnCastSucceeded(a2, a3)
    elseif event == "UNIT_COMBAT" then
      Tracker.OnUnitCombat(a1, a2)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
      Frames.OnPlateAdded(a1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      Frames.OnPlateRemoved(a1)
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
      ns.Quest.Invalidate()
      ns.Alerts.OnQuestLog()
    elseif event == "PLAYER_ENTERING_WORLD" then
      -- After Plater has applied its own range at login.
      C_Timer.After(2, function() ns.SafeCall("range", ns.ApplyPlateRange, false) end)
    elseif event == "PLAYER_REGEN_DISABLED" then
      ns.Targeting.EnterCombat(GetTime()) -- last moment secure buttons may change
      ns.Panel.EnterCombat(GetTime())
    elseif event == "ADDON_LOADED" and a1 == ADDON then
      QuestTargetHelperDB = QuestTargetHelperDB or {}
      QuestTargetHelperDB.settings = QuestTargetHelperDB.settings or {}
      local s = QuestTargetHelperDB.settings
      for k, v in pairs(ns.DEFAULTS) do if s[k] == nil then s[k] = v end end
      ns.settings = s
      ns.SafeCall("settings", ns.RegisterSettings)
      ns.OnSettingsChanged()
      f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
      f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
      f:RegisterUnitEvent("UNIT_COMBAT", "target")
      f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
      f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
      f:RegisterEvent("QUEST_LOG_UPDATE")
      f:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")
      f:RegisterEvent("PLAYER_REGEN_DISABLED")
      f:RegisterEvent("PLAYER_ENTERING_WORLD")
      if s.probeRec then ns.ProbeStartRecording() end
      C_Timer.NewTicker(0.1, function() ns.SafeCall("refresh", refresh) end)
      -- Quest-side work at 4x/s: pick the next mob first so the panel and markers show it.
      C_Timer.NewTicker(0.25, function()
        local now = GetTime()
        ns.SafeCall("targeting", ns.Targeting.Refresh, now)
        ns.SafeCall("panel", ns.Panel.Refresh, now)
        ns.SafeCall("markers", ns.Markers.Update, now)
        ns.SafeCall("loot", ns.Loot.Update)
      end)
    end
  end)
end)

local function debugTarget()
  local guid = Tracker.GuidFor("target")
  local mob = guid and Tracker.byGuid[guid]
  if not mob then say("no tracked DoTs on target") return end
  local now = GetTime()
  for name, e in pairs(mob) do
    say(string.format("%s: %d left of %d (%d ticks of %ss, %.1fs in)", name,
      ns.Math.Remaining(e, now), e.total, e.ticks, e.tick, now - e.start))
  end
end

SLASH_QUESTTARGETHELPER1 = "/qth"
SlashCmdList.QUESTTARGETHELPER = function(msg)
  ns.SafeCall("slash", function()
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "" then
      ns.OpenSettings()
    elseif cmd == "on" or cmd == "off" then
      Settings.SetValue("QTH_enabled", cmd == "on")
      say("kill zone " .. cmd)
    elseif cmd == "loot" then
      ns.Loot.Setup()
    elseif cmd == "feedback" or cmd == "bug" then
      ns.ShowFeedback()
    elseif cmd == "debug" then
      debugTarget()
    elseif cmd == "probe" and rest == "rec" then
      ns.settings.probeRec = not ns.settings.probeRec
      say("probe recording " .. (ns.settings.probeRec and "on" or "off") .. " (takes effect after /reload)")
    elseif cmd == "probe" then
      ns.ProbeSnapshot(rest ~= "" and rest or nil)
    elseif cmd == "reset" then
      QuestTargetHelperDB.probe = nil
      say("probe data cleared")
    elseif cmd == "errors" then
      for _, e in ipairs(QuestTargetHelperDB.errors or {}) do print(e) end
    else
      say("/qth (settings)  /qth on|off  /qth feedback  /qth debug  /qth errors")
    end
  end)
end
