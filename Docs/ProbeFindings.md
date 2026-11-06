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

## Report 2 (2026-11-05): automatic in-combat snapshots, Zhevra Runners (quest mobs)
- `HasSecretRestrictions` and `ShouldAurasBeSecret` are both true in combat.
- `UnitGUID` and `UnitName` are **plain in combat** (`ShouldUnitIdentityBeSecret` = false), on the target and on nameplates.
- `UnitCanAttack` is plain. `UnitHealthMax` is secret (`ShouldUnitHealthMaxBeSecret` = true).
- **Auras are unreadable in combat**: "Auras cannot be accessed when secret while tainted". `UNIT_AURA`'s `isFullUpdate` is itself secret.
- **`UNIT_COMBAT` amounts are secret.** `action` (WOUND, …), `flag` (CRITICAL) and `school` stay plain. No addon can learn tick sizes, which is why DoesItDie's estimates stay wrong.
- DoT ticks can crit.
- `GetSpellBonusDamage` is **secret in combat** (it was 29 out of combat).
- `C_Spell.GetSpellDescription` stays plain in combat, with the same text as out of combat.
- Quest detection works in combat:
  - `C_QuestLog.UnitIsRelatedToActiveQuest(unit)` = true.
  - `C_TooltipInfo.GetUnit` lines are plain: type 17 = quest title ("The Zhevra"), type 8 = objective ("0/4 Zhevra Hooves").
  - Plater's `namePlateIsQuestObjective` = true and `namePlateNpcId` = 3242 are plain.
- With Plater, Blizzard's `plate.UnitFrame` is hidden and Plater's `plate.unitFrame` is the one shown.

## Open
- Do description numbers include spell power? Check by swapping a +spell damage item out of combat and re-reading the description.
