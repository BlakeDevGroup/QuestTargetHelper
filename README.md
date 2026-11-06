# QuestTargetHelper

A speed-levelling helper for **World of Warcraft: Forever**.

## Kill zone
Your DoTs are marked on the health bar of every mob you've dotted: on nameplates (Blizzard's or Plater's) and on your target and focus frames. The zone is the damage your DoTs still have to deal, drawn from the left edge of the bar. **If the health ends inside the zone, your DoTs will kill it.** A skull appears beside the bar when they will.

- The estimate is right from your first cast. It is read from the spell's own tooltip, which already includes your spell power, so there is nothing to learn first.
- It errs low: crits are not counted, so if it says a mob dies, it does.
- It counts DoTs cast at your soft target, mouseover or focus, not just your target.
- Classes: Warlock, Priest, Druid, Hunter, Mage, Rogue, Shaman, Warrior.

## Pull tracker
A small panel lists the quest mobs around you, each with a mini health bar, its kill zone and skull, greyed if another player tagged it. **Left-click a mob to target it, right-click to skull it.** Your current target's row is highlighted in gold. Below them are the objectives those mobs count for.

In combat the row order holds still, because the game won't let clickable buttons move mid-fight. The rows themselves keep updating.

Set it to show in combat, when quest mobs are nearby (default), always, or never. Drag it by the objectives to move it, then lock it.

## Next quest mob keybind
Bind **Target next quest mob** (Key Bindings → AddOns → QuestTargetHelper). One press targets the best quest mob around you and puts a skull on it.
- It skips mobs another player tagged, mobs already carrying your DoTs, and mobs whose objectives you've finished.
- It prefers **double-dip** mobs: one kill that advances two objectives.
- Out of combat, it targets exactly the mob outlined in green on its nameplate (and marked `>` in the pull tracker).
- In combat, Forever won't let addons change the key's target, so it targets the quest mobs by name and moves on from your current target.

Forever doesn't allow targeting or marking without a key press, so this is a keybind, not automatic.

## Markers and alerts
- **x2** beside a nameplate: that mob counts for two unfinished objectives.
- A **Quest complete** announcement, with a sound.

## Looting
Addons can't loot or interact for you; only Blizzard's Interact key can. `/qth loot` turns on soft interact and auto loot. Then the Interact key loots the corpse in front of you without targeting it, and a "Loot: press <key>" prompt shows when there's loot. Bind **Interact With Target** to a mouse button and looting is one click.

## Commands
- `/qth`: settings (also under Options → AddOns)
- `/qth on` / `/qth off`
- `/qth feedback`: link to report a bug, with a ready-made report to paste
- `/qth debug`: the DoTs tracked on your target

## Feedback
[Open an issue](https://github.com/BlakeDevGroup/QuestTargetHelper/issues). `/qth feedback` in game gives you the link and a report to paste.

## How it works on Forever
Forever hides mob health, aura data and damage numbers from addons in combat. Addon code can't compare "DoT damage left" with "health left". A health bar can, though: the kill zone is a bar scaled to the mob's max health, so the game draws the comparison and the addon never reads health. Details are in [Docs/ProbeFindings.md](Docs/ProbeFindings.md).

## Development
Every decision (quest mob, fighting your side, rows, next mob, cast target, quest-complete alerts) lives in `QuestTargetHelper/Rules.lua`. These are pure functions over plain "snapshots", which `Snapshot.lua` builds from the game; anything Forever hides becomes `nil`, never a guess. Every bug found in play gets a regression test in `tests/rules_test.lua`.

```
lua tests/run_all.lua
```
CI runs the same on every push, with Lua 5.1 like WoW.

## Credits
The clipped skull bar is an idea from [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive (MIT).

## License
MIT
