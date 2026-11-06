-- The kill zone: a StatusBar laid over a health bar, filled from the left by
-- the remaining DoT damage (max = the unit's max health). If the health fill
-- ends inside the zone, the DoTs kill it. Health is secret on Forever, so the
-- engine does the comparison by drawing; Lua never reads health.
--
-- Skull (idea from DoesItDie, MIT): a 10000px-long invisible StatusBar with
-- max = current health and value = remaining damage. Its fill only reaches the
-- far end when damage >= health. A skull rides the fill's right edge and a
-- clipping window shows only the last skull-width, so it appears only when lethal.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local SKULL_BAR_LENGTH = 10000

local O = {}
ns.Overlay = O

local function build(bar, skullSize)
  local o = CreateFrame("StatusBar", nil, bar)
  o:SetAllPoints(bar)
  o:SetFrameLevel(bar:GetFrameLevel() + 3)
  o:SetStatusBarTexture(WHITE)
  o:SetStatusBarColor(0.55, 0.15, 0.85, 0.5)

  -- Bright line at the zone's end so the edge is easy to compare with the fill.
  local edge = o:CreateTexture(nil, "OVERLAY")
  edge:SetColorTexture(1, 1, 1, 0.95)
  edge:SetWidth(2)
  edge:SetPoint("TOP", o:GetStatusBarTexture(), "TOPRIGHT")
  edge:SetPoint("BOTTOM", o:GetStatusBarTexture(), "BOTTOMRIGHT")

  local win = CreateFrame("Frame", nil, o)
  win:SetClipsChildren(true)
  win:SetSize(skullSize, skullSize)
  win:SetPoint("LEFT", bar, "RIGHT", 3, 0)
  local sb = CreateFrame("StatusBar", nil, win)
  sb:SetSize(SKULL_BAR_LENGTH, skullSize)
  sb:SetPoint("RIGHT", win, "RIGHT")
  sb:SetStatusBarTexture(WHITE)
  sb:SetStatusBarColor(0, 0, 0, 0)
  local skull = sb:CreateTexture(nil, "OVERLAY")
  skull:SetTexture(SKULL)
  skull:SetSize(skullSize, skullSize)
  skull:SetPoint("RIGHT", sb:GetStatusBarTexture(), "RIGHT")

  o.skullBar = sb
  o:Hide()
  return o
end

-- remaining = plain number from the Tracker. UnitHealth/Max are secret and go
-- straight into the StatusBars, never into Lua math.
function O.Update(bar, unit, remaining, skullSize)
  local o = bar.__qthZone
  if not remaining or remaining <= 0 then
    if o then o:Hide() end
    return
  end
  if not o then
    o = build(bar, skullSize or 14)
    bar.__qthZone = o
  end
  o:SetMinMaxValues(0, UnitHealthMax(unit))
  o:SetValue(remaining)
  o.skullBar:SetMinMaxValues(0, UnitHealth(unit))
  o.skullBar:SetValue(remaining)
  o:Show()
end

function O.Hide(bar)
  if bar and bar.__qthZone then bar.__qthZone:Hide() end
end
