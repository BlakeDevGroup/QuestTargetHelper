# CurseForge listing

Everything needed to fill in the project page. Copy each block as is.

## Project name
QuestTargetHelper

## Summary (the one line under the name and in search results)
Track your DoTs on every mob at once: see which ones will die, and click quest mobs to target them. Built for WoW Forever.

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

**Stop wasting casts on mobs that are already dead, and stop hunting for quest mobs.**

A speed-levelling helper for **WoW Forever**.

### 💀 Kill zone
A purple zone on every health bar shows the damage your DoTs still have to deal. **Health inside the zone = it dies.** A skull confirms it.
- Accurate from your first cast, spell power included
- Nameplates (Blizzard and Plater), target and focus
- Every DoT class

### 🎯 Pull tracker
Every quest mob nearby and every mob fighting you or your group, with health bars, kill zones and your objectives with live counts. **Click a mob to target it, right-click to skull it.** Mobs that count for two objectives are marked x2.

### ✅ Just works
Built for Forever's addon rules, so it doesn't break. Only your quests count in a group. Light on settings, heavy on tests.

**Open world only:** in dungeons and raids Forever hides nameplates and mob info from addons, so QuestTargetHelper switches off there.

Bugs or ideas: `/qth feedback` or [GitHub](https://github.com/BlakeDevGroup/QuestTargetHelper/issues).

## Screenshots (take these in game; the first is the thumbnail)
1. **Hero shot:** 3 dotted mobs on nameplates, one with its health inside the purple zone and a skull. Plater, default colours. This one sells the addon.
2. **Pull tracker** mid-fight: two quest mobs and one orange non-quest mob attacking you, objectives with counts above.
3. **x2 marker:** a nameplate with `x2`, and the gold outline from hovering its pull-tracker row.
4. **Target frame** with the kill zone and skull.
5. **Settings page** (`/qth`), to show it's simple.

Tips: hide other UI clutter, keep the camera close, use a busy quest area, 1920x1080 or larger.

## Logo (project avatar, square, 400x400)
`Media/logo.png`: a gold quest "!" over a health bar, with red health ending inside the purple kill zone, before its white edge. It's an original drawing (not Blizzard's quest icon), readable at 64px. Rendered by Blender from `Media/logo.py`:
`blender -b --factory-startup -P Media/logo.py -- Media/logo.png 400`

## First release notes (v1.0.0)
First public release for WoW Forever.
- Kill zone on nameplates (Blizzard and Plater) and target and focus frames, with a skull when your DoTs are lethal.
- Pull tracker panel: nearby quest mobs and mobs fighting your side, clickable, with objectives and live counts.
- x2 marker for mobs that count for two objectives.
- Quest complete announcement and nameplate range setting.

## Where to post it
- **CurseForge** first, so the other links point there.
- **r/wow and the WoW Forever subreddit or Discord, if one exists.** Post the hero screenshot or a 10-second clip of a mob dying inside its zone, the summary line, and the link. Answer comments for the first day; early bug reports are where reviews come from.
- **Levelling communities:** RestedXP and Questie users are the exact audience. Post "works alongside RXP and Questie", which is true: it doesn't replace either.
- Don't post to the DoesItDie page or compare against it directly; the credit line says enough.
