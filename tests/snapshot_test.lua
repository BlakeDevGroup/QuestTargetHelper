-- Snapshot.lua + Quest.lua against a fake WoW API, where any call can return a
-- secret or throw like Forever does. The Rules tests prove the decisions; this
-- proves the game layer feeds them without ever crashing.
-- Run from the repo root: lua tests/run_all.lua (or lua tests/snapshot_test.lua)
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local T = H.suite("snapshot")
local eq = T.eq

-- Secret values are tables marked __secret; Safe.lua sees them via issecretvalue.
local function secret() return { __secret = true } end
_G.issecretvalue = function(v) return type(v) == "table" and v.__secret == true end

-- The fake world: unit token -> facts. Values may be secret().
local world = { lockdown = false, units = {} }
local function u(token) return world.units[token] end
local function field(token, key) local x = u(token) return x and x[key] end

_G.InCombatLockdown = function() return world.lockdown end
_G.IsInRaid = function() return false end
_G.IsInGroup = function() return false end
_G.GetNumGroupMembers = function() return 0 end
_G.UnitGUID = function(t) return field(t, "guid") end
_G.UnitName = function(t) return field(t, "name") end
_G.UnitCanAttack = function(_, t) return field(t, "canAttack") end
_G.UnitIsDead = function(t) return field(t, "dead") end
_G.UnitIsTapDenied = function(t) return field(t, "tapDenied") end
_G.UnitAffectingCombat = function(t) return field(t, "combat") end
_G.UnitThreatSituation = function(side, mob) local x = u(mob) return x and x.threat and x.threat[side] end
_G.UnitIsUnit = function(a, b)
  local mob = a:match("^(.-)target$")
  if mob and u(mob) then
    local t = u(mob).targets
    if type(t) == "table" then return t end -- secret
    return t == b
  end
  return a == b
end
_G.C_QuestLog = { UnitIsRelatedToActiveQuest = function(t) return field(t, "related") end }
_G.C_TooltipInfo = { GetUnit = function(t) local x = u(t) return x and { lines = x.tooltip or {} } end }
_G.C_NamePlate = { GetNamePlateForUnit = function(t)
  local x = u(t)
  if not x then return nil end
  return { GetBottom = function()
    if x.restricted then error("NamePlate1:GetBottom(): Action[FrameMeasurement] failed because[Can't measure restricted regions]") end
    return x.bottom
  end }
end }

-- Stand-ins for the frame/tracker modules Snapshot reads.
local frames = { plates = {} }
local dots = {}
local tracker = {
  GuidFor = function(t) local g = UnitGUID(t) if g and not issecretvalue(g) then return g end end,
  Remaining = function(guid) return dots[guid] or 0 end,
}
local ns = H.addon({ "Safe", "Rules", "Quest" }, { Frames = frames, Tracker = tracker })
ns = H.addon({ "Snapshot" }, ns)
local S, R, Q = ns.Snapshot, ns.Rules, ns.Quest

local function plate(token, facts)
  world.units[token] = facts
  frames.plates[token] = false
end
local function reset()
  world.units, world.lockdown, frames.plates, dots = {}, false, {}, {}
  world.units.player = { guid = "Player-1", name = "Me", combat = false }
  Q.cache = {}
  S.ours = {}
end

local KILL = { { type = 17, leftText = "Razormane Raid" }, { type = 8, leftText = "Razormane Raider slain: 2/8" } }

---------------------------------------------------------------------------
-- Bug: everything stopped (panel, /qth) because measuring a
-- nameplate throws on Forever: "Can't measure restricted regions".
---------------------------------------------------------------------------
reset()
plate("nameplate1", { guid = "C-1", name = "Razormane Raider", canAttack = true, dead = false,
  tapDenied = false, combat = false, tooltip = KILL, restricted = true })
