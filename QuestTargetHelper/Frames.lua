-- Finds the health bars to draw on: target, focus and every enemy nameplate.
local _, ns = ...

local F = { plates = {} } -- plates[unitToken] = health bar
ns.Frames = F

function F.TargetBar()
  local tf = TargetFrame
  local main = tf and tf.TargetFrameContent and tf.TargetFrameContent.TargetFrameContentMain
  return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
    or (main and main.HealthBar) or TargetFrameHealthBar or (tf and tf.healthbar)
end

function F.FocusBar()
  local ff = FocusFrame
  local main = ff and ff.TargetFrameContent and ff.TargetFrameContent.TargetFrameContentMain
  return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
    or (main and main.HealthBar) or FocusFrameHealthBar or (ff and ff.healthbar)
end

local function shown(f)
  local ok, s = pcall(f.IsShown, f)
  return ok and s == true
end

-- Plater's bar when Plater drives the plate, else Blizzard's.
local function plateBar(unit)
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then return nil end
  local pf = plate.unitFrame
  if pf and pf.healthBar and shown(pf) then return pf.healthBar end
  local uf = plate.UnitFrame
  if uf and uf.healthBar then return uf.healthBar end
  return nil
end

function F.OnPlateAdded(unit)
  F.plates[unit] = false -- bar resolved at draw time (Plater may not be set up yet)
end

-- Current bar for a plate unit. If Plater swapped bars, hide the zone on the old one.
function F.PlateBar(unit)
  local bar = plateBar(unit)
  local old = F.plates[unit]
  if old and old ~= bar then ns.Overlay.Hide(old) end
  F.plates[unit] = bar or false
  return bar
end

-- Plates are recycled: hide our zone before the bar goes to another mob.
function F.OnPlateRemoved(unit)
  ns.Overlay.Hide(F.plates[unit] or nil)
  F.plates[unit] = nil
end
