# CurseForge listing

Everything needed to fill in the project page. Copy each block as is.

## Project name
QuestTargetHelper

## Summary (the one line under the name and in search results)
See at a glance which mobs your DoTs will kill, and target the next quest mob with one key. Built for WoW Forever.

## Categories
- Primary: **Quests & Leveling**
- Also: **Combat**, **Unit Frames**, **Class**

## Game version
WoW Forever 1.60.1 (Interface 16001)

## Links
- Issues: https://github.com/BlakeDevGroup/QuestTargetHelper/issues
- Source: https://github.com/BlakeDevGroup/QuestTargetHelper
- License: MIT

---

## Description (paste into the description editor)

**Stop wasting casts on mobs that are already dead, and stop hunting for the next quest mob.**

QuestTargetHelper is a speed-levelling helper for **World of Warcraft: Forever**. It shows how much damage your DoTs still have to deal, right on the health bar, and it finds the next mob your quests need.

### Kill zone
Every mob you've DoTed gets a purple **kill zone** on its health bar: the damage your DoTs still have to deal, drawn from the left edge. **If the health ends inside the zone, your DoTs will kill it.** A skull appears beside the bar when they will.

- **Right from your first cast.** Damage comes from your spell's own tooltip, which already includes your spell power. There's nothing to learn first.
- **Errs low.** Crits aren't counted, so if it says a mob dies, it does.
- **On nameplates and your target and focus frames.** Works with Blizzard nameplates and Plater.
- **Follows your casts.** DoTs cast at your soft target, mouseover or focus count too, not just your target.
- **Every DoT class:** Warlock, Priest, Druid, Hunter, Mage, Rogue, Shaman, Warrior.

### Pull tracker
A small panel lists the mobs that matter right now:
- the quest mobs around you, with the objectives they count for and live counts from your quest log;
- every mob fighting you, your pet or your group;
- a mini health bar per mob, with its own kill zone and skull.

**Left-click a mob to target it, right-click to put a skull on it.** Your current target is highlighted in gold. Mobs tagged by another player are greyed out. In a group, only your own quests and counts are shown, never a teammate's.

### Next quest mob: one key
Bind **Target next quest mob**. One press targets the best quest mob around you and puts a skull on it:
- skips mobs someone else tagged, mobs already carrying your DoTs, and objectives you've finished;
- prefers **double-dip** mobs, where one kill advances two objectives (marked **x2** on their nameplate);
- out of combat, the exact mob it will hit is outlined in green.

### Also
- **Quest complete** announcement, once per quest.
- **One-key looting setup** (`/qth loot`): turns on Blizzard's Interact key for the corpse in front of you, and shows "Loot: press F" when there's loot.
- **Nameplate range** setting, so the tracker and keybind see further.

### Commands
- `/qth`: settings (also under Options → AddOns)
- `/qth feedback`: report a bug, with a ready-made report to paste
- `/qth debug`, `/qth quest`: what the addon sees on your target

### How it works on Forever (and why it doesn't break)
Forever hides mob health, aura data and damage numbers from addons in combat. Addon code can't compare "DoT damage left" with "health left". A health bar can, though: the kill zone is a bar scaled to the mob's max health, so the game draws the comparison and the addon never reads health. The rules it decides with (what's a quest mob, what's fighting you, which mob is next, DoT math) are covered by automated tests that run on every change.

For the same reason, **targeting and looting need a key press**: Forever doesn't let addons target or interact on their own, so QuestTargetHelper sets up the key and you press it.

### Feedback
Found a bug or have an idea? Type `/qth feedback` in game, or open an issue on [GitHub](https://github.com/BlakeDevGroup/QuestTargetHelper/issues).

*The clipped skull bar idea comes from [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive (MIT).*

---

## Screenshots (take these in game; the first is the thumbnail)
1. **Hero shot:** 3 dotted mobs on nameplates, one with its health inside the purple zone and a skull. Plater, default colours. This one sells the addon.
2. **Pull tracker** mid-fight: two quest mobs and one orange non-quest mob attacking you, objectives with counts above.
3. **Next quest mob:** the green outline on a nameplate, plus an `x2` mob nearby.
4. **Target frame** with the kill zone and skull.
5. **Settings page** (`/qth`), to show it's simple.

Tips: hide other UI clutter, keep the camera close, use a busy quest area, 1920x1080 or larger.

## Logo (project avatar, square, 400x400)
`Media/logo.png`: a skull over a health bar, with red health ending inside the purple kill zone, before its white edge. It's an original drawing (not Blizzard's raid icon), readable at 64px. Rendered by Blender from `Media/logo.py`:
`blender -b --factory-startup -P Media/logo.py -- Media/logo.png 400`

## First release notes (v1.0.0)
First public release for WoW Forever.
- Kill zone on nameplates (Blizzard and Plater) and target and focus frames, with a skull when your DoTs are lethal.
- Pull tracker panel: nearby quest mobs and mobs fighting your side, clickable, with objectives and live counts.
- Target next quest mob keybind, with skull marking, double-dip priority and next-mob outline.
- Quest complete announcement, one-key looting setup, nameplate range setting.

## Where to post it
- **CurseForge** first, so the other links point there.
- **r/wow and the WoW Forever subreddit or Discord, if one exists.** Post the hero screenshot or a 10-second clip of a mob dying inside its zone, the summary line, and the link. Answer comments for the first day; early bug reports are where reviews come from.
- **Levelling communities:** RestedXP and Questie users are the exact audience. Post "works alongside RXP and Questie", which is true: it doesn't replace either.
- Don't post to the DoesItDie page or compare against it directly; the credit line says enough.
