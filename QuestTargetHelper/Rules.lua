-- Every decision the addon makes, as pure functions over plain data. No WoW API
-- calls here, so tests/rules_test.lua can pin each rule (and each bug once
-- found) in plain Lua. Snapshot.lua is the only layer that asks the game.
--
-- A mob snapshot `s` holds plain values, nil when unknown (secret on Forever):
--   unit, guid, name, y (screen height of its plate)
--   attackable, dead, tapDenied, inCombat  booleans or nil
--   threatStatus  highest UnitThreatSituation of our side on it (0-3) or nil
--   targetsSide   true if its target is us, our pet or a group member
--   rem           DoT damage of ours still to come (number, 0 if none)
--   entry         quest entry from Quest.lua: { name, quests = { {title, objectives} }, threat }
--   related       C_QuestLog.UnitIsRelatedToActiveQuest, or nil
-- ctx: { sideInCombat = bool, targetGuid = guid or nil, ours = { [guid] = true } }
-- progress(title, objective) -> have, need   (quest log first, see Quest.Progress)
local _, ns = ...
ns = ns or {}
local R = {}
ns.Rules = R

local function default(title, o) return o.have, o.need end

-- Unfinished objectives this mob counts for (2+ = one kill, two objectives).
function R.OpenObjectives(entry, progress)
  progress = progress or default
  local n = 0
  for _, q in ipairs(entry and entry.quests or {}) do
    for _, o in ipairs(q.objectives) do
      local have, need = progress(q.title, o)
      if have < need then n = n + 1 end
    end
  end
  return n
end

-- Still matters for our quests: an unfinished objective, or a quest listed
-- without any countable objective that the game says is related. A mob whose
-- objectives we've finished still lists the quest in its tooltip; it isn't one.
function R.IsQuestMob(s, progress)
  local entry = s.entry
  if not entry then return false end
  if R.OpenObjectives(entry, progress) > 0 then return true end
  for _, q in ipairs(entry.quests) do
    if #q.objectives == 0 then return s.related == true end
  end
  return false
end

-- In combat with us, our pet or our group, not with some stranger. Several
-- signals because Forever may hide any of them in combat:
--  * our DoTs are on it;
--  * our threat share on it is above 0 (tooltip line, plain in combat);
--  * it is attacking one of us (threat status 2-3);
--  * it has one of us targeted;
--  * it passed one of those earlier this fight (ctx.ours[guid]): signals
--    flicker when a mob switches targets or a value goes secret for a tick.
-- Not "in combat and untagged": mobs fighting strangers or guards look the same.
function R.FightingNow(s)
  if (s.rem or 0) > 0 then return true end
  if s.entry and s.entry.threat then return true end
  if s.threatStatus and s.threatStatus >= 2 then return true end
  if s.targetsSide == true then return true end
  return false
end

function R.Fighting(s, ctx)
  if R.FightingNow(s) then return true end
  return ctx.sideInCombat == true and ctx.ours ~= nil and s.guid ~= nil and ctx.ours[s.guid] == true
end

-- The "ours" memory after this pass: kept and added to while our side is in
-- combat, emptied once it's out.
function R.UpdateOurs(ours, snaps, ctx)
  if not ctx.sideInCombat then return {} end
  for _, s in ipairs(snaps) do
    if s.guid and R.FightingNow(s) then ours[s.guid] = true end
  end
  return ours
end

local function alive(s) return s.attackable == true and s.dead ~= true end

-- Pull tracker rows: mobs fighting our side, plus quest mobs. Fighting first,
-- then most DoT damage still coming, then by unit token for a stable order.
function R.Rows(snaps, ctx, progress)
  local rows = {}
  for _, s in ipairs(snaps) do
    if alive(s) then
      local fight = R.Fighting(s, ctx)
      if fight or R.IsQuestMob(s, progress) then
        rows[#rows + 1] = { unit = s.unit, guid = s.guid, rem = s.rem or 0, fight = fight }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.fight ~= b.fight then return a.fight end
    if a.rem ~= b.rem then return a.rem > b.rem end
    return a.unit < b.unit
  end)
  return rows
end

-- Unfinished objectives of the attackable mobs around, in first-seen order
-- (snaps come in a stable order), with counts from `progress`.
function R.Objectives(snaps, progress)
  progress = progress or default
  local byKey, order = {}, {}
  for _, s in ipairs(snaps) do
    if s.attackable == true and s.entry then
      for _, q in ipairs(s.entry.quests) do
        for _, o in ipairs(q.objectives) do
          local key = q.title .. "\n" .. o.text
          local have, need = progress(q.title, o)
          local obj = byKey[key]
          if not obj then
            byKey[key] = { title = q.title, text = o.text, have = have, need = need }
            order[#order + 1] = key
          elseif have > obj.have then
            obj.have = have
          end
        end
      end
    end
  end
  local out = {}
  for _, key in ipairs(order) do
    local o = byKey[key]
    if o.have < o.need then out[#out + 1] = o end
  end
  return out
end

-- Is this row's mob our current target? By GUID: plain in combat, unlike some
-- unit comparisons. Unknown GUIDs never match.
function R.IsTarget(guid, targetGuid)
  return guid ~= nil and targetGuid ~= nil and guid == targetGuid
end

-- Which unit a cast went to, from the cast target's name (UNIT_SPELLCAST_SENT).
-- candidates: ordered { {unit, name, hostile} } - target, softenemy, mouseover,
-- focus, then nameplates. The first hostile one with that name wins, so the
-- hard target wins a tie between same-name mobs. nil if none matches.
function R.CastUnit(targetName, candidates)
  if type(targetName) ~= "string" or targetName == "" then return nil end
  for _, c in ipairs(candidates) do
    if c.name == targetName and c.hostile == true then return c.unit end
  end
  return nil
end

-- Is the unit on a pull-tracker row still the mob the row was given to?
-- Rows hold nameplate tokens, and a token freed by a dead mob goes to the
-- next unit with a plate (often the player who killed it).
function R.SameMob(expected, current)
  return expected ~= nil and current ~= nil and current == expected
end

-- Quests to announce as complete: in `now` (questID -> title) but not in
-- `known`, and never announced before. Marks them in `announced`. The quest
-- log can flicker complete -> not -> complete while updating; this keeps that
-- from repeating the announcement. known == nil (first scan) announces nothing.
function R.NewlyCompleted(known, now, announced)
  local out = {}
  if known == nil then return out end
  for id, title in pairs(now) do
    if not known[id] and not announced[id] then
      announced[id] = true
      out[#out + 1] = title
    end
  end
  table.sort(out)
  return out
end

return R
