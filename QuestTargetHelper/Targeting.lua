-- "Target next quest mob" keybind. Forever blocks addons from targeting or
-- marking on their own, and a secure button can't be changed in combat. So:
--  * Out of combat, Lua picks the single best mob and points the button at its
--    nameplate: "/target nameplate7" + "/tm !8". Exact, refreshed 4x/s.
--  * On PLAYER_REGEN_DISABLED (the last moment changes are allowed) the button
--    switches to a name list, "/targetexact <name>" per quest mob, best last
--    (the last line that matches wins). /targetexact moves off a current
--    target with the same name, so a press in combat goes to another mob.
local _, ns = ...
local Tracker, Frames, Quest = ns.Tracker, ns.Frames, ns.Quest

local BUTTON = "QuestTargetHelperNextButton"
BINDING_HEADER_QUESTTARGETHELPER = "QuestTargetHelper"
_G["BINDING_NAME_CLICK " .. BUTTON .. ":LeftButton"] = "Target next quest mob"

local MAX_NAMES = 12 -- keeps the macro well under the 1023-character limit
local SEEN_FOR = 30  -- seconds a quest mob's name stays on the in-combat list

local G = { nextUnit = nil }
ns.Targeting = G

local function plain(v) return v ~= nil and not ns.IsSecret(v) end
local function isTrue(v) return plain(v) and v == true end

local current, lastHint = nil, 0 -- nil until the button exists, so the first update creates it
local btn

-- Created on first use out of combat: making or changing a secure button in
-- combat is blocked (a /reload mid-fight would otherwise trip it at load).
local function button()
  if btn or InCombatLockdown() then return btn end
  btn = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", "")
  btn:RegisterForClicks("AnyUp", "AnyDown") -- the binding sends one of the two (ActionButtonUseKeyDown)
  btn:SetSize(1, 1)
  btn:SetAlpha(0)
  btn:EnableMouse(false)
  btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
  -- A press that found nothing to target says so (insecure hook, after the click).
  btn:HookScript("PostClick", function()
    if current == "" and GetTime() - lastHint > 3 then
      lastHint = GetTime()
      print("|cff55ff55QTH|r no unfinished quest mobs nearby")
    end
  end)
  return btn
end

local function setMacro(text)
  if text == current or InCombatLockdown() then return end
  local b = button()
  if not b then return end
  b:SetAttribute("macrotext", text)
  current = text
end

local function markLine()
  return ns.settings.markSkull and "\n/tm !8" or "" -- "!" = don't toggle the skull off (Forever)
end

-- Quest mobs worth pulling next, best first (rule in Rules.NextCandidates).
function G.Candidates(now)
  local snaps, ctx = ns.Snapshot.All(now)
  return ns.Rules.NextCandidates(snaps, ctx, Quest.Progress)
end

-- Out of combat: aim the button at the best plate.
function G.Refresh(now)
  if InCombatLockdown() then return end
  local best = G.Candidates(now)[1]
  G.nextUnit = best and best.unit or nil
  -- Plain "/target nameplate7": Blizzard's /target passes the text straight to
  -- TargetUnit, no conditional parsing (which misjudges [@nameplateN] here).
  setMacro(best and ("/target " .. best.unit .. markLine()) or "")
end

-- Last chance before lockdown: switch to names, so presses keep working while
-- plates come and go.
function G.EnterCombat(now)
  G.nextUnit = nil
  local names, seen = {}, {}
  local function add(name)
    if name and name ~= "?" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  for _, c in ipairs(G.Candidates(now)) do add(c.name) end
  for _, e in pairs(Quest.cache) do
    if now - e.seen < SEEN_FOR and Quest.OpenObjectives(e) > 0 then add(e.name) end
  end
  if #names == 0 then setMacro("") return end
  local macro = {}
  for i = math.min(#names, MAX_NAMES), 1, -1 do -- best last: the last match wins
    macro[#macro + 1] = "/targetexact " .. names[i]
  end
  setMacro(table.concat(macro, "\n") .. markLine())
end
