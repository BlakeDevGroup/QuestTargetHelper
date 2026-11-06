-- Pull tracker: quest objectives with "kills in flight" (quest mobs carrying
-- our DoTs), and the nearby quest mobs with mini health bars + kill zone.
-- Display only, so it may update freely in combat. Health stays secret: the
-- row bars take UnitHealth straight into SetValue, like the kill zone.
local _, ns = ...
local Tracker, Frames, Overlay, Quest = ns.Tracker, ns.Frames, ns.Overlay, ns.Quest

local WHITE = "Interface\\Buttons\\WHITE8X8"
local READY = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local WIDTH, ROW_H, LINE_H, MAX_ROWS = 250, 18, 15, 6

ns.PANEL_MODES = { "Off", "In combat", "Quest mobs nearby", "Always" }

local P = {}
ns.Panel = P

local frame, lines, rows

local function plain(v) return v ~= nil and not ns.IsSecret(v) end
local function isTrue(v) return plain(v) and v == true end

local function savePosition()
  local point, _, relPoint, x, y = frame:GetPoint()
  QuestTargetHelperDB.panelPos = { point, relPoint, x, y }
end

local function build()
  frame = CreateFrame("Frame", "QuestTargetHelperPanel", UIParent)
  frame:SetSize(WIDTH, 40)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  local pos = QuestTargetHelperDB.panelPos
  if pos then
    frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 360, 40)
  end
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)

  lines, rows = {}, {}
  frame:Hide()
end

local function line(i)
  local fs = lines[i]
  if not fs then
    fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(WIDTH - 16)
    lines[i] = fs
  end
  return fs
end

local function row(i)
  local r = rows[i]
  if not r then
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - 16, ROW_H)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT")
    r.name:SetWidth(100)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.bar:SetSize(100, 10)
    r.bar:SetStatusBarTexture(WHITE)
    r.bar:SetStatusBarColor(0.75, 0.2, 0.2)
    local back = r.bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    rows[i] = r
  end
  return r
end

local function shouldShow(mode, anyObjective)
  if mode == 4 then return true end
  if mode == 2 then return InCombatLockdown() end
  if mode == 3 then return anyObjective end
  return false
end

function P.Refresh(now)
  local s = ns.settings
  if not frame then
    if s.panelMode == 1 then return end
    build()
  end
  frame:EnableMouse(not s.panelLocked)

  -- Nearby quest mobs from the nameplates.
  local mobs, objectives, order = {}, {}, {}
  local function objectiveFor(q, o)
    local key = q.title .. "\n" .. o.text
    local obj = objectives[key]
    if not obj then
      obj = { title = q.title, text = o.text, have = o.have, need = o.need, kill = o.kill, dotted = 0 }
      objectives[key] = obj
      order[#order + 1] = key
    elseif o.have > obj.have then
      obj.have = o.have
    end
    return obj
  end

  for unit in pairs(Frames.plates) do
    if isTrue(UnitCanAttack("player", unit)) and not isTrue(UnitIsDead(unit)) then
      local guid, e = Quest.ForUnit(unit, now)
      if guid and #e.quests > 0 then
        for _, q in ipairs(e.quests) do
          for _, o in ipairs(q.objectives) do objectiveFor(q, o) end
        end
        mobs[#mobs + 1] = { unit = unit, guid = guid, name = e.name,
          rem = Tracker.Remaining(guid, now), tapped = UnitIsTapDenied ~= nil and isTrue(UnitIsTapDenied(unit)) }
      end
    end
  end

  -- Kills in flight: every dotted mob we know a quest for, on a plate or not.
  for guid in pairs(Tracker.byGuid) do
    local e = Quest.cache[guid]
    if e and Tracker.Remaining(guid, now) > 0 then
      for _, q in ipairs(e.quests) do
        for _, o in ipairs(q.objectives) do
          local obj = objectiveFor(q, o)
          obj.dotted = obj.dotted + 1
        end
      end
    end
  end
  Quest.Prune(now, Tracker.byGuid)

  -- Finished objectives drop out.
  local shown = {}
  for _, key in ipairs(order) do
    local o = objectives[key]
    if o.have < o.need then shown[#shown + 1] = o end
  end

  if not shouldShow(s.panelMode, #shown > 0) then
    frame:Hide()
    return
  end

  -- Objective lines, grouped under their quest title.
  local y, li, lastTitle = -8, 0, nil
  for _, o in ipairs(shown) do
    if o.title ~= lastTitle and o.title ~= "" then
      li = li + 1
      local t = line(li)
      t:SetPoint("TOPLEFT", 8, y)
      t:SetText("|cffffd100" .. o.title .. "|r")
      t:Show()
      y, lastTitle = y - LINE_H, o.title
    end
    li = li + 1
    local t = line(li)
    t:SetPoint("TOPLEFT", 16, y)
    local text = string.format("%s  %d/%d", o.text, o.have, o.need)
    if o.dotted > 0 then
      local enough = o.kill and o.have + o.dotted >= o.need
      text = text .. string.format("  |cff%s+%d dotted|r", enough and "40ff40" or "ffff40", o.dotted)
      if enough then text = text .. " " .. READY end
    end
    t:SetText(text)
    t:Show()
    y = y - LINE_H
  end
  if #shown == 0 then
    li = li + 1
    local t = line(li)
    t:SetPoint("TOPLEFT", 8, y)
    t:SetText("|cff999999No quest mobs nearby|r")
    t:Show()
    y = y - LINE_H
  end
  for i = li + 1, #lines do lines[i]:Hide() end

  -- Mob rows: dotted first (most damage still coming), then the rest.
  table.sort(mobs, function(a, b)
    if (a.rem > 0) ~= (b.rem > 0) then return a.rem > 0 end
    if a.rem ~= b.rem then return a.rem > b.rem end
    return a.unit < b.unit
  end)
  y = y - 4
  local n = math.min(#mobs, MAX_ROWS)
  for i = 1, n do
    local m, r = mobs[i], row(i)
    r:SetPoint("TOPLEFT", 8, y)
    r.name:SetText(m.tapped and ("|cff888888" .. m.name .. "|r") or m.name)
    r.bar:SetMinMaxValues(0, UnitHealthMax(m.unit))
    r.bar:SetValue(UnitHealth(m.unit))
    r.bar:SetStatusBarColor(m.tapped and 0.4 or 0.75, m.tapped and 0.4 or 0.2, m.tapped and 0.4 or 0.2)
    Overlay.Update(r.bar, m.unit, s.enabled and m.rem or 0)
    r:Show()
    y = y - ROW_H
  end
  for i = n + 1, #rows do rows[i]:Hide() end

  frame:SetHeight(-y + 6)
  frame:Show()
end
