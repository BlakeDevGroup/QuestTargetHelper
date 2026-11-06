# Forever probe findings

Build 1.60.1.70790, Interface 16001, WOW_PROJECT_ID 18. Warlock level 18, open world.

## Report 1 (2026-11-05): out of combat, no target selected
- `UnitHealth`, `UnitHealthMax`, `UnitHealthPercent` and `UnitHealthMissing` are **secret everywhere**, even out of combat in the open world, nameplates included. Arithmetic and comparison both throw. So the kill zone has to be drawn by a StatusBar.
- `StatusBar:SetMinMaxValues(0, secret)` and `SetValue(secret)` work, and `GetValue` returns a secret.
- `SetAlphaFromBoolean` and `SetReverseFill` exist. `C_CurveUtil` has `CreateCurve`, `CreateColorCurve`, `EvaluateColorFromBoolean`, `EvaluateColorValueFromBoolean` and `EvaluateGameCurve`.
- `UnitGUID` and `UnitName` are **plain out of combat** (`Creature-0-6806-1-2-11833-…`). In combat: not yet tested.
- `UNIT_SPELLCAST_SUCCEEDED` / `_SENT` give a plain spellID and castGUID.
- `C_Spell.GetSpellDescription` contains damage numbers, e.g. Corruption 6222 "103 Shadow damage over 15 sec", Immolate 707 "27 Fire … then 48 over 15 sec", Bane of Agony 980 "118 over 24 sec". Not yet tested: whether these scale with spell power (`GetSpellBonusDamage(6)` = 29).
- It returned `""` inside the event for spells whose data wasn't loaded (crafts). Pre-load DoT spells with `C_Spell.RequestLoadSpellData`.
- `COMBAT_LOG_EVENT_UNFILTERED`: registering it triggers ADDON_ACTION_FORBIDDEN. Never register it. `UNIT_COMBAT` registers fine.
- Nameplates are ready during `NAME_PLATE_UNIT_ADDED` (no delay needed). The user runs Plater: `plate.UnitFrame.healthBar` is Blizzard's bar, `plate.unitFrame` is Plater's. Plater caches `namePlateUnitGUID`, `namePlateNpcId`, `namePlateUnitName` and `namePlateIsQuestObjective` on the plate.
- `C_Secrets` has predicates per category (`ShouldUnitIdentityBeSecret`, `ShouldUnitHealthMaxBeSecret`, `ShouldAurasBeSecret`, …), so we can check before reading.

## Still open (report 2: automatic in-combat snapshots)
- Are GUIDs and names secret in combat? Are our debuffs readable in combat?
- Does `UNIT_COMBAT` fire with plain amounts?
- Does tooltip quest-objective data or `UnitIsRelatedToActiveQuest` work?
- Are Plater's cached fields plain?
