-- Phase 0 capability probe. Records what this client lets addons see so the
-- real design can be fitted to it. Output: QuestTargetHelperDB.probe (after /reload).
local _, ns = ...
local D, Try, IsSecret = ns.Describe, ns.Try, ns.IsSecret

local LOG_CAP = 25

local function db()
  QuestTargetHelperDB = QuestTargetHelperDB or {}
  QuestTargetHelperDB.probe = QuestTargetHelperDB.probe or { snapshots = {}, events = {} }
  return QuestTargetHelperDB.probe
end

local function log(kind, entry)
  local ev = db().events
  ev[kind] = ev[kind] or {}
  local list = ev[kind]
  entry.t = GetTime()
  entry.combat = InCombatLockdown()
  table.insert(list, entry)
  if #list > LOG_CAP then table.remove(list, 1) end
end

local function exists(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return false end
    cur = cur[part]
  end
  return cur ~= nil
end

local function keys(t)
  local out = {}
  if type(t) == "table" then
    for k in pairs(t) do out[#out + 1] = tostring(k) end
    table.sort(out)
  end
  return table.concat(out, ",")
end

local function mathTest(v)
  if v == nil then return "nil" end
  local ok = pcall(function() return v + 0 end)
  local okCmp = pcall(function() return v > 0 end)
  return "add=" .. tostring(ok) .. " cmp=" .. tostring(okCmp)
end

local function probeUnit(unit)
  local r = {}
  r.exists = D(Try(UnitExists, unit))
  r.name = D(Try(UnitName, unit))
  r.guid = D(Try(UnitGUID, unit))
  r.canAttack = D(Try(UnitCanAttack, "player", unit))
  r.level = D(Try(UnitLevel, unit))
  r.classification = D(Try(UnitClassification, unit))
  local h = Try(UnitHealth, unit)
  local hm = Try(UnitHealthMax, unit)
  r.health, r.healthMax = D(h), D(hm)
  r.healthMath = mathTest(type(h) == "number" and h or nil)
  if UnitHealthPercent then r.healthPercent = D(Try(UnitHealthPercent, unit)) end
  if UnitHealthMissing then r.healthMissing = D(Try(UnitHealthMissing, unit)) end
  r.isTarget = D(Try(UnitIsUnit, unit, "target"))
  if UnitIsQuestBoss then r.questBoss = D(Try(UnitIsQuestBoss, unit)) end

  -- Our own debuffs on this unit.
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    r.auras = {}
    for i = 1, 10 do
      local a = Try(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL|PLAYER")
      if type(a) == "string" then r.auras[#r.auras + 1] = a break end
      if a == nil then break end
      r.auras[#r.auras + 1] = table.concat({
        "name=" .. D(a.name), "id=" .. D(a.spellId), "dur=" .. D(a.duration),
        "exp=" .. D(a.expirationTime), "stacks=" .. D(a.applications),
        "src=" .. D(a.sourceUnit), "points=" .. D(a.points and a.points[1]),
      }, " ")
    end
  end
  return r
end

local function describeBars(frame, depth, out, prefix)
  if not frame or depth > 4 then return end
  local ok, children = pcall(function() return { frame:GetChildren() } end)
  if not ok then return end
  for _, c in ipairs(children) do
    local okT, ot = pcall(c.GetObjectType, c)
    local name = prefix .. "/" .. (D(c:GetName()) ~= "nil" and D(c:GetName()) or "?")
    if okT and ot == "StatusBar" then
      out[#out + 1] = name .. " w=" .. D(Try(c.GetWidth, c)) .. " h=" .. D(Try(c.GetHeight, c))
    end
    describeBars(c, depth + 1, out, name)
  end
end

local function probePlate(unit)
  local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and Try(C_NamePlate.GetNamePlateForUnit, unit)
  if type(plate) ~= "table" then return D(plate) end
  local r = { name = D(plate:GetName()), plateKeys = keys(plate) }
  local uf = plate.UnitFrame
  r.UnitFrame = uf and "yes" or "no"
  if uf then
    r.ufKeys = keys(uf)
    r.healthBar = uf.healthBar and "UnitFrame.healthBar" or
      (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar and "UnitFrame.HealthBarsContainer.healthBar") or "none"
  end
  r.statusBars = {}
  describeBars(plate, 1, r.statusBars, "")
  return r
end

local function probeWidgets()
  local r = {}
  local sb = CreateFrame("StatusBar")
  r.setMinMaxSecret = D(Try(sb.SetMinMaxValues, sb, 0, UnitHealthMax("target")))
  r.setValueSecret = D(Try(sb.SetValue, sb, UnitHealth("target")))
  r.getValue = D(Try(sb.GetValue, sb))
  r.SetAlphaFromBoolean = sb.SetAlphaFromBoolean and "yes" or "no"
  r.SetReverseFill = sb.SetReverseFill and "yes" or "no"
  return r
end

local function probeSpellbook()
  local out = {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return "no C_SpellBook" end
  local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if info then
      for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
        if item and item.spellID then
          out[#out + 1] = item.spellID .. " | " .. D(item.name) .. " | " ..
            D(Try(C_Spell.GetSpellDescription, item.spellID))
        end
      end
    end
  end
  return out
end

function ns.ProbeSnapshot(label)
  local snap = { label = label or "unlabeled", at = date("%H:%M:%S") }
  snap.build = table.concat({ D(select(1, GetBuildInfo())), D(select(2, GetBuildInfo())), D(select(4, GetBuildInfo())) }, " ")
  snap.project = D(WOW_PROJECT_ID)
  snap.inCombat = D(InCombatLockdown())
  snap.instance = D(select(2, IsInInstance()))
  snap.class = D(select(2, UnitClass("player")))
  snap.playerLevel = D(UnitLevel("player"))
  snap.apis = {}
  for _, api in ipairs({
    "issecretvalue", "C_Secrets", "UnitHealthPercent", "UnitHealthMissing", "C_CurveUtil",
    "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetAuraDataByAuraInstanceID",
    "C_Spell.GetSpellDescription", "C_Spell.GetSpellInfo", "GetSpellCritChance",
    "GetSpellBonusDamage", "GetComboPoints", "UnitPower", "C_NamePlate.GetNamePlates",
    "C_TooltipInfo.GetUnit", "C_QuestLog.UnitIsRelatedToActiveQuest", "UnitIsQuestBoss",
    "SetRaidTarget", "TargetUnit", "CombatLogGetCurrentEventInfo", "C_DamageMeter",
  }) do
    snap.apis[api] = exists(api)
  end
  snap.registered = ns.ProbeRegistered
  snap.secretsKeys = keys(C_Secrets)
  snap.curveKeys = keys(C_CurveUtil)
  snap.critShadow = D(Try(GetSpellCritChance, 6))
  snap.spellPowerShadow = D(Try(GetSpellBonusDamage, 6))
  snap.units = { target = probeUnit("target"), focus = probeUnit("focus") }
  snap.plates = {}
  if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    snap.plateCount = C_NamePlate.GetNamePlates and #(C_NamePlate.GetNamePlates() or {}) or "?"
    for i = 1, 40 do
      local unit = "nameplate" .. i
      local plate = Try(C_NamePlate.GetNamePlateForUnit, unit)
      if type(plate) == "table" then
        snap.plates[#snap.plates + 1] = { unit = unit, token = D(plate.namePlateUnitToken),
          info = probeUnit(unit), frame = probePlate(unit) }
        if #snap.plates >= 5 then break end
      end
    end
  end
  snap.widgets = probeWidgets()
  snap.spellbook = probeSpellbook()
  table.insert(db().snapshots, snap)
  print("|cff55ff55QuestTargetHelper|r probe '" .. snap.label .. "' saved (" .. #db().snapshots .. " total). /reload or log out to write the file.")
end

-- Event recorders: these run all session so casts and plate timing get captured.
local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
f:RegisterUnitEvent("UNIT_AURA", "target")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- UNIT_COMBAT is fine on Forever (DoesItDie ships using it). Never register
-- COMBAT_LOG_EVENT_UNFILTERED: Forever answers with ADDON_ACTION_FORBIDDEN,
-- which pcall cannot catch (Details skips it on these clients too).
local combatOk = pcall(f.RegisterUnitEvent, f, "UNIT_COMBAT", "target")

f:SetScript("OnEvent", function(_, event, ...)
  ns.SafeCall("probe:" .. event, function(...)
    local a1, a2, a3, a4, a5 = ...
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      log(event, { castGUID = D(a2), spellID = D(a3), targetGuid = D(Try(UnitGUID, "target")),
        desc = (not IsSecret(a3) and type(a3) == "number") and D(Try(C_Spell.GetSpellDescription, a3)) or "?" })
    elseif event == "UNIT_SPELLCAST_SENT" then
      log(event, { target = D(a2), castGUID = D(a3), spellID = D(a4) })
    elseif event == "UNIT_AURA" then
      local info = a2
      local added = {}
      if type(info) == "table" and type(info.addedAuras) == "table" then
        for _, a in ipairs(info.addedAuras) do
          added[#added + 1] = "name=" .. D(a.name) .. " id=" .. D(a.spellId) .. " dur=" .. D(a.duration) ..
            " src=" .. D(a.sourceUnit) .. " mine=" .. D(a.isFromPlayerOrPlayerPet)
        end
      end
      log(event, { full = type(info) == "table" and D(info.isFullUpdate) or D(info), added = added })
    elseif event == "UNIT_COMBAT" then
      log(event, { action = D(a2), flag = D(a3), amount = D(a4), school = D(a5) })
    elseif event == "NAME_PLATE_UNIT_ADDED" then
      local unit = a1
      local entry = { unit = D(unit), now = probePlate(unit) }
      log(event, entry)
      C_Timer.After(0, function()
        entry.nextFrame = probePlate(unit)
      end)
    end
  end, ...)
end)

ns.ProbeRegistered = { UNIT_COMBAT = combatOk }
