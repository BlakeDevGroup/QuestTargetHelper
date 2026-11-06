-- Pull tracker: the quest objectives of the mobs around you, then the mobs
-- themselves (fighting you, or quest mobs) with mini health bars + kill zone.
-- Left-click a mob row to target it (and skull it if that setting is on).
--
-- Clicking needs secure buttons, which can't be moved, shown, hidden or
-- re-aimed in combat, and anything that contains them can't be hidden or
-- resized either. So:
--  * the click layer is its own frame (`holder`), only touched out of combat,
--    anchored just under the objectives;
--  * in combat the objectives section keeps the height it had when the fight
--    started, so the rows (and the click spots over them) don't move;
--  * each clickable row is bound to a nameplate token; display and click both
--    read that token, so what you click is what the row shows;
--  * mobs that show up mid-fight get display-only rows below ("no click").
local _, ns = ...
local Tracker, Frames, Overlay, Quest = ns.Tracker, ns.Frames, ns.Overlay, ns.Quest

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, ROW_H, LINE_H, PAD = 250, 18, 15, 8
local CLICK_ROWS, MAX_ROWS = 8, 14 -- clickable slots / total rows incl. mid-fight extras

ns.PANEL_MODES = { "Off", "In combat", "Quest mobs nearby", "Always" }

local P = {}
ns.Panel = P

local frame, lines, rows
local holder, clickers
local slots = {}       -- clickable slot index -> nameplate token
local objHeight = PAD  -- height of the objectives section; frozen in combat

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
  frame:SetScript("OnDragStart", function() if not InCombatLockdown() then frame:StartMoving() end end)
  frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)
  lines, rows = {}, {}
  frame:Hide()
end

-- Secure click layer. Parented to UIParent, not the panel, so the panel stays
-- an ordinary frame that may hide and resize in combat.
local function buildClickers()
  if clickers or InCombatLockdown() then return end
  holder = CreateFrame("Frame", "QuestTargetHelperPanelClicks", UIParent)
  holder:SetSize(WIDTH, CLICK_ROWS * ROW_H)
  holder:SetFrameStrata("MEDIUM")
  holder:SetFrameLevel(frame:GetFrameLevel() + 20)
  clickers = {}
  for i = 1, CLICK_ROWS do
    local b = CreateFrame("Button", "QuestTargetHelperPanelRow" .. i, holder, "SecureActionButtonTemplate")
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", PAD, -(i - 1) * ROW_H)
    b:SetSize(WIDTH - 2 * PAD, ROW_H)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "")
    -- Both: the secure template acts on down or up depending on the
    -- ActionButtonUseKeyDown setting and ignores the other.
    b:RegisterForClicks("AnyUp", "AnyDown")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    b:Hide()
    clickers[i] = b
  end
  holder:Hide()
end

local function line(i)
  local fs = lines[i]
  if not fs then
    fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(WIDTH - 2 * PAD)
    fs:SetWordWrap(false)
    lines[i] = fs
  end
  return fs
end

local function row(i)
  local r = rows[i]
  if not r then
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - 2 * PAD, ROW_H)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT")
    r.name:SetWidth(110)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.bar:SetSize(92, 10)
    r.bar:SetStatusBarTexture(WHITE)
    local back = r.bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    rows[i] = r
  end
  return r
end

local function shouldShow(mode, any)
  if mode == 4 then return true end
  if mode == 2 then return InCombatLockdown() end
  if mode == 3 then return any end
  return false
end

-- Is this mob fighting us? Our DoTs on it, the threat API (when readable), or
-- the "100% Threat" tooltip line (plain in combat).
local function fighting(unit, e, rem)
  if rem > 0 or (e and e.threat) then return true end
  local status = UnitThreatSituation and UnitThreatSituation("player", unit)
  return plain(status)
end

