-- Regression tests for every decision rule, one block per bug reported in
-- play. Mobs are built from tooltip lines shaped like Forever's (probe report
-- 2): 17 = quest title, 8 = objective, 18 = player name, 7 = threat.
-- Run from the repo root: lua tests/run_all.lua (or lua tests/rules_test.lua)
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local ns = H.addon({ "Rules", "Quest" })
local R, Q = ns.Rules, ns.Quest
local T = H.suite("rules")
local eq = T.eq

-- A fact the game hid (secret): nil in the snapshot. (`{ x = nil }` can't
-- override a default, so tests say UNKNOWN.)
local UNKNOWN = {}

-- A mob snapshot from tooltip lines plus plain facts. Defaults: an alive,
-- attackable, untagged mob out of combat that nobody is fighting.
local function mob(unit, lines, facts)
  local quests = Q.ParseTooltip(lines or {}, "Zhevra Runner", facts and facts.isMine, "Me")
  local s = { unit = unit, guid = "Creature-" .. unit, name = "Zhevra Runner", y = 0, rem = 0,
    attackable = true, dead = false, tapDenied = false, inCombat = false,
    entry = { name = "Zhevra Runner", quests = quests, threat = facts and facts.threatLine or false } }
  for k, v in pairs(facts or {}) do
    if k ~= "isMine" and k ~= "threatLine" then
      if v == UNKNOWN then s[k] = nil else s[k] = v end
    end
  end
  return s
end

local HOOVES = { { type = 17, leftText = "The Zhevra" }, { type = 8, leftText = "1/4 Zhevra Hooves" } }
local DONE = { { type = 17, leftText = "The Zhevra" }, { type = 8, leftText = "4/4 Zhevra Hooves" } }
local OUT_OF_COMBAT = { sideInCombat = false }
local IN_COMBAT = { sideInCombat = true }

