# BLOODBOUND — REQUIEM OF THE FALLEN

> *"A clan once kept watch over the passage between life and death. They entrusted that passage to Honjō Masamune. The Hollow Sovereign came for the blade. The courtyard burned. Under the ashes, one heir still breathed."*

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.5.1_Standard-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows_Desktop_x86__64-0078d7?logo=windows&logoColor=white)](https://github.com/DikshantDuggal/BloodHounds)
[![Renderer](https://img.shields.io/badge/Renderer-GL_Compatibility-green)](#technical-architecture)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](licenses/Godot-LICENSE.txt)
[![Art Attribution](https://img.shields.io/badge/Art_Attribution-CC_BY_4.0-orange)](assets/minotaur/ATTRIBUTION.txt)

---

## Table of Contents
1. [Overview](#overview)
2. [Story & Narrative](#story--narrative)
3. [Combat System & Core Mechanics](#combat-system--core-mechanics)
4. [Controls Reference](#controls-reference)
5. [Campaign Progression & Level Walkthrough](#campaign-progression--level-walkthrough)
6. [Enemies & Boss Encounters](#enemies--boss-encounters)
7. [Abilities & Soul Progression](#abilities--soul-progression)
8. [Technical Architecture](#technical-architecture)
9. [Automated QA & Headless Testing](#automated-qa--headless-testing)
10. [Building & Running the Game](#building--running-the-game)
11. [Licenses & Credits](#licenses--credits)

---

## Overview

**BLOODBOUND — REQUIEM OF THE FALLEN** is a precision 2D dark fantasy combat action game developed in **Godot Engine 4.5.1**. Emphasizing fluid swordplay, high-stakes parry timing, dynamic boss phase choreography, and an ancestral resurrection system, the game puts players in the sandals of **Ilyen**, the sole remaining heir of a fallen clan guardian order.

Armed with the legendary spirit blade **Honjō Masamune**, Ilyen must cross five perilous transitional domains to confront **The Hollow Sovereign** atop the Throne of the Eclipse and break the cycle of tragedy.

---

## Story & Narrative

Long ago, an ancient clan maintained equilibrium across the threshold separating the living from the dead. Their sacred duty was bound to **Honjō Masamune**, a masterwork blade capable of anchoring a soul across mortality.

Seeking absolute dominion over souls and death, **The Hollow Sovereign** descended upon the clan's ancestral home with his cursed greatsword **Grave Meridian**. In the ensuing massacre, the courtyard burned, the guardians fell, and Ilyen was slain before the Sovereign's throne.

Yet death refused to claim the heir. Through Honjō Masamune's latent resonance, Ilyen's soul returned to flesh. Wounded but resolute, Ilyen embarks on a pilgrimage through the ruins of memory and ash to fulfill the last oath.

---

## Combat System & Core Mechanics

The combat engine is built around responsive movement, attack chaining, stamina-free yet energy-metered special arts, and frame-accurate defense windows:

### 1. Melee Combat & Combos
- **Combo String (`J`)**: Ilyen chains up to three consecutive strikes on the ground (`light_1` &rarr; `light_2` &rarr; `light_3`), ending in an extended-reach finisher with an increased damage multiplier (1.6×).
- **Aerial Slash (`Air + J`)**: A sweeping airborne slash designed for engaging flying or elevated foes and interrupting leap attacks.
- **Heavy Slash (`K`)**: A slower, high-impact cleave dealing 1.8× baseline damage.
- **Charged Strike (`Hold K with ≥ 25 Energy`)**: Consumes 25 Ability Energy to unleash an ultra-wide (178px reach), 1.52× power charged strike capable of staggering high-poise adversaries.

### 2. Defensive Arts
- **Directional Dash / Dodge (`Shift`)**: Grants brief invulnerability frames (iframes) to slip through melee arcs and enemy rush trajectories.
- **Active Parry (`L`)**: Raising Honjō Masamune just before an incoming strike deflects the blow, nullifies incoming damage, negates knockback, and restores **+27 Ability Energy**.
- **Perfect Parry Window (0.065s)**: Deflecting within the first 65 milliseconds of the parry stance triggers a **Perfect Parry**, causing screen freeze, visual spark bursts, massive posture stagger to the attacker, and reflecting counter-damage multiplied by the critical factor (`1.5×`).

### 3. Ability Energy Pool
- Ability Energy spans from **0 to 100**.
- Energy is earned by landing melee slashes (+8 to +10 per strike) and successfully deflecting strikes via parry (+27 per parry).
- Shared pool fuels:
  - **Phantom Step** (20 Energy)
  - **Soul Sever** (25 Energy)
  - **Ancestral Echo** (25 Energy)
  - **Charged Heavy Slash** (25 Energy)
  - **Death Reversal** (100 Energy + 1 Resurrection Charge)

### 4. Deduplication & Damage Calculation
- **Damage Math**:
  $$\text{Damage} = \max\left(1, \text{round}\left(\text{BaseAttack} \times \text{Multiplier} \times (1 + 0.10 \times \text{SoulLevel})\right)\right)$$
- **Hit Channel Deduplication**: The engine uses a custom token-based tracking architecture (`scripts/strike.gd`) across independent channels (`melee`, `sever`, `echo`, `reversal`, `counter`). This guarantees multi-frame collision boxes register exactly once per attack swing, preventing erratic multiple-hit damage spikes.

---

## Controls Reference

| Key Binding | Action | Description |
| :--- | :--- | :--- |
| **`A` / `D`** or **`←` / `→`** | Move | Smooth ground locomotion with acceleration & turn damping |
| **`Space`** or **`↑`** | Jump / Leap | Variable-height jump; release early for a low hop |
| **`J`** | Light Attack | Tap to strike; tap rhythmically to chain the 3-hit combo |
| **`K`** | Heavy Attack | Single heavy strike; hold to charge if energy is available |
| **`Shift`** | Dash / Dodge | Directional evade granting brief invulnerability frames |
| **`L`** | Parry / Guard | Timed guard against parryable attacks; 65ms perfect window |
| **`E`** | Phantom Step | Rapid long-range warp dash through enemy hitboxes *(Unlocked Lv. 2)* |
| **`U`** | Soul Sever | Long-range crescent shockwave projectile *(Unlocked Lv. 3)* |
| **`Q`** | Death Reversal | Emergency resurrection blast dealing 48 damage *(Unlocked Lv. 4)* |
| **`I`** | Ancestral Echo | Arms spirit shadow to repeat next attack after 0.25s *(Unlocked Lv. 5)* |
| **`F`** | One Flash | Decisive final cinematic finisher during prompt *(Unlocked Lv. 6)* |
| **`Enter`** | Confirm / Skip | Advances dialogues, skips cutscenes & cinematics |
| **`Escape`** | Pause | Opens pause overlay and access to audio volume settings |
| **`R`** | Retry | Restores state from latest checkpoint after defeat |

---

## Campaign Progression & Level Walkthrough

The journey spans six progressively challenging domains. Transitioning between levels elevates Ilyen's maximum health pool, refills all resurrection charges, and unlocks new combat abilities:

```
[Level 1: Courtyard] ──> [Level 2: Ashen Road] ──> [Level 3: Shrine]
       (120 HP)                  (140 HP)                 (160 HP)
          │                          │                        │
  Ancestral Resurrect          Phantom Step              Soul Sever
          │                          │                        │
          ▼                          ▼                        ▼
[Level 4: Underworld] ──> [Level 5: Frozen Oath] ──> [Level 6: Throne]
       (180 HP)                  (200 HP)                 (220 HP)
          │                          │                        │
    Death Reversal            Ancestral Echo              One Flash
```

### Detailed Area Breakdown

| Level | Realm Name | Entry HP | Major Encounters | Reward / Unlock |
| :---: | :--- | :---: | :--- | :--- |
| **1** | **The Fallen Courtyard** | **120 HP** | Scripted duel with The Sovereign | **Ancestral Resurrection** |
| **2** | **The Ashen Road** | **140 HP** | 2× Shadow Remnants, The Ashen Warden | **Phantom Step (`E`)** |
| **3** | **The Shrine of Fading Names** | **160 HP** | Shadow Remnants, The Veiled Spirit | **Soul Sever (`U`)** + Clan Memorial |
| **4** | **The Underworld Gate** | **180 HP** | Gatekeeper Remnants, Underworld Guardian | **Death Reversal (`Q`)** |
| **5** | **Frozen Oath** | **200 HP** | Glacial Remnants, The Frozen Rival | **Ancestral Echo (`I`)** |
| **6** | **The Throne of the Eclipse** | **220 HP** | The Hollow Sovereign (3-phase climax) | **One Flash (`F`)** |

---

## Enemies & Boss Encounters

Every adversary features custom telegraphs, windup animations, active swing windows, and distinct vulnerability windows:

### 1. Minions & Gatekeepers
- **Shadow Remnant (40 HP)**: Fast-skulking shade executing *Ravenous Cut*. Susceptible to stagger on hit.
- **The Ashen Warden (250 HP)**: Heavily armored juggernaut wielding an executioner polearm.
  - *Executioner's Fall*: Slow overhead smash.
  - *Ashen Rift*: Ground rupture wave that must be jumped.
  - *Iron Procession*: Unrelenting forward charge that can be parried or dodged.
- **The Veiled Spirit (350 HP)**: Ethereal mystic dancing between realms.
  - *Three Forgotten Names*: Rapid 3-slash combination requiring rhythmic deflections.
  - *Veil Step*: Instantaneous repositioning with gold marker telegraph.
  - *Wandering Grief*: Floating, slow homing soul orb.
- **The Underworld Guardian (450 HP)**: Colossal sentinel of the nether passage.
  - *Gatekeeper's Blade*, *Pyre Break* (ground fire wave), *Three Tolls* heavy combo.
- **The Frozen Rival (550 HP)**: Agile swordsman wielding frost-imbued twin steel.
  - *Frostbite Combo*, *Ice Veil* dash, *Winter's Mirror* teleport slash.

### 2. The Climax: The Hollow Sovereign (800 HP)
The Sovereign commands the Throne of the Eclipse across three distinct phases and an execution climax:

1. **Phase I — The Awakened Duel (800 &rarr; 520 HP)**:
   - Uses *Void Cleave* (horizontal arc), *Eclipse Slam* (dual shockwave), and *Shadow Rush*.
2. **Phase II — The Broken Crown (520 &rarr; 200 HP)**:
   - Phase threshold triggers a crown-shattering cinematic.
   - Gains *Falling Ruin* (vertical blade bombardment from the sky), *Eclipse Step* teleportation, and *Thronebreaker* (a terrifying three-beat combo: *Beat 1 Dash &rarr; Beat 2 Dash &rarr; Beat 3 Parry!*).
3. **Phase III — The Final Oath (200 &rarr; 40 HP)**:
   - High-tempo, reduced windups, elevated aggression, and heightened stagger recovery. Ilyen's blade turns pure white.
4. **Execution Phase — One Flash (40 HP)**:
   - Sovereign's health locks at 40 HP; conventional strikes deal zero damage.
   - The camera zooms in as the screen darkens into the **One Flash** prompt: `PRESS F`.
   - **Last Chance Mechanic**: If the player fails to react in time, the Sovereign repels Ilyen with a ground shockwave. Leaping over this shockwave grants a second opportunity to execute One Flash!
   - Pressing **`F`** triggers the blinding final slash, ancestral spirit figures materialize to hold the oath, and the Sovereign dissolves in an ink shockwave.

---

## Abilities & Soul Progression

### Ancestral Resurrection
- When health reaches zero with available charges, Honjō Masamune pulls Ilyen back from the veil.
- **Soul Power**: Each resurrection grants **+1 Soul Level** (capped at Level 5), permanently raising attack strength by **+10% per level** (up to a **+50% attack boost**).
- During automatic resurrection in boss fights, the boss's HP and phase are preserved!

### Ability Mechanics Table

| Ability | Key | Cost | Cooldown | Visual FX | Combat Function |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Phantom Step** | `E` | 20 Energy | 3.5s | Cyan spectral ghosting | Blinks forward at 1080 px/s with invulnerability; repositions through bosses. |
| **Soul Sever** | `U` | 25 Energy | 2.2s | Violet crescent wave | Fires a slicing projectile that travels 540 px/s across the arena floor. |
| **Death Reversal** | `Q` | 100 Energy + 1 Charge | 25.0s | Crimson radial shockwave | Delivers an immediate 48-damage blast in a 190px radius, knocking back foes. |
| **Ancestral Echo** | `I` | 25 Energy | 5.0s | Golden silhouette echo | Charges Ilyen's next sword attack to be duplicated after a 0.25s delay for 70% damage. |
| **One Flash** | `F` | None | N/A | White screen flash & kanji-style cut | Cinematic finisher triggered exclusively in the Sovereign's execution window. |

---

## Technical Architecture

The Bloodbound codebase is designed for modularity, data-driven balance, zero runtime allocation spikes, and graceful procedural fallbacks:

```
Bloodbound/
├── assets/
│   └── minotaur/                 # Boss sprite sheet & CC BY 4.0 attribution
│       ├── ATTRIBUTION.txt
│       ├── sheet.png
│       └── sovereign_frames.tres
├── licenses/                     # Engine and open-source license documentation
│   ├── Godot-COPYRIGHT.txt
│   └── Godot-LICENSE.txt
├── resources/                    # Data-driven configuration profiles (.cfg & .tres)
│   ├── encounter.cfg             # Dialogue lines, timings, audio mappings & story panels
│   ├── enemies.cfg               # Complete enemy stats, attack boxes & patterns
│   ├── heir.cfg                  # Player speed, jump gravity, hitboxes & weapon rects
│   ├── oath_gradient.tres        # Color ramp for awakened swings and VFX
│   ├── player_progression.tres   # HP by level, energy limits & unlock sequences
│   └── sovereign.cfg             # Boss health, phases, telegraphs & attack definitions
├── scenes/                       # Godot PackedScene definitions
│   ├── Enemy.tscn                # Standard enemy instance
│   ├── Heir.tscn                 # Player character instance
│   ├── InkCutscene.tscn          # Procedural ink-wash cutscene canvas
│   ├── Sovereign.tscn            # Boss character instance
│   └── Throne.tscn               # Master game world & stage coordinator
├── scripts/                      # Core GDScript game logic
│   ├── arena.gd                  # Arena bounds, parallax mountains & scenery rendering
│   ├── bindings.gd               # InputMap key registration
│   ├── camera_director.gd        # Dynamic camera framing, zoom & screen rumble
│   ├── damage.gd                 # Clamping & arithmetic damage helpers
│   ├── effects.gd                # Particle bursts, arcs, ghosts & hitbox debug draws
│   ├── enemy.gd                  # Route enemy state machine & attack dispatch
│   ├── fighter_art.gd            # Sprite rendering & procedural vector character rig
│   ├── heir.gd                   # Player physics, combo buffers, jump coyote & iframes
│   ├── ink_cutscene.gd           # Traditional Japanese ink-and-paper cutscene renderer
│   ├── interface.gd              # Heads-Up Display (HUD), menus, boss gauges & modal UI
│   ├── journey.gd                # Area transitions, enemy wave spawner & checkpoints
│   ├── player_stats.gd           # Level scaling, soul caps, snapshots & restore logic
│   ├── powers.gd                 # Ability cooldowns, projectile waves & echo logic
│   ├── profile.gd                # ConfigFile wrapper with safe fallback handling
│   ├── soundscape.gd             # Audio manager & real-time procedural audio synthesizer
│   ├── sovereign.gd              # Sovereign 3-phase AI state machine
│   ├── story.gd                  # Timed cutscene timeline player
│   ├── strike.gd                 # Hitbox token & multi-hit deduplication model
│   └── throne.gd                 # Master orchestrator & cinematic event sequencer
├── tests/
│   └── smoke.gd                  # Automated headless regression & full-route test suite
├── .gitignore                    # Godot 4 editor cache exclusion rules
├── ART_IMPORT_GUIDE.md           # Instructions for replacing procedural art with custom sheets
├── export_presets.cfg            # Windows Desktop standalone build preset
└── project.godot                 # Godot Engine project definition
```

### Key Architectural Highlights
1. **Procedural Audio Synthesizer (`scripts/soundscape.gd`)**:
   - If audio files are missing, the engine automatically falls back to an integrated, algorithmic 16-bit 22.05 kHz audio synthesis engine!
   - Synthesizes blade whooshes (`swing`), metal impacts (`hit`), parry clangs (`parry`), low ground rumbles (`slam`), and harmonic ambient musical melodies using sine, exponential envelopes, and frequency modulation.
2. **Procedural Vector Rig (`scripts/fighter_art.gd`)**:
   - When external SpriteFrames are absent, all characters and bosses are procedurally drawn using 2D canvas primitives, bezier curves, joint rotations, moving cloaks, and responsive eye tracking.
3. **Japanese Ink Cutscene Engine (`scripts/ink_cutscene.gd`)**:
   - Renders story cinematics on an authentic paper-and-ink canvas (`#e3d6bc` wash with `#292527` calligraphy strokes and crimson highlights), complete with procedural brush sweeps, mountain silhouettes, and animated ink dispersal.

---

## Automated QA & Headless Testing

The project includes an enterprise-grade automated test runner located at `res://tests/smoke.gd`. It drives simulated player input at fixed 60 FPS physics ticks to verify game integrity without requiring human interaction.

To run tests from the command line using Godot 4.5.1:

```powershell
# 1. Clean import assets in headless mode
godot --headless --path . --editor --import --quit

# 2. Run the complete 6-level campaign test suite
godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd

# 3. Test procedural fallback rendering without sprite assets
godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd -- --no-art

# 4. Direct final duel combat verification with starting stats
godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd -- --base-duel
```

### Verified Test Cases
- New game starting statistics, health clamping, and level progression up to 220 HP.
- Soul level damage scaling capped at +50%.
- Choreographed intro skip safety and cinematic pacing.
- Checkpoint persistence, health refills, and retry state preservation.
- Hitbox deduplication on single-strike instances.
- Multi-phase Sovereign transitions at 520 HP, 200 HP, and 40 HP execution lock.
- One Flash timing window, Last Chance shockwave recovery, and cinematic execution.

---

## Building & Running the Game

### Play Immediately on Windows
- A standalone, pre-built Windows 64-bit executable is included in the release:
  ```powershell
  ..\Bloodbound.exe
  ```

### Run from Source in Godot Editor
1. Download and install **Godot Engine 4.5.1 Standard** (available at [godotengine.org](https://godotengine.org)).
2. Launch Godot, click **Import**, and select `project.godot`.
3. Press **F5** (or click the Play button in the top right corner) to start the game.

### Exporting to Executable
1. Open the project in Godot 4.5.1.
2. Navigate to **Project &rarr; Export...**.
3. Select the **Windows Desktop** preset configured in `export_presets.cfg`.
4. Click **Export Project** and choose the destination binary path.

---

## Licenses & Credits

- **Game Engine & Source Code**: Released under the [MIT License](licenses/Godot-LICENSE.txt).
- **Godot Engine**: Copyright (c) 2014-present Godot Engine contributors; released under the [MIT License](licenses/Godot-LICENSE.txt).
- **Minotaur Boss Atlas**: Created by **chierit** ([Boss: Minotaur on itch.io](https://chierit.itch.io/boss-minotaur)); licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). See `assets/minotaur/ATTRIBUTION.txt`.
- **Honjō Masamune Lore**: Inspired by legendary Japanese swordsmith **Gorō Nyūdō Masamune** and the celebrated historic blade passed through the Tokugawa shogunate.

---

*“I lowered Honjō Masamune. The blade was finally still.”*
