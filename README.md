# QuestTargetHelper

A speed-levelling helper for **World of Warcraft: Forever**.

## Kill zone
Your DoTs are marked on the health bar of every mob you've dotted: on nameplates (Blizzard's or Plater's) and on your target and focus frames. The zone is the damage your DoTs still have to deal, drawn from the left edge of the bar. **If the health ends inside the zone, your DoTs will kill it.** A skull appears beside the bar when they will.

- The estimate is right from your first cast. It is read from the spell's own tooltip, which already includes your spell power, so there is nothing to learn first.
- It errs low: crits are not counted, so if it says a mob dies, it does.
- It counts DoTs cast at your soft target, mouseover or focus, not just your target.
- Classes: Warlock, Priest, Druid, Hunter, Mage, Rogue, Shaman, Warrior.

## Pull tracker
A small panel shows your quest objectives for the mobs around you, and how many kills are **in flight**: quest mobs carrying your DoTs. *"Zhevra Hooves 2/4 +2 dotted ✔"* means the DoTs already out will finish a kill objective, so stop pulling. Below the objectives are the nearby quest mobs, each with a mini health bar, its kill zone and skull, and grey if another player tagged it.

Set it to show in combat, when quest mobs are nearby (default), always, or never. Drag it to move it, then lock it so clicks go through.

## Quest-mob targeting
*Coming next:* one keybind targets the next mob your quests need and marks it with a skull.

## Commands
- `/qth`: settings (also under Options → AddOns)
- `/qth on` / `/qth off`
- `/qth feedback`: link to report a bug, with a ready-made report to paste
- `/qth debug`: the DoTs tracked on your target

## Feedback
[Open an issue](https://github.com/BlakeDevGroup/QuestTargetHelper/issues). `/qth feedback` in game gives you the link and a report to paste.

## How it works on Forever
Forever hides mob health, aura data and damage numbers from addons in combat. Addon code can't compare "DoT damage left" with "health left". A health bar can, though: the kill zone is a bar scaled to the mob's max health, so the game draws the comparison and the addon never reads health. Details are in [Docs/ProbeFindings.md](Docs/ProbeFindings.md).

## Credits
The clipped skull bar is an idea from [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive (MIT).

## License
MIT