local function units(rows)
  local out = {}
  for _, r in ipairs(rows) do out[#out + 1] = r.unit end
  return table.concat(out, ",")
end

---------------------------------------------------------------------------
-- Bug: "it's highlighting mobs from my teammates' quests"
---------------------------------------------------------------------------
local mineOnly = function(title) return title == "The Zhevra" end
local teammateOnly = mob("np1", {
  { type = 17, leftText = "Their Quest" }, { type = 8, leftText = "0/6 Zhevra Runner slain" },
}, { isMine = mineOnly })
eq("teammate-only quest: not a quest mob", R.IsQuestMob(teammateOnly), false)
eq("teammate-only quest: no row", units(R.Rows({ teammateOnly }, OUT_OF_COMBAT)), "")
eq("teammate-only quest: no objective line", #R.Objectives({ teammateOnly }), 0)

local sharedTheirProgress = mob("np1", {
  { type = 17, leftText = "The Zhevra" },
  { type = 18, leftText = "Teammate" }, { type = 8, leftText = "1/4 Zhevra Hooves" },
})
eq("only a teammate's progress shown: not ours", R.IsQuestMob(sharedTheirProgress), false)

---------------------------------------------------------------------------
-- Bug: "it isn't picking up quest mobs anymore" (our own progress sits under
-- a line with our own name when grouped)
---------------------------------------------------------------------------
local ownNamed = mob("np1", {
  { type = 17, leftText = "The Zhevra" },
  { type = 18, leftText = "Me" }, { type = 8, leftText = "1/4 Zhevra Hooves" },
  { type = 18, leftText = "Teammate" }, { type = 8, leftText = "4/4 Zhevra Hooves" },
})
eq("own named progress: quest mob", R.IsQuestMob(ownNamed), true)
eq("own named progress: row", units(R.Rows({ ownNamed }, OUT_OF_COMBAT)), "np1")
local objs = R.Objectives({ ownNamed })
eq("own named progress: our count, not theirs", objs[1] and objs[1].have, 1)

local solo = mob("np1", HOOVES)
eq("solo quest mob: row", units(R.Rows({ solo }, OUT_OF_COMBAT)), "np1")

---------------------------------------------------------------------------
-- Bug: "it's showing quest mobs without the quest indicator" (objective done)
---------------------------------------------------------------------------
local finished = mob("np1", DONE)
eq("finished objective: not a quest mob", R.IsQuestMob(finished), false)
eq("finished objective: no row out of combat", units(R.Rows({ finished }, OUT_OF_COMBAT)), "")
eq("finished objective: no objective line", #R.Objectives({ finished }), 0)

-- The quest log is ahead of the tooltip: finished there, so finished here.
local logDone = function(title, o) return 4, 4 end
eq("log says done: not a quest mob", R.IsQuestMob(mob("np1", HOOVES), logDone), false)

-- A quest title with no countable objective: trust the game's own check.
local titleOnly = { { type = 17, leftText = "The Zhevra" } }
eq("title only + related: quest mob", R.IsQuestMob(mob("np1", titleOnly, { related = true })), true)
eq("title only + related unknown: not", R.IsQuestMob(mob("np1", titleOnly, { related = UNKNOWN })), false)
eq("title only + not related: not", R.IsQuestMob(mob("np1", titleOnly, { related = false })), false)

---------------------------------------------------------------------------
-- Bug: "it's highlighting ANY mobs in combat" and then "it's not showing mobs
-- I'm in combat with". Must be: in combat with you, your pet or your group.
---------------------------------------------------------------------------
local plain = { { type = 2, leftText = "Wolf" } }
eq("dotted by us: fighting", R.Fighting(mob("np1", plain, { rem = 50 }), OUT_OF_COMBAT), true)
eq("our threat line > 0: fighting", R.Fighting(mob("np1", plain, { threatLine = true }), IN_COMBAT), true)
eq("attacking our pet (status 3): fighting", R.Fighting(mob("np1", plain, { threatStatus = 3 }), IN_COMBAT), true)
eq("targets a group member: fighting", R.Fighting(mob("np1", plain, { targetsSide = true }), IN_COMBAT), true)
-- Bug: "mobs in combat out of party are shown". In combat and untagged is also
-- a stranger's fresh pull, or a mob fighting a guard: not a signal.
eq("in combat, untagged, nothing points at us: not ours",
  R.Fighting(mob("np1", plain, { inCombat = true, tapDenied = false }), IN_COMBAT), false)
-- The "any mob" side:
eq("stranger's fight (tagged by them): not ours",
  R.Fighting(mob("np1", plain, { inCombat = true, tapDenied = true }), IN_COMBAT), false)
eq("in combat but we aren't: not ours",
  R.Fighting(mob("np1", plain, { inCombat = true, tapDenied = false }), OUT_OF_COMBAT), false)
eq("threat status 0 only: not ours", R.Fighting(mob("np1", plain, { threatStatus = 0 }), IN_COMBAT), false)
eq("tagged unknown (secret): not ours by that signal",
  R.Fighting(mob("np1", plain, { inCombat = true, tapDenied = UNKNOWN }), IN_COMBAT), false)
eq("in combat unknown (secret): not ours by that signal",
  R.Fighting(mob("np1", plain, { inCombat = UNKNOWN, tapDenied = false }), IN_COMBAT), false)
eq("idle wolf: not ours", R.Fighting(mob("np1", plain), IN_COMBAT), false)

-- Rows: our fights (quest or not) plus quest mobs; strangers' fights excluded.
local rows = R.Rows({
  mob("np1", HOOVES),                                            -- quest mob, idle
  mob("np2", plain, { inCombat = true, targetsSide = true }),    -- wolf fighting us
  mob("np3", plain, { inCombat = true, tapDenied = true }),      -- stranger's fight
  mob("np6", plain, { inCombat = true, tapDenied = false }),     -- stranger's fresh pull
  mob("np4", plain),                                             -- idle wolf
  mob("np5", HOOVES, { rem = 80 }),                              -- quest mob we dotted
}, IN_COMBAT)
eq("rows: fights first, most DoT damage first, then quest mobs", units(rows), "np5,np2,np1")
eq("rows: dead mobs dropped", units(R.Rows({ mob("np1", HOOVES, { dead = true }) }, OUT_OF_COMBAT)), "")
eq("rows: non-attackable dropped", units(R.Rows({ mob("np1", HOOVES, { attackable = false }) }, OUT_OF_COMBAT)), "")

-- Our fight stays ours when its signals flicker (switches to the pet, a value
-- goes secret for a tick), until our side leaves combat.
local wolf = mob("np1", plain, { inCombat = true, targetsSide = true })
local ours = R.UpdateOurs({}, { wolf }, IN_COMBAT)
local flicker = mob("np1", plain, { inCombat = true, targetsSide = UNKNOWN })
eq("sticky: remembered after one signal", ours[wolf.guid], true)
eq("sticky: still fighting when the signal goes away",
  R.Fighting(flicker, { sideInCombat = true, ours = ours }), true)
ours = R.UpdateOurs(ours, { flicker }, IN_COMBAT)
eq("sticky: kept while in combat", ours[wolf.guid], true)
ours = R.UpdateOurs(ours, { flicker }, OUT_OF_COMBAT)
eq("sticky: forgotten out of combat", ours[wolf.guid], nil)
eq("sticky: a stranger's pull is never remembered",
  R.UpdateOurs({}, { mob("np2", plain, { inCombat = true, tapDenied = false }) }, IN_COMBAT)["Creature-np2"], nil)

---------------------------------------------------------------------------
-- Bug: "the widget doesn't update when I get new items" (log beats tooltip)
---------------------------------------------------------------------------
local fromLog = function(title, o) if o.text == "Zhevra Hooves" then return 3, 4 end return o.have, o.need end
objs = R.Objectives({ mob("np1", HOOVES) }, fromLog)
eq("objective count from the quest log", objs[1] and objs[1].have, 3)
objs = R.Objectives({ mob("np1", HOOVES), mob("np2", { { type = 17, leftText = "The Zhevra" },
  { type = 8, leftText = "2/4 Zhevra Hooves" } }) })
eq("same objective on two mobs: one line, highest count", #objs, 1)
eq("same objective on two mobs: count", objs[1] and objs[1].have, 2)

---------------------------------------------------------------------------
-- Bug: "when I'm not targeting the mob directly the damage doesn't add"
---------------------------------------------------------------------------
local cands = {
  { unit = "target", name = "Kolkar", hostile = true },
  { unit = "softenemy", name = "Zhevra Runner", hostile = true },
  { unit = "mouseover", name = "Zhevra Runner", hostile = true },
}
eq("cast at soft target credited there", R.CastUnit("Zhevra Runner", cands), "softenemy")
eq("tie: hard target wins", R.CastUnit("Kolkar", cands), "target")
-- Bug: a group member's DoT replaced ours on the mob, but the zone kept ours.
eq("group cast: party member", R.IsGroupCaster("party2", false), true)
eq("group cast: raid member", R.IsGroupCaster("raid17", false), true)
eq("group cast: our own raid token is not a teammate", R.IsGroupCaster("raid3", true), false)
eq("group cast: a mob's cast is not a teammate", R.IsGroupCaster("nameplate4", false), false)
eq("group cast: party pets don't count", R.IsGroupCaster("partypet1", false), false)
eq("group cast: target is not a teammate", R.IsGroupCaster("target", false), false)
eq("non-hostile skipped", R.CastUnit("Guard", { { unit = "target", name = "Guard", hostile = false } }), nil)
eq("no name: no unit", R.CastUnit(nil, cands), nil)

---------------------------------------------------------------------------
-- Current-target highlight
---------------------------------------------------------------------------
eq("our target: highlighted", R.IsTarget("Creature-np1", "Creature-np1"), true)
eq("another mob: not highlighted", R.IsTarget("Creature-np2", "Creature-np1"), false)
eq("no target: nothing highlighted", R.IsTarget("Creature-np1", nil), false)
eq("unknown GUID: never highlighted", R.IsTarget(nil, nil), false)

---------------------------------------------------------------------------
-- Bug: repeated "Quest complete" raid warnings (log flicker)
---------------------------------------------------------------------------
local announced = {}
eq("first scan announces nothing", #R.NewlyCompleted(nil, { [1] = "A" }, announced), 0)
eq("new completion announced", R.NewlyCompleted({}, { [1] = "A" }, announced)[1], "A")
eq("flicker: gone from the log", #R.NewlyCompleted({ [1] = "A" }, {}, announced), 0)
eq("flicker: back again, not re-announced", #R.NewlyCompleted({}, { [1] = "A" }, announced), 0)
eq("a different quest still announced", R.NewlyCompleted({ [1] = "A" }, { [1] = "A", [2] = "B" }, announced)[1], "B")

return T.done()
