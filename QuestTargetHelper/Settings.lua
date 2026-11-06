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

  Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
    "Feedback and bug reports", "Open", function() ns.ShowFeedback() end, nil, false))

  Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
end
