-- Source checks for Forever rules we've already been bitten by. Each one
-- failed in play without a Lua error, so only reading the source catches it.
-- Run from the repo root: lua tests/run_all.lua (or lua tests/lint_test.lua)
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local T = H.suite("lint")
local eq = T.eq

-- Every Lua file the TOC loads (and each one must exist).
local FILES = {}
for line in assert(io.open("QuestTargetHelper/QuestTargetHelper.toc", "r")):lines() do
  local name = line:match("^([%w_]+)%.lua%s*$")
  if name then FILES[#FILES + 1] = name end
end

local function source(name)
  local f = assert(io.open("QuestTargetHelper/" .. name .. ".lua", "r"))
  local text = f:read("*a")
  f:close()
  -- Drop comments so explanations of a rule don't trip it.
  text = text:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  return text
end

local function offenders(pattern)
  local hits = {}
  for _, name in ipairs(FILES) do
    local text = source(name)
    local n = 0
    for line in text:gmatch("[^\n]+") do
      n = n + 1
      if line:find(pattern) then hits[#hits + 1] = name .. ".lua: " .. line:gsub("^%s+", "") end
    end
  end
  return table.concat(hits, " | ")
end

-- Bug: the panel wouldn't show or grow in combat. Its click layer (secure
-- buttons) was anchored to it, which makes the panel protected; Show/Hide/
-- SetHeight on it are then blocked in combat, silently.
eq("click layer never anchored to the panel", offenders("holder:SetPoint%([^)]*frame"), "")
eq("secure buttons never parented to the panel",
  offenders('CreateFrame%("Button",[^)]*, *frame, *"SecureActionButtonTemplate"'), "")

-- Bug: everything errored. Measuring a nameplate throws ("Can't measure
-- restricted regions"); only pcall(plate.GetBottom, plate) is allowed.
for _, m in ipairs({ "Bottom", "Top", "Left", "Right", "Center", "Width", "Height", "Rect", "Size" }) do
  eq("no direct nameplate measuring: Get" .. m, offenders("plate:Get" .. m .. "%("), "")
end

-- Bug: row clicks did nothing. A visibility state driver with
-- [@nameplateN,exists,nodead] evaluates false on Forever for live mobs, so
-- every click spot hid itself.
eq("no state drivers on click spots", offenders("RegisterStateDriver%("), "")

-- Bug: clicks reached the row but didn't target, twice. Blizzard's secure
-- click code aborts when the button's "unit" fails UnitExists(), which
-- nameplate units do on Forever; [@nameplateN] conditionals fail the same
-- way. Only plain "/target nameplateN" macros with no unit attribute work.
eq("no [@nameplate...] conditionals built in code", offenders('%[@" %.%. '), "")
eq("no unit attribute on click buttons", offenders('SetAttribute%("unit'), "")
-- Then: "/target nameplate1" ran but cleared the target. Nameplate tokens
-- can't be targeted at all on Forever; only names can.
eq("never target a nameplate token", offenders('"/target " %.%. [%w%.]*unit'), "")
eq("rows target by name", (source("Panel"):find('"/targetexact " %.%. name') ~= nil), true)

-- The keybind and looting were removed: nothing may still point at them.
eq("no Targeting or Loot module left", offenders("ns%.Targeting") .. offenders("ns%.Loot"), "")
eq("TOC lists the core files", #FILES >= 16, true)

-- Bug: only the name part of a row took clicks; the kill-zone frames over the
-- bar were in the way. Display frames ignore the mouse, the click layer is HIGH.
local _, mouseOff = source("Overlay"):gsub("EnableMouse%(false%)", "")
eq("overlay frames (zone, skull window, skull bar) ignore the mouse", mouseOff, 3)
eq("click layer above the panel", (source("Panel"):find('holder:SetFrameStrata%("HIGH"%)') ~= nil), true)

-- Bug: "sometimes when I drag the position resets". The 4x/s refresh re-anchored
-- the panel mid-drag, snapping it back to the saved spot.
eq("panel never re-anchored mid-drag", (source("Panel"):find("InCombatLockdown%(%) or dragging then return") ~= nil), true)

-- Bug: a player's name showed on a row. Rows and the hover outline must check
-- the mob's GUID, never trust a nameplate token alone.
eq("rows check the slot still holds its mob", (source("Panel"):find("Rules%.SameMob%(expect, guid%)") ~= nil), true)
eq("hover outline follows the GUID", offenders("hoverUnit"), "")

-- Bug: an ADDON_ACTION_FORBIDDEN popup pcall can't catch.
eq("combat log never registered", offenders("COMBAT_LOG_EVENT_UNFILTERED"), "")

-- Bug: a secret GUID used as a table key throws; Markers once did this.
eq("no table index with a raw UnitGUID call", offenders("%[%s*UnitGUID%("), "")

return T.done()
