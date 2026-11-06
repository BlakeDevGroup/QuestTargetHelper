local ADDON, ns = ...
local Tracker, Frames, Overlay = ns.Tracker, ns.Frames, ns.Overlay

local DEFAULTS = { enabled = true, plates = true, skullSize = 14, probeRec = false }
local settings = DEFAULTS
local PREFIX = "|cff55ff55QTH|r "

local function say(msg) print(PREFIX .. msg) end

-- WoW only rereads a TOC's file list when the client starts, so after an
-- update that adds files a /reload runs new Core.lua without its modules.
if not (Tracker and Frames and Overlay and ns.Math and ns.Spells) then
  C_Timer.After(3, function()
    say("|cffff5555files missing: fully restart WoW (a /reload is not enough after an update that adds files).|r")
  end)
  return
end

-- Redraw every visible bar. Runs 10x/s, but only while some mob has our DoTs
-- (plus one extra pass to hide the zones after the last one ends).
local hadAny = false
local function draw(unit, bar, now, visible)
  if not bar then return end
  local guid = visible and Tracker.GuidFor(unit)
  Overlay.Update(bar, unit, guid and Tracker.Remaining(guid, now) or 0, settings.skullSize)
end

local function refresh()
  local any = next(Tracker.byGuid) ~= nil
  if not any and not hadAny then return end
  hadAny = any
  local now = GetTime()
  local on = settings.enabled
  draw("target", Frames.TargetBar(), now, on)
  draw("focus", Frames.FocusBar(), now, on)
  for unit in pairs(Frames.plates) do
    draw(unit, Frames.PlateBar(unit), now, on and settings.plates)
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, a1, a2, a3)
  ns.SafeCall(event, function()
    if event == "UNIT_SPELLCAST_SENT" then
      Tracker.OnCastSent(a3)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      Tracker.OnCastSucceeded(a2, a3)
    elseif event == "UNIT_COMBAT" then
      Tracker.OnUnitCombat(a1, a2)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
      Frames.OnPlateAdded(a1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      Frames.OnPlateRemoved(a1)
    elseif event == "ADDON_LOADED" and a1 == ADDON then
      QuestTargetHelperDB = QuestTargetHelperDB or {}
      QuestTargetHelperDB.settings = QuestTargetHelperDB.settings or {}
      settings = QuestTargetHelperDB.settings
      for k, v in pairs(DEFAULTS) do if settings[k] == nil then settings[k] = v end end
      f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
      f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
      f:RegisterUnitEvent("UNIT_COMBAT", "target")
      f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
      f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
      if settings.probeRec then ns.ProbeStartRecording() end
      C_Timer.NewTicker(0.1, function() ns.SafeCall("refresh", refresh) end)
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
    if cmd == "on" or cmd == "off" then
      settings.enabled = cmd == "on"
      hadAny = true
      say("kill zone " .. cmd)
    elseif cmd == "plates" then
      settings.plates = not settings.plates
      hadAny = true
      say("nameplates " .. (settings.plates and "on" or "off"))
    elseif cmd == "debug" then
      debugTarget()
    elseif cmd == "probe" and rest == "rec" then
      settings.probeRec = not settings.probeRec
      say("probe recording " .. (settings.probeRec and "on" or "off") .. " (takes effect after /reload)")
    elseif cmd == "probe" then
      ns.ProbeSnapshot(rest ~= "" and rest or nil)
    elseif cmd == "reset" then
      QuestTargetHelperDB.probe = nil
      say("probe data cleared")
    elseif cmd == "errors" then
      for _, e in ipairs(QuestTargetHelperDB.errors or {}) do print(e) end
    else
      say("/qth on|off  /qth plates  /qth debug  /qth probe [label|rec]  /qth reset  /qth errors")
    end
  end)
end