local ok, snaps = pcall(S.All, 100)
eq("restricted plate: snapshot doesn't throw", ok, true)
eq("restricted plate: still listed", ok and #snaps or 0, 1)
eq("restricted plate: height unknown -> 0", ok and snaps[1] and snaps[1].y, 0)
local ctx
ok, snaps, ctx = pcall(S.All, 100)
eq("restricted plate: still a quest mob row", ok and #R.Rows(snaps, ctx, Q.Progress), 1)

---------------------------------------------------------------------------
-- Razormane Raider in a fight: quest mob, and fighting us.
---------------------------------------------------------------------------
reset()
world.lockdown = true
plate("nameplate1", { guid = "C-1", name = "Razormane Raider", canAttack = true, dead = false,
  tapDenied = false, combat = true, targets = "player", tooltip = KILL, bottom = 200 })
snaps, ctx = S.All(100)
eq("raider: quest mob", R.IsQuestMob(snaps[1], Q.Progress), true)
eq("raider: fighting us (targets us)", R.Fighting(snaps[1], ctx), true)
eq("raider: row", #R.Rows(snaps, ctx, Q.Progress), 1)
eq("raider: objective line", R.Objectives(snaps, Q.Progress)[1].text, "Razormane Raider slain")

---------------------------------------------------------------------------
-- Forever hides things in combat: secret values become nil, never errors.
---------------------------------------------------------------------------
reset()
world.lockdown = true
plate("nameplate1", { guid = "C-1", name = "Razormane Raider", canAttack = true, dead = secret(),
  tapDenied = secret(), combat = secret(), tooltip = KILL, bottom = secret(),
  threat = { player = secret() }, targets = secret(), related = secret() })
ok, snaps, ctx = pcall(S.All, 100)
eq("secret facts: no error", ok, true)
local s = ok and snaps[1] or {}
eq("secret dead -> nil", s.dead, nil)
eq("secret tapDenied -> nil", s.tapDenied, nil)
eq("secret inCombat -> nil", s.inCombat, nil)
eq("secret threat -> nil", s.threatStatus, nil)
eq("secret target compare -> nil", s.targetsSide, nil)
eq("secret plate height -> 0", s.y, 0)
eq("secret facts: quest mob still found from its tooltip", ok and R.IsQuestMob(s, Q.Progress), true)

reset()
plate("nameplate1", { guid = secret(), name = "Razormane Raider", canAttack = true, tooltip = KILL })
ok, snaps = pcall(S.All, 100)
eq("secret GUID: no error", ok, true)
eq("secret GUID: skipped (can't track it)", ok and #snaps, 0)

-- A tooltip line with a secret text is skipped, the rest still parsed.
reset()
plate("nameplate1", { guid = "C-1", name = "Razormane Raider", canAttack = true, dead = false, tapDenied = false,
  tooltip = { { type = 17, leftText = "Razormane Raid" }, { type = 8, leftText = secret() },
    { type = 8, leftText = "Razormane Raider slain: 2/8" } } })
snaps = S.All(100)
eq("secret tooltip line: rest parsed", R.OpenObjectives(snaps[1].entry, Q.Progress), 1)

---------------------------------------------------------------------------
-- Dungeons: QuestTargetHelper is off (Forever gives no nameplates there).
---------------------------------------------------------------------------
_G.IsInInstance = function() return true, "party" end
eq("in a dungeon: off", S.InInstance(), true)
_G.IsInInstance = function() return true, "raid" end
eq("in a raid: off", S.InInstance(), true)
_G.IsInInstance = function() return false, "none" end
eq("open world: on", S.InInstance(), false)
_G.IsInInstance = function() return true, "pvp" end
eq("battleground: not treated as a dungeon", S.InInstance(), false)

---------------------------------------------------------------------------
-- Fighting our pet: the mob targets "pet".
---------------------------------------------------------------------------
reset()
world.lockdown = true
plate("nameplate1", { guid = "C-1", name = "Wolf", canAttack = true, dead = false, tapDenied = secret(),
  combat = secret(), targets = "pet", tooltip = { { type = 2, leftText = "Wolf" } } })
snaps, ctx = S.All(100)
eq("mob on our pet: fighting", R.Fighting(snaps[1], ctx), true)

-- Bug: "mobs in combat out of party are shown": a stranger's fresh pull
-- (in combat, untagged, not on us) is not listed; our own pull stays listed
-- when its target goes secret.
reset()
world.lockdown = true
plate("nameplate1", { guid = "C-1", name = "Wolf", canAttack = true, dead = false, tapDenied = false,
  combat = true, targets = "player", tooltip = { { type = 2, leftText = "Wolf" } } })
plate("nameplate2", { guid = "C-2", name = "Wolf", canAttack = true, dead = false, tapDenied = false,
  combat = true, targets = "stranger", tooltip = { { type = 2, leftText = "Wolf" } } })
snaps, ctx = S.All(100)
eq("stranger's pull: not a row", #R.Rows(snaps, ctx, Q.Progress), 1)
world.units.nameplate1.targets = secret()
snaps, ctx = S.All(101)
eq("our pull, target now secret: still a row", #R.Rows(snaps, ctx, Q.Progress), 1)
world.lockdown = false
world.units.player.combat = false
snaps, ctx = S.All(102)
eq("out of combat: memory cleared", next(S.ours), nil)

return T.done()
