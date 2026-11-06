-- Pull tracker: nearby quest mobs (clickable: left-click targets, and skulls
-- if that setting is on) with mini health bars + kill zone, and the quest
-- objectives they count for.
--
-- Clicking needs secure buttons, which can't be moved, shown, hidden or
-- re-aimed in combat, and anything that contains them can't be hidden or
-- resized either. So:
--  * the click layer is its own frame (`holder`), only touched out of combat;
--  * mob rows sit at fixed slots at the top, objectives below them;
--  * each slot is bound to a nameplate token. Display and click both read that
--    token, so what you click is what the row shows, even if the plate is
--    reused for another mob mid-fight;
--  * in combat the slot -> token mapping freezes; rows keep updating live.
local _, ns = ...
local Tracker, Frames, Overlay, Quest = ns.Tracker, ns.Frames, ns.Overlay, ns.Quest

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, ROW_H, LINE_H, MAX_ROWS, TOP = 250, 18, 15, 6, -8

ns.PANEL_MODES = { "Off", "In combat", "Quest mobs nearby", "Always" }

local P = {}
ns.Panel = P

local frame, lines, rows
local holder, clickers
local slots = {} -- slot index -> nameplate token

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
  holder:SetPoint("TOPLEFT", frame, "TOPLEFT")
  holder:SetSize(WIDTH, MAX_ROWS * ROW_H - TOP)
  holder:SetFrameStrata("MEDIUM")
  holder:SetFrameLevel(frame:GetFrameLevel() + 20)
  clickers = {}
  for i = 1, MAX_ROWS do
    local b = CreateFrame("Button", "QuestTargetHelperPanelRow" .. i, holder, "SecureActionButtonTemplate")
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", 8, TOP - (i - 1) * ROW_H)
    b:SetSize(WIDTH - 16, ROW_H)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "")
    b:RegisterForClicks("AnyUp")
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
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, TOP - (i - 1) * ROW_H)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT")
    r.name:SetWidth(100)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.bar:SetSize(100, 10)
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

-- Rows: every mob fighting us, plus quest mobs. Fighting first, then most
-- DoT damage still coming, then the rest.
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

-- Out of combat only: point slots and their click buttons at the current mobs.
local function assignSlots(now, visible, mobs)
  buildClickers()
  mobs = mobs or nearbyMobs(now)
  wipe(slots)
  for i = 1, math.min(#mobs, MAX_ROWS) do slots[i] = mobs[i].unit end
  if not clickers then return end
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
-- slots, and make them clickable even in "In combat" mode (hidden until now).
function P.EnterCombat(now)
  if not frame or ns.settings.panelMode == 1 then return end
  assignSlots(now, true)
end

-- Show one row for the mob behind `unit` right now (the token may have moved on).
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
  if clickable == false then label = label .. " |cff666666(no click)|r" end
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

  -- Objectives of the quest mobs on screen (finished ones drop out).
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

  -- Visibility. In combat the click layer can't be hidden, so while it is up
  -- the panel stays up too (otherwise clicks would land on an invisible row).
  local mobs = nearbyMobs(now)
  local want = shouldShow(s.panelMode, #shown > 0 or #mobs > 0)
  if not combat then
    assignSlots(now, want, mobs)
  elseif holder and holder:IsShown() then
    want = true
  end
  if not want then
    frame:Hide()
    return
  end

  -- Mob rows at fixed slots.
  local n = #slots
  for i = 1, n do
    local r = row(i)
    drawRow(r, slots[i], now, s, true)
    r:Show()
  end
  -- In combat, mobs that joined the fight after the slots froze still get a
  -- row; it can't be clicked until combat ends (the click layer is frozen).
  if combat then
    local inSlots = {}
    for _, u in ipairs(slots) do inSlots[u] = true end
    for _, m in ipairs(mobs) do
      if n >= MAX_ROWS + 3 then break end
      if m.fight and not inSlots[m.unit] then
        n = n + 1
        local r = row(n)
        drawRow(r, m.unit, now, s, false)
        r:Show()
      end
    end
  end
  for i = n + 1, #rows do rows[i]:Hide() end

  -- Objective lines below, grouped under their quest title.
  local y, li, lastTitle = TOP - n * ROW_H - (n > 0 and 4 or 0), 0, nil
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
    t:SetText(string.format("%s  %d/%d", o.text, o.have, o.need))
    t:Show()
    y = y - LINE_H
  end
  if #shown == 0 and n == 0 then
    li = li + 1
    local t = line(li)
    t:SetPoint("TOPLEFT", 8, y)
    t:SetText("|cff999999No quest mobs nearby|r")
    t:Show()
    y = y - LINE_H
  end
  for i = li + 1, #lines do lines[i]:Hide() end

  frame:SetHeight(-y + 6)
  frame:Show()
end
