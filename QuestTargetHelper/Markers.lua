-- Nameplate markers, display only:
--  * a gold outline on the mob whose pull-tracker row is hovered;
--  * "x2" (x3...) on mobs that count for two or more unfinished objectives.
local _, ns = ...
local Frames, Quest = ns.Frames, ns.Quest

local M = {}
ns.Markers = M

local marked = {} -- bar -> true for bars carrying our markers this pass

local function build(bar)
  local m = CreateFrame("Frame", nil, bar)
  m:SetAllPoints(bar)
  m:SetFrameLevel(bar:GetFrameLevel() + 5)
  local edges = {}
  for i, spec in ipairs({
    { "TOPLEFT", "TOPRIGHT", 0, 2, true }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, -2, true },
    { "TOPLEFT", "BOTTOMLEFT", -2, 0, false }, { "TOPRIGHT", "BOTTOMRIGHT", 2, 0, false },
  }) do
    local t = m:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 0.82, 0, 1)
    t:SetPoint(spec[1], bar, spec[1], spec[3], spec[4])
    t:SetPoint(spec[2], bar, spec[2], spec[3], spec[4])
    if spec[5] then t:SetHeight(2) else t:SetWidth(2) end
    edges[i] = t
  end
  m.edges = edges
  m.count = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.count:SetPoint("RIGHT", bar, "LEFT", -3, 0)
  m.count:SetTextColor(1, 0.82, 0)
  bar.__qthMarks = m
  return m
end

local function show(bar, open, hovered)
  local m = bar.__qthMarks or build(bar)
  for _, t in ipairs(m.edges) do t:SetShown(hovered) end
  m.count:SetText(open >= 2 and ("x" .. open) or "")
  m:Show()
  marked[bar] = true
end

-- GUID of the mob whose pull-tracker row is under the mouse (Panel sets it).
M.hoverGuid = nil

function M.Update(now)
  local s = ns.settings
  local still = {}
  for unit in pairs(Frames.plates) do
    local bar = Frames.PlateBar(unit)
    if bar then
      local guid = UnitGUID(unit)
      if guid ~= nil and ns.IsSecret(guid) then guid = nil end -- never compare or index with a secret
      local isHovered = guid ~= nil and guid == M.hoverGuid
      local open = 0
      if s.doubleDip then
        local e = guid and Quest.cache[guid]
        if e then open = Quest.OpenObjectives(e) end
      end
      if isHovered or open >= 2 then
        show(bar, open, isHovered)
        still[bar] = true
      end
    end
  end
  for bar in pairs(marked) do
    if not still[bar] and bar.__qthMarks then bar.__qthMarks:Hide() end
  end
  marked = still
end
