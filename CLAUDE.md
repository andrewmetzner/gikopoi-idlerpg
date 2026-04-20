# gikomacs-bot-akai-bot — Project Notes

## File structure

| File | Purpose |
|---|---|
| `gikopoi.el` | Gikopoi client (upstream fork + akai patches) |
| `system.el` | Core engine: player DB, items, stats, XP, inventory, gold, AP |
| `classes.el` | MapleStory job tree + advancement logic |
| `battle.el` | Monster definitions, combat simulation, per-player battle timers |
| `barter.el` | Shop listings, buy/sell between players |
| `commands.el` | All `$cmd` handlers + dispatch table |
| `akai-bot.el` | Gikopoi event hook, idle XP timer, `akai-bot-connect` |
| `run-akai-bot.el` | **Entry point** — loads everything, sets config, calls connect |
| `akai-bot-players.el` | Auto-generated player DB (do not edit by hand) |

## How to launch

```
M-x load-file RET run-akai-bot.el RET
```
or `(load "/path/to/run-akai-bot.el")` in init.el. Does NOT read/touch `gikopoi-default-*` from .emacs.

---

## Bot config (edit in run-akai-bot.el)

| Variable | Value | Notes |
|---|---|---|
| `akai-bot-bot-server` | `"play.gikopoi.com"` | |
| `akai-bot-bot-area` | `"for"` | |
| `akai-bot-bot-name` | `"idleRP"` | |
| `akai-bot-bot-character` | `"giko"` | |
| `akai-bot-bot-password` | `nil` | |
| `akai-bot-idle-xp-interval` | `300` | seconds between idle XP ticks |
| `akai-bot-idle-xp-amount` | `50` | XP per idle tick (idle mode only) |
| `rpg-battle-interval` | `60` | seconds between auto-fights (battle mode) |

Room is always auto-selected (most populated on server).

---

## Player commands

| Command | Effect |
|---|---|
| `$register` | Create Beginner character |
| `$stats` | Full character sheet |
| `$level` | Level, XP, XP to next level |
| `$job` | Current job + advancement status |
| `$advance <job>` | Advance job (needs level + item) |
| `$classes` | List all job paths |
| `$ap` | See unspent ability points |
| `$addstat <str/dex/int/luk>` | Spend 1 AP on a stat |
| `$equip <item-id>` | Equip a weapon or armor |
| `$use <item-id>` | Use a consumable |
| `$inventory` / `$inv` | Show bag, equipped, and shop listings |
| `$battle on/off/status` | Toggle battle mode |
| `$barter on/off` | Toggle shop mode |
| `$sell <item-id> <price>` | List item in shop (barter mode required) |
| `$buy <item-id> from <player>` | Buy from another player's shop |
| `$market` | See all open shops in the room |
| `$top` | Leaderboard (top 5 by level) |
| `$online` | Registered players in room |
| `$help` | Command list |

---

## MapleStory job tree

```
Beginner (lv1)
  → lv10 + Scroll of Awakening →
      Warrior  → lv30 + Warrior's Manual  → Fighter / Spearman
                                              → lv60 + Hero's Emblem → Crusader / Dragon Knight
      Magician → lv30 + Magician's Tome   → Fire Mage / Ice Mage / Cleric
                                              → lv60 + Hero's Emblem → Archmage(F/P) / Archmage(I/L) / Bishop
      Bowman   → lv30 + Bowman's Manual   → Hunter / Crossbowman
                                              → lv60 + Hero's Emblem → Bowmaster / Marksman
      Thief    → lv30 + Thief's Codex     → Assassin / Bandit
                                              → lv60 + Hero's Emblem → Night Lord / Shadower
```

Stat primaries: Warrior=STR, Magician=INT, Bowman=DEX, Thief=DEX+LUK

---

## XP / Level formula

`Total XP to reach level N = (N-1) × N × 50`

| Level | Total XP | Idle time (50xp/5min) | Battle time (~300xp/min) |
|---|---|---|---|
| 2 | 100 | 10 min | <1 min |
| 5 | 1000 | 1.7 hr | 3 min |
| 10 | 4500 | 7.5 hr | 15 min |
| 30 | 43500 | 72 hr | 2.4 hr |
| 60 | 177000 | 295 hr | 10 hr |

---

## Combat formula

- Player DMG = `max(1, ATK − monster_DEF/2) × (1 + LUK×0.002)`
- Monster DMG = `max(1, monster_ATK − player_DEF/2)`
- Win if rounds-to-kill-monster < rounds-to-kill-player
- Win: gain XP + gold + possible item drops
- Loss: HP floors at 1, lose 10% gold

ATK stat weights by job:
- Warrior/Fighter/Spearman: weapon + STR×0.5 + DEX×0.2
- Magician: weapon + INT×0.5 + matk
- Bowman/Hunter/Crossbow: weapon + DEX×0.5 + STR×0.2
- Thief/Assassin/Bandit: weapon + DEX×0.4 + LUK×0.4

---

## Items of note

| Item | How to get | Used for |
|---|---|---|
| Scroll of Awakening | lv5+ monsters | 1st job advance |
| Warrior's/Magician's/Bowman's/Thief's Manual | lv30+ monsters | 2nd job advance |
| Hero's Emblem | lv60+ monsters | 3rd job advance |
| Red Potion | drops, barter | +50 HP |
| Blue Potion | drops, barter | +30 MP |
| Elixir | lv30+ drops | +300 HP +150 MP |

---

## gikopoi.el patches (vs upstream)

- Auto-scroll / near-bottom tracking
- Auto-ignore list (`auto-ignore.txt`)
- Logger (`gikopoi-logger`, daily log files)
- Auto-reconnect timer (`gikopoi-reconnect-timer-minutes`, default 720)
- Busiest-room auto-join (`gikopoi-get-most-populated-room`)
- `gikopoi-default-room nil` = always auto-join most populated
- HSL name colors for dark themes
- Nil-safe `gikopoi-default-name` guard in arglist

---

## Ideas / TODO

- [ ] HP/MP potion drops more common early game
- [ ] `$quest` random event while idle (find item, lose gold, etc.)
- [ ] PvP: `$duel <player>`
- [ ] Guild system
- [ ] Crafting: combine drops into better gear