-- Mobs for rows: every mob fighting us, plus quest mobs. Fighting first, then
-- most DoT damage still coming, then the rest.
local function nearbyMobs(now)
  local mobs = {}
  for unit in pairs(Frames.plates) do
    if isTrue(UnitCanAttack("player", unit)) and not isTrue(UnitIsDead(unit)) then
      local guid, e = Quest.ForUnit(unit, now)
      if guid then
        local rem = Tracker.Remaining(guid, now)
        local fight = fighting(unit, e, rem)
        if fight or #e.quests > 0 then
          mobs[#mobs + 1] = { unit = unit, rem = rem, fight = fight }
        end
      end
    end
  end
  table.sort(mobs, function(a, b)
    if a.fight ~= b.fight then return a.fight end
    if a.rem ~= b.rem then return a.rem > b.rem end
    return a.unit < b.unit
  end)
  return mobs
end

-- Unfinished objectives of the quest mobs on screen, in first-seen order.
local function nearbyObjectives(now)
  local objectives, order = {}, {}
  for unit in pairs(Frames.plates) do
    if isTrue(UnitCanAttack("player", unit)) then
      local guid, e = Quest.ForUnit(unit, now)
      if guid then
        for _, q in ipairs(e.quests) do
          for _, o in ipairs(q.objectives) do
            local key = q.title .. "\n" .. o.text
            local obj = objectives[key]
            if not obj then
              objectives[key] = { title = q.title, text = o.text, have = o.have, need = o.need }
              order[#order + 1] = key
            elseif o.have > obj.have then
              obj.have = o.have
            end
          end
        end
      end
    end
  end
  local shown = {}
  for _, key in ipairs(order) do
    local o = objectives[key]
    if o.have < o.need then shown[#shown + 1] = o end
  end
  return shown
end

-- Objective text lines, quest titles in gold.
local function objectiveLines(shown)
  local out, lastTitle = {}, nil
  for _, o in ipairs(shown) do
    if o.title ~= lastTitle and o.title ~= "" then
      out[#out + 1] = { text = "|cffffd100" .. o.title .. "|r", indent = 0 }
      lastTitle = o.title
    end
    out[#out + 1] = { text = string.format("%s  %d/%d", o.text, o.have, o.need), indent = 8 }
  end
  return out
end

-- Out of combat only: aim the click layer at the current mobs, under the objectives.
local function assignSlots(mobs, visible)
  buildClickers()
  wipe(slots)
  for i = 1, math.min(#mobs, CLICK_ROWS) do slots[i] = mobs[i].unit end
  if not clickers then return end
  holder:ClearAllPoints()
  holder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -objHeight)
  local mark = ns.settings.markSkull and "\n/tm !8" or ""
  for i, b in ipairs(clickers) do
    local unit = slots[i]
    if unit and visible then
      b:SetAttribute("macrotext", "/target " .. unit .. mark)
      b:Show()
    else
      b:Hide()
    end
  end
  holder:SetShown(visible and #slots > 0)
end

-- PLAYER_REGEN_DISABLED, the last moment secure frames may change: freeze the
-- layout, and make rows clickable even in "In combat" mode (hidden until now).
function P.EnterCombat(now)
  if not frame or ns.settings.panelMode == 1 then return end
  local text = objectiveLines(nearbyObjectives(now))
  objHeight = PAD + #text * LINE_H + (#text > 0 and 4 or 0)
  assignSlots(nearbyMobs(now), true)
end

-- One row for the mob behind `unit` right now (the token may have moved on).
local function drawRow(r, unit, now, s, clickable)
  local guid = Tracker.GuidFor(unit)
  local name = nil
  if Frames.plates[unit] ~= nil then name = UnitName(unit) end
  if not guid or not plain(name) then
    r.name:SetText("|cff666666-|r")
    r.bar:Hide()
    return
  end
  local grey = isTrue(UnitIsDead(unit)) or (UnitIsTapDenied and isTrue(UnitIsTapDenied(unit)))
  local e = Quest.cache[guid]
  local questMob = e and #e.quests > 0
  local label = (grey and ("|cff888888" .. name .. "|r"))
    or (questMob and name)
    or ("|cffff9040" .. name .. "|r") -- not a quest mob, but fighting us
  if not clickable then label = label .. " |cff666666(no click)|r" end
  if ns.Targeting.nextUnit == unit then label = "|cff40ff40>|r " .. label end
  r.name:SetText(label)
  r.bar:SetMinMaxValues(0, UnitHealthMax(unit))
  r.bar:SetValue(UnitHealth(unit))
  if grey then r.bar:SetStatusBarColor(0.4, 0.4, 0.4) else r.bar:SetStatusBarColor(0.75, 0.2, 0.2) end
  Overlay.Update(r.bar, unit, s.enabled and Tracker.Remaining(guid, now) or 0)
  r.bar:Show()
end

function P.Refresh(now)
  local s = ns.settings
  if not frame then
    if s.panelMode == 1 then return end
    build()
  end
  local combat = InCombatLockdown()
  if not combat then frame:EnableMouse(not s.panelLocked) end

  local text = objectiveLines(nearbyObjectives(now))
  local mobs = nearbyMobs(now)

  -- Visibility. In combat the click layer can't be hidden, so while it is up
  -- the panel stays up too (otherwise clicks would land on an invisible row).
  local want = shouldShow(s.panelMode, #text > 0 or #mobs > 0)
  if not combat then
    objHeight = PAD + #text * LINE_H + (#text > 0 and 4 or 0)
    assignSlots(mobs, want)
  elseif holder and holder:IsShown() then
    want = true
  end
  if not want then
    frame:Hide()
    return
  end

  -- Objectives on top. In combat they keep the height they had when the fight
  -- started (lines that no longer fit are dropped) so the click spots stay put.
  local room = math.floor((objHeight - PAD) / LINE_H + 0.01)
  local nLines = combat and math.min(#text, room) or #text
  for i = 1, nLines do
    local fs = line(i)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + text[i].indent, -PAD - (i - 1) * LINE_H)
    fs:SetText(text[i].text)
    fs:Show()
  end
  for i = nLines + 1, #lines do lines[i]:Hide() end

  -- Mob rows under the objectives: clickable slots first, then (in combat) the
  -- mobs that turned up after the layout froze.
  local n = #slots
  for i = 1, n do
    local r = row(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -objHeight - (i - 1) * ROW_H)
    drawRow(r, slots[i], now, s, true)
    r:Show()
  end
  if combat then
    local inSlots = {}
    for _, u in ipairs(slots) do inSlots[u] = true end
    for _, m in ipairs(mobs) do
      if n >= MAX_ROWS then break end
      if not inSlots[m.unit] then
        n = n + 1
        local r = row(n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -objHeight - (n - 1) * ROW_H)
        drawRow(r, m.unit, now, s, false)
        r:Show()
      end
    end
  end
  for i = n + 1, #rows do rows[i]:Hide() end

  local height = objHeight + n * ROW_H + PAD
  if n == 0 and #text == 0 then
    local fs = line(1)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    fs:SetText("|cff999999No quest mobs nearby|r")
    fs:Show()
    height = PAD + LINE_H + PAD
  end
  frame:SetHeight(height)
  frame:Show()
end
