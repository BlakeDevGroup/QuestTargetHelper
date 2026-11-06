-- Records our DoT casts per mob (by GUID) and answers "how much DoT damage is
-- still coming". Forever hides aura data and damage amounts in combat, so this
-- works purely from cast events + the spell description at cast time.
local _, ns = ...
local IsSecret, M = ns.IsSecret, ns.Math

local T = { byGuid = {} }
ns.Tracker = T

local MISS = { MISS = true, DODGE = true, PARRY = true, RESIST = true, IMMUNE = true,
  EVADE = true, DEFLECT = true, BLOCK = true, REFLECT = true }
local MISS_WINDOW = 0.6 -- seconds after a cast in which a miss on that mob cancels it

local pendingCombo = {} -- castGUID -> combo points before the finisher spent them
local lastApplied        -- { guid, name, at } for miss detection

local function plain(v) return v ~= nil and not IsSecret(v) end

local function spellName(id)
  if C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  local info = C_Spell.GetSpellInfo(id)
  return info and info.name
end

function T.GuidFor(unit)
  local g = UnitGUID(unit)
  if plain(g) then return g end
  return nil
end

function T.OnCastSent(castGUID)
  if not plain(castGUID) then return end
  local cp = GetComboPoints and GetComboPoints("player", "target")
  if plain(cp) then pendingCombo[castGUID] = cp end
end

function T.OnCastSucceeded(castGUID, spellID)
  if not plain(spellID) then return end
  local name = spellName(spellID)
  if not plain(name) then return end
  local def = ns.Spells[name]
  if not def then return end
  local guid = T.GuidFor("target")
  if not guid then return end

  local desc = C_Spell.GetSpellDescription(spellID)
  if not plain(desc) or desc == "" then
    C_Spell.RequestLoadSpellData(spellID)
    return
  end
  local cp = plain(castGUID) and pendingCombo[castGUID]
  if plain(castGUID) then pendingCombo[castGUID] = nil end
  local total, duration, tick = M.ParseDescription(desc, def.model, cp)
  if not total or not duration or duration <= 0 then return end

  local now = GetTime()
  local mob = T.byGuid[guid] or {}
  T.byGuid[guid] = mob
  mob[name] = M.NewEntry(def, total, duration, tick, now) -- a refresh replaces it
  lastApplied = { guid = guid, name = name, at = now }
end

-- UNIT_COMBAT on the target: a miss/immune right after our cast means it never landed.
function T.OnUnitCombat(unit, action)
  if not lastApplied or not plain(action) or not MISS[action] then return end
  if GetTime() - lastApplied.at > MISS_WINDOW then return end
  if T.GuidFor(unit) ~= lastApplied.guid then return end
  local mob = T.byGuid[lastApplied.guid]
  if mob then mob[lastApplied.name] = nil end
  lastApplied = nil
end

-- Total DoT damage still to come on this mob, plus the per-spell breakdown.
function T.Remaining(guid, now)
  local mob = guid and T.byGuid[guid]
  if not mob then return 0 end
  local sum, any = 0, false
  for name, entry in pairs(mob) do
    local r = M.Remaining(entry, now)
    if r <= 0 then mob[name] = nil else sum, any = sum + r, true end
  end
  if not any then T.byGuid[guid] = nil end
  return sum
end

function T.Forget(guid)
  if guid then T.byGuid[guid] = nil end
end
