-- One-key looting. Addons can't interact with a corpse (and no macro command
-- does it); Blizzard's Interact Key can: with SoftTargetInteract = 3 it acts on
-- the nearest corpse/NPC/object in front of you, no targeting needed. This
-- turns that on, says which key it is, and shows "Loot: press F" when the
-- corpse in front of you has loot.
local _, ns = ...

local L = {}
ns.Loot = L

local BINDING = "INTERACTTARGET"

local function plain(v) return v ~= nil and not ns.IsSecret(v) end

function L.Key()
  local key = GetBindingKey and GetBindingKey(BINDING)
  return plain(key) and key or nil
end

function L.Setup()
  if InCombatLockdown() then
    print("|cff55ff55QTH|r leave combat first, then try again")
    return
  end
  SetCVar("SoftTargetInteract", "3") -- interact with what's in front of you, untargeted
  SetCVar("autoLootDefault", "1")
  local key = L.Key()
  if key then
    print("|cff55ff55QTH|r one-key looting on: walk up to a corpse and press |cffffd100" ..
      GetBindingText(key) .. "|r")
  else
    print("|cff55ff55QTH|r one-key looting on. Now bind |cffffd100Interact With Target|r " ..
      "(Key Bindings > Targeting), then press it at a corpse.")
    if Settings and Settings.KEYBINDINGS_CATEGORY_ID then Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end
  end
end

-- The prompt: a line of text above the action bars.
local hint = CreateFrame("Frame", nil, UIParent)
hint:SetSize(300, 24)
hint:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
hint:Hide()
local text = hint:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER")

function L.Update()
  if not ns.settings.lootHint then hint:Hide() return end
  local dead = UnitIsDead("softinteract")
  local guid = UnitGUID("softinteract")
  if not (plain(dead) and dead == true and plain(guid)) then hint:Hide() return end
  local hasLoot = CanLootUnit and CanLootUnit(guid)
  if not (plain(hasLoot) and hasLoot == true) then hint:Hide() return end
  local key = L.Key()
  text:SetText(key and ("Loot: press |cffffffff" .. GetBindingText(key) .. "|r")
    or "Loot here: bind Interact With Target (/qth)")
  hint:Show()
end
