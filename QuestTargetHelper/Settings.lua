-- Options > AddOns > QuestTargetHelper.
-- Forever-specific rules (learned by SkillUpForever, UI/Settings.lua):
--  * every row goes in through Settings.RegisterInitializer; Settings.CreateCheckbox
--    and friends insert from addon code and taint the settings search.
--  * no dropdowns: Forever's native settings dropdown hits a menu assertion, so
--    choices are a stepped slider with a label.
local ADDON, ns = ...

ns.COLORS = {
  { "Purple", 0.55, 0.15, 0.85 },
  { "Red", 0.90, 0.15, 0.15 },
  { "Green", 0.20, 0.85, 0.30 },
  { "Gold", 1.00, 0.80, 0.10 },
  { "White", 1.00, 1.00, 1.00 },
}

ns.DEFAULTS = {
  enabled = true,     -- kill zone at all
  unitFrames = true,  -- target and focus frames
  plates = true,      -- nameplates
  skull = true,
  pad = 3,            -- px the zone sticks out above and below the bar
  opacity = 55,       -- percent
  color = 1,          -- index into ns.COLORS
  skullSize = 16,
  panelMode = 3,      -- index into ns.PANEL_MODES: Off / In combat / Quest mobs nearby / Always
  panelLocked = false,
  markSkull = true,   -- the keybind also puts a skull on the mob it targets
  nextMarker = true,  -- green outline on the next mob's nameplate
  doubleDip = true,   -- "x2" on mobs counting for 2+ objectives
  alerts = true,      -- quest complete / nothing left here
  alertSound = true,
  lootHint = true,    -- "Loot: press F" when the corpse in front of you has loot
  plateRange = 0,     -- nameplateMaxDistance in yards; 0 = leave the game's value
  probeRec = false,
}

local category

local function Register(key, varType, name)
  local setting = Settings.RegisterAddOnSetting(category, "QTH_" .. key, key, ns.settings,
    varType, name, ns.DEFAULTS[key])
  setting:SetValueChangedCallback(function() ns.OnSettingsChanged() end)
  return setting
end

local function Checkbox(key, name, tooltip)
  Settings.RegisterInitializer(category,
    Settings.CreateCheckboxInitializer(Register(key, Settings.VarType.Boolean, name), nil, tooltip))
end

local function Slider(key, name, minV, maxV, step, label, tooltip)
  local setting = Register(key, Settings.VarType.Number, name)
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
  Settings.RegisterInitializer(category, Settings.CreateSliderInitializer(setting, options, tooltip))
end

function ns.RegisterSettings()
  category = Settings.RegisterVerticalLayoutCategory("QuestTargetHelper")

  Checkbox("enabled", "Show the kill zone",
    "Marks the DoT damage still to come on the health bar. If the health ends inside the zone, your DoTs kill it.")
  Checkbox("unitFrames", "On target and focus frames", nil)
  Checkbox("plates", "On nameplates", "Works with Blizzard nameplates and Plater.")
  Checkbox("skull", "Show a skull when the DoTs are lethal", nil)

  Slider("pad", "Zone height beyond the bar", 0, 8, 1,
    function(v) return v .. " px" end,
    "How far the zone sticks out above and below the health bar. It never gets wider: its width lines up with the health.")
  Slider("color", "Zone color", 1, #ns.COLORS, 1,
    function(v) return ns.COLORS[v] and ns.COLORS[v][1] or "?" end, nil)
  Slider("opacity", "Zone opacity", 20, 100, 5,
    function(v) return v .. "%" end, nil)
  Slider("skullSize", "Skull size", 10, 32, 2,
    function(v) return v .. " px" end, nil)

  Slider("plateRange", "Nameplate range", 0, 60, 1,
    function(v) return v == 0 and "Game default" or (v .. " yd") end,
    "How far away nameplates appear, and with them the mobs the pull tracker and keybind can see. The game caps it; the value it accepts is printed in chat. Plater has its own setting for this, which this overrides after login.")
  Slider("panelMode", "Pull tracker panel", 1, #ns.PANEL_MODES, 1,
    function(v) return ns.PANEL_MODES[v] or "?" end,
    "Nearby quest mobs with their kill zones (click one to target it) and the objectives they count for.")
  Checkbox("panelLocked", "Lock the pull tracker",
    "Unlocked, drag it by the objectives to move it. Locked, clicks outside the mob rows go through it.")

  Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
    "Next quest mob keybind", "Bind", function()
      if Settings.KEYBINDINGS_CATEGORY_ID then Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end
      print("|cff55ff55QTH|r Key Bindings > AddOns > QuestTargetHelper > Target next quest mob")
    end, "Targets the best unfinished quest mob nearby: not tagged by someone else, not already dotted, two objectives before one.", false))
  Checkbox("markSkull", "Keybind puts a skull on the mob", nil)
  Checkbox("nextMarker", "Outline the next mob's nameplate",
    "Out of combat only: in combat the key targets by name, so there is no exact next mob to show.")
  Checkbox("doubleDip", "Show x2 on mobs that count for two objectives", nil)
  Checkbox("alerts", "Announce completed quests and \"nothing left here\"", nil)
  Checkbox("alertSound", "Play a sound with announcements", nil)

  Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
    "One-key looting", "Set up", function() ns.Loot.Setup() end,
    "Turns on Blizzard's Interact Key for whatever is in front of you, plus auto loot. Then one key loots the nearest corpse, no targeting.", false))
  Checkbox("lootHint", "Show \"Loot: press <key>\" at lootable corpses", nil)

  Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
    "Feedback and bug reports", "Open", function() ns.ShowFeedback() end, nil, false))

  Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
end
