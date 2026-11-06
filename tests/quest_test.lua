-- Run from the repo root: lua tests/run_all.lua (or lua tests/quest_test.lua)
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local ns = H.addon({ "Rules", "Quest" })
local Q = ns.Quest
local T = H.suite("quest")
local eq = T.eq

-- Lines as Forever's unit tooltip gave them (probe report 2).
local o = Q.ParseObjective("0/4 Zhevra Hooves", "Zhevra Runner")
eq("loot text", o.text, "Zhevra Hooves"); eq("loot have", o.have, 0); eq("loot need", o.need, 4)
eq("loot is not a kill", o.kill, false)

o = Q.ParseObjective("Zhevra Runner slain: 1/8", "Zhevra Runner")
eq("slain text", o.text, "Zhevra Runner slain"); eq("slain have", o.have, 1); eq("slain need", o.need, 8)
eq("slain is a kill", o.kill, true)

o = Q.ParseObjective("- Kolkar Bloodcharger: 3/10", "Kolkar Bloodcharger")
eq("mob-name objective is a kill", o.kill, true); eq("dash stripped", o.text, "Kolkar Bloodcharger")

eq("no counter", Q.ParseObjective("The Zhevra", nil), nil)
eq("not a string", Q.ParseObjective(nil, nil), nil)

local quests = Q.ParseTooltip({
  { type = 2, leftText = "Zhevra Runner" },
  { type = 0, leftText = "Level 14" },
  { type = 17, leftText = "The Zhevra" },
  { type = 8, leftText = "0/4 Zhevra Hooves" },
  { type = 7, leftText = "100% Threat" },
  { type = 17, leftText = "Plainstrider Menace" },
  { type = 8, leftText = "Zhevra Runner slain: 2/6" },
}, "Zhevra Runner")
eq("two quests", #quests, 2)
eq("first title", quests[1].title, "The Zhevra")
eq("first objective", quests[1].objectives[1].text, "Zhevra Hooves")
eq("second objective have", quests[2].objectives[1].have, 2)
eq("threat line ignored", #quests[1].objectives, 1)

eq("open objectives across quests", Q.OpenObjectives({ quests = quests }), 2)
eq("finished objective not open", Q.OpenObjectives({ quests = {
  { title = "A", objectives = { { have = 4, need = 4 }, { have = 1, need = 3 } } } } }), 1)

-- Grouped: a party member's progress follows a QuestPlayer (18) line.
quests = Q.ParseTooltip({
  { type = 17, leftText = "The Zhevra" },
  { type = 8, leftText = "1/4 Zhevra Hooves" },
  { type = 18, leftText = "Teammate" },
  { type = 8, leftText = "3/4 Zhevra Hooves" },
}, "Zhevra Runner")
eq("party progress ignored", #quests[1].objectives, 1)
eq("our progress kept", quests[1].objectives[1].have, 1)

-- A quest only a teammate has (not in our log) is dropped, objectives and all.
local mine = function(title) return title == "The Zhevra" end
quests = Q.ParseTooltip({
  { type = 17, leftText = "Their Quest" },
  { type = 8, leftText = "0/6 Zhevra Runner slain" },
  { type = 17, leftText = "The Zhevra" },
  { type = 8, leftText = "0/4 Zhevra Hooves" },
}, "Zhevra Runner", mine)
eq("teammate-only quest dropped", #quests, 1)
eq("our quest kept", quests[1].title, "The Zhevra")

-- Grouped, our own progress is under a QuestPlayer line with our name.
quests = Q.ParseTooltip({
  { type = 17, leftText = "The Zhevra" },
  { type = 18, leftText = "Me" },
  { type = 8, leftText = "1/4 Zhevra Hooves" },
  { type = 18, leftText = "Teammate" },
  { type = 8, leftText = "3/4 Zhevra Hooves" },
}, "Zhevra Runner", nil, "Me")
eq("our named section kept", #quests, 1)
eq("our named progress", quests[1].objectives[1].have, 1)
eq("their named section skipped", #quests[1].objectives, 1)

-- Titles match the log despite colour codes, case and spacing.
eq("title key", Q.Key(" |cffffd100The Zhevra|r "), "the zhevra")

-- Only a teammate's progress on a shared title: nothing of ours left.
quests = Q.ParseTooltip({
  { type = 17, leftText = "The Zhevra" },
  { type = 18, leftText = "Teammate" },
  { type = 8, leftText = "2/4 Zhevra Hooves" },
}, "Zhevra Runner")
eq("quest with only their progress dropped", #quests, 0)

-- Quest-log progress wins over a stale tooltip count, matched on the text.
Q.progress = { ["the zhevra"] = { ["Zhevra Hooves"] = { have = 3, need = 4 } } }
local stale = Q.ParseObjective("1/4 Zhevra Hooves")
local have, need = Q.Progress("The Zhevra", stale)
eq("log have", have, 3); eq("log need", need, 4)
have = Q.Progress("Other Quest", stale)
eq("no log entry falls back to tooltip", have, 1)
Q.progress = { ["the zhevra"] = { ["Zhevra Hooves"] = { have = 4, need = 4 } } }
eq("done in the log = not open", Q.OpenObjectives({ quests = {
  { title = "The Zhevra", objectives = { stale } } } }), 0)
Q.progress = {}

eq("no quest lines", #Q.ParseTooltip({ { type = 2, leftText = "Wolf" } }, "Wolf"), 0)

return T.done()
