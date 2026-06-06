# 🤝 BotFriendship

**Affinity and loyalty system for NPCBots in World of Warcraft 3.3.5a**  
Compatible with **AzerothCore + Eluna** and the **mod-npc-bots** module.

---

## What is BotFriendship?

BotFriendship turns your NPCBots into adventure companions with memory. Each bot tracks an affinity score with you that grows when you treat them well and drops when you act dishonorably. Reaching certain ranks earns you in-game mail rewards, and hitting the maximum rank unlocks **Paragon** mode with repeatable rewards.

---

## 📁 File structure

```
Interface/AddOns/BotFriendship/
├── BotFriendship.lua        ← Client addon (Interface/AddOns)
└── BotFriendship.toc

lua_scripts/
└── BotFriendship_Rewards.lua  ← Server script (Eluna lua_scripts folder)
```

> ⚠️ `BotFriendship_Rewards.lua` goes on the **server**, not in the AddOns folder.

---

## 🚀 Installation

### Client addon
1. Copy the `BotFriendship` folder into `World of Warcraft/Interface/AddOns/`
2. Enable the addon from the character selection screen

### Server script
1. Copy `BotFriendship_Rewards.lua` into your AzerothCore server's `lua_scripts` folder
2. Restart the server or reload scripts with `.reload eluna`

---

## 🎮 In-game usage

### Quick access button
A square button with the guild icon appears on screen. You can **drag it** anywhere — its position is saved between sessions.

| Action | Result |
|---|---|
| Left click | Opens / closes the Companion Journal |
| Right click | Shows available commands in chat |
| Drag | Moves the button anywhere on screen |

### Slash commands

```
/botfriend menu                    → Opens the Companion Journal
/botfriend desbloquear BotName     → Manually unblocks a bot
```

---

## 📖 The Companion Journal

The Journal shows all bots you have interacted with, displaying their name, current rank, points and a progress bar.

- **Colored bar** — reflects the bot's current rank
- **IN TIMEOUT** — the bot is blocked with a live countdown timer
- **Reset button** — resets a specific bot's affinity (asks for confirmation)
- **Language selector** — switches between Spanish and English

---

## ⭐ Rank system

Affinity ranges from 0 to 10,000 points. Each rank is reached once and unlocks a mail reward.

| Rank | Points | Name |
|---|---|---|
| 1 | 0 – 1000 | Distrustful |
| 2 | 1001 – 3000 | Neutral |
| 3 | 3001 – 6000 | Companion |
| 4 | 6001 – 9999 | Faithful |
| 5 | 10000+ | Brother in Arms |

### Paragon mode
Upon reaching **Brother in Arms** (10,000 points), Paragon mode activates. The counter resets to 0 and a new cycle begins. Each completed cycle adds a **+N** indicator to the rank and delivers a new mail reward. Paragon reward gold scales with the level: `base_gold × paragon_level`.

---

## 📈 How to earn points

| Action | Points |
|---|---|
| Complete a quest with the bot in your party | +250 |
| Kill a normal creature (grants XP or honor) | +2 |
| Kill an elite or rare | +10 |
| Kill a worldboss or rare elite | +20 |

> The bot **must be in your party** to receive positive points.

---

## 📉 How to lose points (penalties)

| Action | Penalty |
|---|---|
| Kill a creature **without the bot in your party** | −30 |
| The bot dies in combat | −100 |
| Attack civilians or friendly NPCs | −2000 |

---

## 🔒 Timeout system

If a bot's affinity drops to **0 points**, they refuse to serve you any further:

1. `.npcbot hide` is triggered — all bots are hidden
2. The bot appears in the Journal as **IN TIMEOUT** with a live countdown
3. While blocked, the bot neither gains nor loses points
4. After **15 minutes**, the bot returns automatically with **1 point** and `.npcbot unhide` is triggered
5. If you log out during the timeout, upon returning the addon checks whether the time has elapsed and unblocks automatically

To unblock manually:
```
/botfriend desbloquear BotName
```

---

## 🎁 Reward configuration

Edit `BotFriendship_Rewards.lua` on the server. All configuration is inside the marked zone at the top of the file.

### Rank rewards
```lua
[2] = {
    gold    = 5 * 10000,       -- 5 gold (X * 10000 = X gold)
    items   = {
        { entry = 34009, count = 1 },  -- item ID from the database
    },
    subject = "New Rank: Neutral",
    body    = "Your companion now sees you as someone trustworthy.",
},
```

### Paragon rewards
**Option A** — same reward every cycle: edit only `PARAGON_DEFAULT`.  
**Option B** — different reward per specific cycle: add an entry `[N]` in `PARAGON_LEVELS`.

```lua
PARAGON_LEVELS = {
    [3] = {
        gold    = 500 * 10000,
        items   = { { entry = 40753, count = 1 } },
        subject = "Paragon +3: Special Reward!",
        body    = "You have reached the third Paragon cycle. Extraordinary.",
    },
}
```

Item IDs can be looked up on [Wowhead WotLK](https://www.wowhead.com/wotlk).

---

## ⚙️ Advanced configuration (BotFriendship.lua)

At the top of `BotFriendship.lua` you can adjust all values:

```lua
local PUNTOS_MISION         = 250   -- points per completed quest
local PUNTOS_KILL_NORMAL    = 2     -- normal creature
local PUNTOS_KILL_ELITE     = 10    -- elite / rare
local PUNTOS_KILL_BOSS      = 20    -- worldboss / rare elite

local PENALIZACION_SIN_GRUPO  = -30    -- kill without bot in party
local PENALIZACION_MUERTE_BOT = -100   -- bot dies
local PENALIZACION_DESHONOR   = -2000  -- attack on civilians

local BLOQUEO_DURACION = 15 * 60   -- timeout duration in seconds
```

---

## 🌐 Languages

The addon includes support for **Spanish** and **English**. Switch from the language button inside the Journal. The preference is saved per account.

---

## 📋 Requirements

- World of Warcraft **3.3.5a** (build 12340)
- [AzerothCore](https://www.azerothcore.org/)
- [Eluna Lua Engine](https://github.com/ElunaLuaEngine/Eluna)
- [mod-npc-bots](https://github.com/trickerer/Trinity-Bots)

---

## 🤝 Credits

Created by **Lleguito**.  
Built on the AzerothCore + Eluna + mod-npc-bots ecosystem.
