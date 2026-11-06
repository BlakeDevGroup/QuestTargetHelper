-- DoTs we track, keyed by spell name (Forever uses its own spell IDs, and every
-- rank shares a name). Damage and duration come from the live description at
-- cast time (see Math.lua); this table only says how the damage is spread.
--   tick  = seconds between ticks (used to step the zone down tick by tick)
--   model = "flat" (even ticks, default), "agony" (ramps up), "finisher" (per combo point)
local _, ns = ...

ns.Spells = {
  -- Warlock
  ["Corruption"]        = { tick = 3 },
  ["Immolate"]          = { tick = 3 },
  ["Bane of Agony"]     = { tick = 2, model = "agony" },
  ["Curse of Agony"]    = { tick = 2, model = "agony" },
  ["Siphon Life"]       = { tick = 3 },
  -- Priest
  ["Shadow Word: Pain"] = { tick = 3 },
  ["Devouring Plague"]  = { tick = 3 },
  ["Holy Fire"]         = { tick = 2 },
  -- Druid
  ["Moonfire"]          = { tick = 3 },
  ["Insect Swarm"]      = { tick = 2 },
  ["Entangling Roots"]  = { tick = 3 },
  ["Rake"]              = { tick = 3 },
  ["Rip"]               = { tick = 2, model = "finisher" },
  ["Pounce"]            = { tick = 3 },
  ["Lacerate"]          = { tick = 3 },
  -- Hunter
  ["Serpent Sting"]     = { tick = 3 },
  -- Mage (periodic part only)
  ["Fireball"]          = { tick = 2 },
  ["Pyroblast"]         = { tick = 3 },
  ["Frostfire Bolt"]    = { tick = 3 },
  -- Rogue
  ["Rupture"]           = { tick = 2, model = "finisher" },
  ["Garrote"]           = { tick = 3 },
  -- Shaman
  ["Flame Shock"]       = { tick = 3 },
  -- Warrior
  ["Rend"]              = { tick = 3 },
}
