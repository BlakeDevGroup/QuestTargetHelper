-- Run from the repo root: lua tests/quest_test.lua
local Q = dofile("QuestTargetHelper/Quest.lua")

local failures = 0
local function eq(name, got, want)
  if got ~= want then
    failures = failures + 1
    print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
  end
end

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

eq("no quest lines", #Q.ParseTooltip({ { type = 2, leftText = "Wolf" } }, "Wolf"), 0)

if failures == 0 then print("all quest tests passed") else print(failures .. " failure(s)") os.exit(1) end
