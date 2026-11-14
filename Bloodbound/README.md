# BLOODBOUND — THE LAST OATH

> *"A clan once kept watch over the passage between life and death. They entrusted that passage to Ketsumei. The Hollow Sovereign came for the blade. The village burned. Under the ashes, one heir still breathed. Now, across morning, afternoon, and night, the last oath must be fulfilled."*

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.5.1_Standard-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Branch](https://img.shields.io/badge/Branch-prototype-blueviolet?logo=git&logoColor=white)](https://github.com/DikshantDuggal/BloodHounds/tree/prototype)
[![Platform](https://img.shields.io/badge/Platform-Windows_Desktop_x86__64-0078d7?logo=windows&logoColor=white)](https://github.com/DikshantDuggal/BloodHounds)
[![Renderer](https://img.shields.io/badge/Renderer-GL_Compatibility-green)](#technical-architecture)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](licenses/Godot-LICENSE.txt)

---

## Table of Contents
1. [Overview](#overview)
2. [Narrative & The Three Acts](#narrative--the-three-acts)
3. [Combat System & New Moves](#combat-system--new-moves)
4. [Controls Reference](#controls-reference)
5. [The Campaign Route & Level Breakdown](#the-campaign-route--level-breakdown)
6. [Enemy & Boss Roster](#enemy--boss-roster)
7. [Abilities & Soul Progression](#abilities--soul-progression)
8. [Asset Manifest & Provenance](#asset-manifest--provenance)
9. [Automated QA & Regression Test Suites](#automated-qa--regression-test-suites)
10. [Building & Running the Game](#building--running-the-game)

---

## Overview

**BLOODBOUND — THE LAST OATH** is an expanded, precision 2D dark fantasy combat action game built in **Godot Engine 4.5.1**. Featuring authentic pixel art animation, frame-accurate hitboxes, dynamic multi-phase boss AI, directional parrying, and an ancestral resurrection engine, the player controls **Ilyen**, the resurrected heir of a slaughtered guardian clan.

Armed with the ancestral spirit katana **Ketsumei**, Ilyen embarks on a three-act quest across changing times of day—from morning in the burning village, through an afternoon pursuit in the autumn forests, into the dead of night at the moonlit fortress where **The Demon Overlord** reigns.

---

## Narrative & The Three Acts

```
[ACT I: MORNING]              [ACT II: AFTERNOON]            [ACT III: NIGHT]
The Fallen Heir ─────────────> The Ashen Hunt ──────────────> The Eclipse Hunt
Village & Courtyard            Stone Bridge & Shrine          Moonlit Pass & Fortress
Rematch with Sovereign         Sovereign (350 HP)             Hunter & Brute Werewolves
Scripted Death & Awakening     Unlocks Phantom Step & Sever   True Boss: Demon Overlord (800 HP)
```

### Act I · Morning: The Fallen Heir
The Hollow Sovereign descends upon the clan's village. Ilyen confronts the warlord in the village courtyard. Despite valiant struggle, the duel ends at the story health threshold: the Sovereign strikes Ilyen down and departs through the sealed gate. Left in the ashes, Ilyen's soul journeys through the afterlife before Ketsumei's ancestral resonance pulls him back to life with three resurrection charges.

### Act II · Afternoon: The Ashen Hunt
Awakened under the afternoon sun, Ilyen advances along the Ashen Road. He crosses the Old Stone Bridge, avoids thorny forest briars, and defeats the forest Hunter werewolf. At the sacred shrine, the Hollow Sovereign returns for an afternoon rematch (350 HP). Defeating him raises maximum health to **160 HP**, unlocks **Phantom Step** and **Soul Sever**, and unseals the passage into night.

### Act III · Night: The Eclipse Hunt
Under the full moon, Ilyen crosses the Moonlit Pass bridge and unlocks **Death Reversal** at the nether checkpoint. Two coordinated werewolves—the swift Black Werewolf **Hunter** (150 HP) and the hulking Red Werewolf **Brute** (220 HP)—guard the fortress gates, alternating their attacks. Their defeat unseals the gate and grants **Ancestral Echo**. Inside the fortress stands the true final boss: **The Demon Overlord** (800 HP), fought across three escalating phases leading to the climactic **One Flash** execution.

---

## Combat System & New Moves

### 1. Melee Combat & Combos
- **3-Hit Combo Chain (`J`)**: Chains three light slashes (`light_1` &rarr; `light_2` &rarr; `light_3`) culminating in a wide, heavy-reaching finisher.
- **Dash Slash (`Shift + J`)**: A newly integrated sweeping dash strike executed immediately out of a dodge roll.
- **Aerial Slash (`Air + J`)**: Broad aerial arc for catching leaping wolves or airborne attacks.
- **Heavy Strike (`K`)**: Slow, high-stagger strike dealing 1.8× base damage.
- **Charged Slash (`Hold K with ≥ 25 Energy`)**: Consumes 25 Ability Energy to unleash a 178px reach, 1.52× power charged strike.

### 2. Defense & Parrying
- **Dodge / Dash (`Shift`)**: Directional evade with invulnerability frames (iframes).
- **Active Parry (`L`)**: Deflects incoming parryable attacks, nullifies damage and knockback, and restores **+27 Ability Energy**.
- **Perfect Parry Window (0.065s)**: Deflecting within the first 65ms of raising the guard triggers a screen shake, frame freeze, massive posture stagger to the attacker, and reflects critical counter-damage (`1.5×`).

### 3. Ability Energy Pool (0–100)
Earned by landing hits (+8 to +10) and parrying (+27). Fuels:
- **Phantom Step (`E`)**: 20 Energy
- **Soul Sever (`U`)**: 25 Energy
- **Ancestral Echo (`I`)**: 25 Energy
- **Charged Heavy Slash (`K`)**: 25 Energy
- **Death Reversal (`Q`)**: 100 Energy + 1 Resurrection Charge

---

## Controls Reference

| Key | Action | Description |
| :--- | :--- | :--- |
| **`A` / `D`** or **`←` / `→`** | Move | Directional ground locomotion with smooth turn transitions |
| **`Space`** or **`↑`** | Jump | Variable-height jump; release early to shorten the arc |
| **`J`** | Attack / Slash | Tap to chain 3-hit combo; press during dodge for **Dash Slash** |
| **`K`** | Heavy Attack | Single heavy slash; hold with 25 energy to charge |
| **`Shift`** | Dodge / Dash | Directional evasive roll granting invulnerability frames |
| **`L`** | Parry | Active guard window against parryable attacks (65ms perfect window) |
| **`E`** | Phantom Step | Rapid long-range warp dash through enemy hitboxes *(Unlocked Lv. 2)* |
| **`U`** | Soul Sever | Slicing crescent wave projectile traveling along the floor *(Unlocked Lv. 2)* |
| **`Q`** | Death Reversal | Emergency resurrection blast dealing 48 damage *(Unlocked Lv. 3)* |
| **`I`** | Ancestral Echo | Arms spirit shadow to repeat next attack after 0.25s *(Unlocked Lv. 3)* |
| **`F`** | One Flash | Decisive cinematic execution strike when prompted *(Unlocked Lv. 3)* |
| **`Enter`** | Confirm / Skip | Advances dialogues, skips cutscenes & cinematics |
| **`Escape`** | Pause | Opens pause menu and separate Music & Effects volume sliders |
| **`R`** | Retry | Restores state from the latest session checkpoint after defeat |

---

## The Campaign Route & Level Breakdown

| Level / Phase | Domain | Entry HP | Primary Encounter | Checkpoint & Rewards |
| :---: | :--- | :---: | :--- | :--- |
| **Act I** | **Ruined Village & Courtyard** | **120 HP** | The Hollow Sovereign (Morning Prologue) | **Ancestral Resurrection** (+10% ATK per Soul Level) |
| **Act II** | **Old Stone Bridge & Forest** | **140 HP** | Briar Obstacles, Forest Werewolf Hunter | Bridge Checkpoint |
| **Act II** | **The Autumn Shrine** | **140 HP** | The Hollow Sovereign Rematch (350 HP) | **Phantom Step (`E`)**, **Soul Sever (`U`)**, Max HP &rarr; **160** |
| **Act III** | **Moonlit Pass Bridge** | **160 HP** | Bridge Traversal & Nether Seals | Nether Checkpoint, **Death Reversal (`Q`)** |
| **Act III** | **The Fortress Gate** | **180 HP** | Hunter Werewolf (150 HP) & Brute Werewolf (220 HP) | **Ancestral Echo (`I`)**, Fortress Gate Unsealed |
| **Act III** | **The Fortress Throne** | **200 HP** | **The Demon Overlord (800 HP)** | **One Flash (`F`)**, Epilogue & Victory |

*Note: Bridges are fully bidirectional. Players can walk either way across both bridges while retaining their current checkpoint and defeated enemy states.*

---

## Enemy & Boss Roster

### 1. Ilyen (The Heir)
- **Weapon**: **Ketsumei** (custom 17 × 60 pixel art asset rendered with sub-pixel alignment and red-wrapped grip).
- **Visuals**: Animated using the CraftPix Samurai sprite sheet with authored death and reverse-death resurrection animations.

### 2. Minions & Werewolves
- **Forest Hunter Werewolf (150 HP)**: Fast-leaping predator executing claw rushes and pounces.
- **Red Brute Werewolf (220 HP)**: Heavy frontline shock trooper with ground-pound claw attacks.
- *Coordinated AI*: In the Fortress Gate encounter, the Hunter and Brute coordinate their attack intervals to test player parry and dodge discipline.

### 3. The Hollow Sovereign (Morning & Afternoon Boss)
- Animated via the Minotaur atlas by chierit (CC BY 4.0).
- Uses *Void Cleave*, *Eclipse Slam* (ground shockwave), and *Shadow Rush*. Returns in the afternoon at 350 HP.

### 4. The Demon Overlord (True Final Boss — 800 HP)
- Sourced from the **Demon Overlord 2D Pixel Art** pack (160 × 160 px authored sheets).
- **Phase I (800 &rarr; 520 HP)**:
  - *Hellsteel Cleave* (18 DMG, reach 160): Parryable overhead blade arc.
  - *Furnace Lunge* (30 DMG, reach 118): High-speed forward thrust.
  - *Flame Wave* (24 DMG): Floor-traveling flame wall that must be jumped.
- **Phase II (520 &rarr; 200 HP)**:
  - Phase threshold triggers an infernal cast animation.
  - Gains *Infernal Seals* (35 DMG, 110 reach): Vertical pillar seals erupting from the floor.
- **Phase III (200 &rarr; 40 HP)**:
  - Relentless tempo! Unlocks *Threefold Execution* (34 DMG): A lethal three-beat rhythm (*Dodge &rarr; Dodge &rarr; Parry!*).
- **Execution Phase — One Flash (40 HP)**:
  - Health locks at 40 HP; conventional damage ceases.
  - The screen darkens and the **Strike Now** prompt appears: **`PRESS F`**.
  - If mistimed, the Overlord unleashes a ground shockwave. Jumping over the wave grants a second chance.
  - Pressing `F` delivers the decisive execution blow, triggering the ancestral ink epilogue.

---

## Abilities & Soul Progression

### Ancestral Resurrection
- When health reaches zero with available charges, Ketsumei pulls Ilyen back from death.
- Each resurrection adds **+1 Soul Level** (up to Level 5), providing a permanent **+10% attack boost per level** (up to **+50%**).
- Automatic resurrection during boss fights preserves the boss's HP and phase!

### Ability Summary Table

| Ability | Key | Cost | Cooldown | Visual FX | Combat Function |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Phantom Step** | `E` | 20 Energy | 3.5s | Cyan spectral ghost | Extended invincible blink through enemy hitboxes. |
| **Soul Sever** | `U` | 25 Energy | 2.2s | Violet crescent wave | Fires a slicing projectile along the floor. |
| **Death Reversal** | `Q` | 100 Energy + 1 Charge | 25.0s | Crimson radial shockwave | Retaliatory 48-damage radial blast that staggers surrounding foes. |
| **Ancestral Echo** | `I` | 25 Energy | 5.0s | Golden spirit duplicate | Replicates next sword attack after 0.25s for 70% damage. |
| **One Flash** | `F` | Free | N/A | Kanji screen flash | Finishing strike triggered at 40 HP during the Overlord execution. |

---

## Asset Manifest & Provenance

All external assets are cataloged in [ASSET_MANIFEST.md](ASSET_MANIFEST.md):

- **Samurai Character (Ilyen)**: [CraftPix Free Samurai Pixel Art](https://craftpix.net/file-licenses/) (Freebie License).
- **Werewolves (Hunter & Brute)**: [CraftPix Free Werewolf Pixel Art](https://craftpix.net/file-licenses/).
- **Demon Overlord**: [Demon Overlord 2D Pixel Art v1.0.0](licenses/Demon-Overlord.txt).
- **Backgrounds (Moonwake & Sunset)**: Four-layer parallax backgrounds by Firepious ([Moonwake License](licenses/Moonwake.txt)).
- **Bridge & Platform Tiles**: [Free Bridges Top-Down Pixel Art Pack](licenses/CraftPix.txt).
- **Blood Impact VFX**: Pixel Art Blood Effect FX020 by **NYKNCK** ([nyknck.itch.io](https://nyknck.itch.io/bloodfx)).
- **Audio & SFX**: Sword slashes and impacts by DavidDumaisAudio (Pixabay License); wolf songs and atmospheres by Dragon Studio and Freesound community.
- **Ketsumei Blade**: Official team-approved custom pixel art (`17 × 60` grid, red hilt wrapping).
- **Hollow Sovereign**: Boss: Minotaur by chierit ([CC BY 4.0](assets/minotaur/ATTRIBUTION.txt)).

---

## Automated QA & Regression Test Suites

Bloodbound features an extensive automated test suite capable of headless execution at fixed 60 FPS:

```powershell
# 1. Clean import of all assets
godot --headless --editor --import --quit

# 2. Complete campaign playthrough test (105 checks through One Flash and victory)
godot --headless --fixed-fps 60 --script res://tests/smoke.gd

# 3. Weapon & Ketsumei sub-pixel alignment regression (25 poses in both directions)
godot --headless --script res://tests/weapon.gd

# 4. Boss sprite fallback validation
godot --headless --fixed-fps 60 --script res://tests/smoke.gd -- --no-art

# 5. Final duel with initial starting stats
godot --headless --fixed-fps 60 --script res://tests/smoke.gd -- --base-duel

# 6. Display & visual frame verification
godot --fixed-fps 60 --script res://tests/display.gd
```

See [TEST_REPORT.md](TEST_REPORT.md) for full test telemetry and pass logs.

---

## Building & Running the Game

### Play Immediately
- Run the compiled 64-bit Windows binary directly:
  ```powershell
  ..\Bloodbound.exe
  ```

### Run from Source in Godot
1. Open **Godot 4.5.1 Standard**.
2. Click **Import** and select `project.godot`.
3. Press **F5** to run.

---

*“I lowered Ketsumei. The blade was finally still.”*
