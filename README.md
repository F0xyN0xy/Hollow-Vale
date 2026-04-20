# 🌲 Hollow Vale

**Hollow Vale** is a 2D top-down action RPG built with the **LÖVE (Love2D)** framework. Explore a mysterious world filled with monsters, NPCs, loot, and a powerful boss lurking in the depths.

---

## ✨ Features

* ⚔️ Real-time combat (melee, tools, and projectiles)
* 👾 Multiple enemy types (slimes, bats, orcs, and bosses)
* 🧙 NPC interactions (merchant, old man, etc.)
* 🎒 Inventory-style objects (weapons, potions, keys, armor)
* ❤️ Health and mana system
* 🌍 Tile-based world with environment elements (trees, water, roads, huts)
* 🎵 Sound effects and background music
* 👑 Boss fight with multiple phases

---

## 📁 Project Structure

```
Hollow Vale/
│
├── main.lua
├── conf.lua
│
├── src/
│   ├── player.lua
│   ├── enemy.lua
│   ├── boss.lua
│   ├── npc.lua
│   ├── world.lua
│   └── camera.lua
│
├── assets/
│   ├── Player/
│   ├── Monster/
│   ├── NPC/
│   ├── Environment/
│   ├── Object/
│   ├── Projectile/
│   └── Sound/
```

---

## 🚀 Getting Started

### 1. Install LÖVE

Download LÖVE from: [https://love2d.org/](https://love2d.org/)

---

### 2. Run the Game

**Option A (Drag & Drop):**

* Drag the `Hollow Vale` folder onto the LÖVE executable

**Option B (Command Line):**

```bash
love "Hollow Vale"
```

---

## 🎮 Controls (example – adjust if needed)

| Key        | Action           |
| ---------- | ---------------- |
| WASD       | Move             |
| Arrow Keys | Alternative move |
| Space      | Attack           |
| Shift      | Guard            |
| E          | Interact         |

---

## 🧠 Game Systems Overview

### Player

* Movement, attacking, guarding
* Uses weapons like sword, axe, and pickaxe
* Can take damage and heal

### Enemies

* Basic AI with movement and attack patterns
* Includes slimes, bats, and orcs

### Boss

* Multi-phase combat system
* Increased difficulty and attack variety

### World

* Tile-based rendering
* Includes collision and environment interaction

### Camera

* Smooth tracking of the player

---

## 🔊 Audio

The game includes:

* Background music (exploration, dungeon, boss fight)
* Sound effects (combat, interaction, environment)

---

## 🛠️ Development

Built using:

* **Lua**
* **LÖVE 2D Framework**

# Credits

* [RyiSnow](https://drive.google.com/drive/u/0/folders/1OBRM8M3qCNAfJDCaldg62yFMiyFaKgYx) for Assets and Sounds
* [RyiSnow](https://www.youtube.com/@RyiSnow) visit his Channel for good Java Tutorials