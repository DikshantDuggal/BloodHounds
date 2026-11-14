# BLOODBOUND — REQUIEM OF THE FALLEN

Ilyen carries Honjō Masamune through six levels. The Hollow Sovereign kills the heir in the Fallen Courtyard and departs before the blade draws Ilyen’s soul back. The journey ends with a rematch at the Throne of the Eclipse.

## Play on Windows

Open **Bloodbound.exe** and select **Begin**. To edit the game, import **project.godot** in Godot 4.5.1 Standard and press **F5**.

| Key | Action |
| --- | --- |
| A / D or ← / → | Move |
| Space or ↑ | Jump. Release early for a shorter jump |
| J | Slash. Tap again to chain a combo |
| K | Heavy strike. Hold and release with 25 energy for a charged slash |
| Shift | Dodge in the movement direction |
| L | Parry just before impact. A perfect parry strengthens the counter |
| E | Phantom Step |
| U | Soul Sever |
| Q | Death Reversal |
| I | Arm Ancestral Echo, then attack |
| F | One Flash during its cue |
| Enter | Confirm or skip a cinematic |
| Esc | Pause or resume |
| R | Retry from the latest checkpoint after game over |

## Progression

| Level | Location and encounter | Entry HP | Unlock at the encounter |
| --- | --- | ---: | --- |
| 1 | Fallen Courtyard · first Sovereign encounter | 120 | Ancestral Resurrection |
| 2 | Ashen Road · Ashen Warden | 140 | Phantom Step |
| 3 | Shrine of Fading Names · Veiled Spirit | 160 | Soul Sever |
| 4 | Underworld Gate · Underworld Guardian | 180 | Death Reversal |
| 5 | Frozen Oath · Frozen Rival | 200 | Ancestral Echo |
| 6 | Throne of the Eclipse · Hollow Sovereign | 220 | One Flash |

Entering the next level raises maximum health and heals you. Unlocks refill health and charges. Phantom Step, Soul Sever, Ancestral Echo, and charged slashes share the ability energy pool. Death Reversal spends the full pool and one resurrection charge. Hit enemies or parry to regain energy.

Resurrection increases attack power by ten percentage points per soul level, up to +50%. Automatic resurrection keeps boss HP and phase. Retry reloads your saved level, unlocks, soul level, energy, and defeated enemies from the last checkpoint, refills health and charges, and resets the unfinished encounter. This limits power growth from repeated game-over loops.

The Sovereign changes phases at 520 and 200 HP. At 40 HP, ordinary attacks stop reducing its health and One Flash begins. After the prompt appears, press **F** to finish the fight. A missed attempt returns after a shockwave.

## Art, audio, and tuning

The [art import guide](ART_IMPORT_GUIDE.md) covers the replaceable face layers, sprite sequences, backgrounds, and audio. The character rig, cutscenes, and environmental art use editable placeholders. The supplied Minotaur atlas by chierit animates the Sovereign. [Original sprite pack](https://chierit.itch.io/boss-minotaur) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

Edit `resources/player_progression.tres` for HP, attack growth, abilities, and charge and energy limits. Enemy health, damage, timing, and phase patterns are in `resources/enemies.cfg` and `resources/sovereign.cfg`. Change player attack timing and movement in `resources/heir.cfg`.

## Test and export

Run these from the project directory with the Godot 4.5.1 console executable on your PATH.

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd
godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd -- --no-art
godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd -- --base-duel
```

The smoke suite drives the six-level campaign and checks attack deduplication, power unlocks, resurrection, checkpoints, boss transitions, and victory. The fallback run uses a missing boss sprite path. The base duel bypasses the route to play the final fight with starting stats.

Install matching Godot export templates and export with the **Windows Desktop** preset. The engine and third-party notices are under `licenses/`.
