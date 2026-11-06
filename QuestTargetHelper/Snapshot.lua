-- The only place that asks the game about mobs. Builds the plain snapshots
-- Rules.lua decides on; any value Forever hides (secret) becomes nil, never a
-- guess. See Rules.lua for the fields.
local _, ns = ...
local Tracker, Frames, Quest = ns.Tracker, ns.Frames, ns.Quest

local S = {}
ns.Snapshot = S

local function plain(v) return v ~= nil and not ns.IsSecret(v) end
local function bool(v) if plain(v) and type(v) == "boolean" then return v end return nil end
local function num(v) if plain(v) and type(v) == "number" then return v end return nil end

-- Dungeons and raids: Forever gives addons no nameplates there and hides
-- names, tooltips and GUIDs, so QuestTargetHelper stays off (a stated limit).
function S.InInstance()
  local inInstance, kind = IsInInstance()
  return inInstance == true and (kind == "party" or kind == "raid" or kind == "scenario")
end

-- Us, our pet, and our group with their pets.
function S.Side()
  local units = { "player", "pet" }
  if IsInRaid and IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      units[#units + 1] = "raid" .. i
      units[#units + 1] = "raidpet" .. i
    end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do
      units[#units + 1] = "party" .. i
      units[#units + 1] = "partypet" .. i
    end
  end
  return units
end

-- Is anyone on our side in combat? (InCombatLockdown covers us.)
local function sideInCombat(side)
  if InCombatLockdown() then return true end
  for _, u in ipairs(side) do
    if bool(UnitAffectingCombat(u)) == true then return true end
  end
  return false
end

-- Mobs seen fighting our side this fight (Rules.UpdateOurs keeps it).
S.ours = {}

function S.Context(side)
  return { sideInCombat = sideInCombat(side), targetGuid = Tracker.GuidFor("target"), ours = S.ours }
end

function S.ForUnit(unit, now, side)
  local guid, e = Quest.ForUnit(unit, now)
  if not guid then return nil end
  local s = { unit = unit, guid = guid, name = e.name, entry = e, rem = Tracker.Remaining(guid, now) }
  s.attackable = bool(UnitCanAttack("player", unit))
  s.dead = bool(UnitIsDead(unit))
  if UnitIsTapDenied then s.tapDenied = bool(UnitIsTapDenied(unit)) end -- (no `and/or`: false must stay false)
  s.inCombat = bool(UnitAffectingCombat(unit))
  local mobTarget = unit .. "target"
  for _, u in ipairs(side) do
    local status = num(UnitThreatSituation and UnitThreatSituation(u, unit))
    if status and (s.threatStatus == nil or status > s.threatStatus) then s.threatStatus = status end
    if bool(UnitIsUnit(mobTarget, u)) == true then s.targetsSide = true end
  end
  if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
    s.related = bool(C_QuestLog.UnitIsRelatedToActiveQuest(unit))
  end
  -- Plates are restricted regions on Forever: measuring one can throw
  -- ("Can't measure restricted regions"), so never let it break a snapshot.
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  local ok, bottom = false, nil
  if plate then ok, bottom = pcall(plate.GetBottom, plate) end
  s.y = ok and num(bottom) or 0
  return s
end

-- Every mob on a nameplate, in a stable order (by unit token).
function S.All(now)
  local side = S.Side()
  local units = {}
  for unit in pairs(Frames.plates) do units[#units + 1] = unit end
  table.sort(units)
  local snaps = {}
  for _, unit in ipairs(units) do
    local s = S.ForUnit(unit, now, side)
    if s then snaps[#snaps + 1] = s end
  end
  local ctx = S.Context(side)
  S.ours = ns.Rules.UpdateOurs(S.ours, snaps, ctx)
  ctx.ours = S.ours
  return snaps, ctx
end
