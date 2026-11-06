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

local lastApplied       -- { guid, name, at } for miss detection

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

-- Where a cast is going. UNIT_SPELLCAST_SENT names the cast target (plain in
-- combat), which may not be our target: soft target, mouseover or @focus
-- macros, or no target at all. Find the unit with that name, preferring the
-- hard target when several mobs share it.
local CANDIDATES = { "target", "softenemy", "mouseover", "focus" }

-- Plain facts about the candidate units, in preference order; the choice
-- itself is Rules.CastUnit (unit tested).
local function unitNamed(name)
  local list = {}
  local function add(unit)
    local n, hostile = UnitName(unit), UnitCanAttack("player", unit)
    list[#list + 1] = { unit = unit, name = plain(n) and n or nil,
      hostile = plain(hostile) and hostile == true }
  end
  for _, unit in ipairs(CANDIDATES) do add(unit) end
  local plates = {}
  for unit in pairs(ns.Frames.plates) do plates[#plates + 1] = unit end
  table.sort(plates)
  for _, unit in ipairs(plates) do add(unit) end
  return ns.Rules.CastUnit(name, list)
end

local pending = {}  -- castGUID -> { guid, cp } captured when the cast started
local pendingCount = 0

function T.OnCastSent(targetName, castGUID)
  if not plain(castGUID) then return end
  local unit = "target"
  if plain(targetName) and targetName ~= "" then unit = unitNamed(targetName) or "target" end
  local cp = GetComboPoints and GetComboPoints("player", unit)
  if pendingCount > 50 then pending, pendingCount = {}, 0 end -- casts that never succeeded
  pending[castGUID] = { guid = T.GuidFor(unit), cp = plain(cp) and cp or nil }
  pendingCount = pendingCount + 1
end

function T.OnCastSucceeded(castGUID, spellID)
  if not plain(spellID) then return end
  local name = spellName(spellID)
  if not plain(name) then return end
  local def = ns.Spells[name]
  if not def then return end
  local sent = plain(castGUID) and pending[castGUID]
  if sent then pending[castGUID] = nil; pendingCount = pendingCount - 1 end
  local guid = (sent and sent.guid) or T.GuidFor("target")
  if not guid then return end

  local desc = C_Spell.GetSpellDescription(spellID)
  if not plain(desc) or desc == "" then
    C_Spell.RequestLoadSpellData(spellID)
    return
  end
  local cp = sent and sent.cp
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
