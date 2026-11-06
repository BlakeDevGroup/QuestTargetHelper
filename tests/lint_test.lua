-- Source checks for Forever rules we've already been bitten by. Each one
-- failed in play without a Lua error, so only reading the source catches it.
-- Run from the repo root: lua tests/run_all.lua (or lua tests/lint_test.lua)
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local T = H.suite("lint")
local eq = T.eq

local FILES = { "Safe", "Math", "Rules", "Spells", "Tracker", "Overlay", "Frames", "Quest", "Snapshot",
  "Targeting", "Markers", "Alerts", "Loot", "Panel", "Settings", "Feedback", "Probe", "Core" }

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

-- Bug: an ADDON_ACTION_FORBIDDEN popup pcall can't catch.
eq("combat log never registered", offenders("COMBAT_LOG_EVENT_UNFILTERED"), "")

-- Bug: a secret GUID used as a table key throws; Markers once did this.
eq("no table index with a raw UnitGUID call", offenders("%[%s*UnitGUID%("), "")

return T.done()
