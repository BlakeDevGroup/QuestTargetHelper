-- The kill zone: a StatusBar laid over a health bar, filled from the left by
-- the remaining DoT damage (max = the unit's max health). If the health fill
-- ends inside the zone, the DoTs kill it. Health is secret on Forever, so the
-- engine does the comparison by drawing; Lua never reads health.
--
-- The zone may stick out above and below the bar (style.pad) so it reads at a
-- glance, but never sideways: its width has to match the health bar's.
--
-- Skull (idea from DoesItDie, MIT): a 10000px-long invisible StatusBar with
-- max = current health and value = remaining damage. Its fill only reaches the
-- far end when damage >= health. A skull rides the fill's right edge and a
-- clipping window shows only the last skull-width, so it appears only when lethal.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local SKULL_BAR_LENGTH = 10000

local O = {
  version = 1,
  style = { pad = 3, r = 0.55, g = 0.15, b = 0.85, a = 0.55, skull = true, skullSize = 16 },
}
ns.Overlay = O

function O.SetStyle(style)
  O.style = style
  O.version = O.version + 1
end

local function build(bar)
  local o = CreateFrame("StatusBar", nil, bar)
  o:SetFrameLevel(bar:GetFrameLevel() + 3)
  o:SetStatusBarTexture(WHITE)

  -- Bright line at the zone's end so the edge is easy to compare with the fill.
  local edge = o:CreateTexture(nil, "OVERLAY")
  edge:SetColorTexture(1, 1, 1, 0.95)
  edge:SetWidth(2)
  edge:SetPoint("TOP", o:GetStatusBarTexture(), "TOPRIGHT")
  edge:SetPoint("BOTTOM", o:GetStatusBarTexture(), "BOTTOMRIGHT")

  local win = CreateFrame("Frame", nil, o)
  win:SetClipsChildren(true)
  win:SetPoint("LEFT", bar, "RIGHT", 3, 0)
  local sb = CreateFrame("StatusBar", nil, win)
  sb:SetPoint("RIGHT", win, "RIGHT")
  sb:SetStatusBarTexture(WHITE)
  sb:SetStatusBarColor(0, 0, 0, 0)
  local skull = sb:CreateTexture(nil, "OVERLAY")
  skull:SetTexture(SKULL)
  skull:SetPoint("RIGHT", sb:GetStatusBarTexture(), "RIGHT")

  o.win, o.skullBar, o.skull = win, sb, skull
  o:Hide()
  return o
end

local function restyle(o, bar)
  local s = O.style
  o:ClearAllPoints()
  o:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, s.pad)
  o:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -s.pad)
  o:SetStatusBarColor(s.r, s.g, s.b, s.a)
  o.win:SetSize(s.skullSize, s.skullSize)
  o.skullBar:SetSize(SKULL_BAR_LENGTH, s.skullSize)
  o.skull:SetSize(s.skullSize, s.skullSize)
  o.win:SetShown(s.skull)
  o.version = O.version
end

-- remaining = plain number from the Tracker. UnitHealth/Max are secret and go
-- straight into the StatusBars, never into Lua math.
function O.Update(bar, unit, remaining)
  local o = bar.__qthZone
  if not remaining or remaining <= 0 then
    if o then o:Hide() end
    return
  end
  if not o then
    o = build(bar)
    bar.__qthZone = o
  end
  if o.version ~= O.version then restyle(o, bar) end
  o:SetMinMaxValues(0, UnitHealthMax(unit))
  o:SetValue(remaining)
  o.skullBar:SetMinMaxValues(0, UnitHealth(unit))
  o.skullBar:SetValue(remaining)
  o:Show()
end

function O.Hide(bar)
  if bar and bar.__qthZone then bar.__qthZone:Hide() end
end
