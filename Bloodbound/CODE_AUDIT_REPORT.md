# BLOODBOUND · Production audit

## Executive summary

Fixed the first werewolf parry, rejected invalid resurrection requests at the point of entry, and made ending skips apply the same final sword placement as the completed cinematic. Simplified the player attack update and reduced off-screen rendering. The Oda canon, combat tuning, and approved art are intact.

The audit started from the live `Bloodbound/` project in the `prototype` checkout at `0cc5694`. That checkout already held story revisions and rebuilt artifacts. A baseline archive, the previous Windows build, and the previous source ZIP are preserved under `work/audit2-baseline/`. Godot 4.5.1 Standard uses `scenes/Throne.tscn` as the main scene, with no autoloads or gameplay packages. The separate Requiem project is a prior edition.

## Analyzers used

| Tool | Command | Result |
| --- | --- | --- |
| GDToolkit 4.5.0 | `gdlint` over all active project scripts | 298 findings before, 294 after. Final findings were 219 line-length, 71 declaration-order, three public-method-count, and one file-length finding. |
| GDToolkit 4.5.0 | `gdradon cc` over the same scripts | Ran before and after. Inspected the highest-complexity functions and separated input commands and attack timing from player physics. |
| GDToolkit 4.5.0 | `gdformat --check` over the same scripts | Ran before and after. Formatted the shared strike helper and new test suite. Final check would reformat 21 scripts and leave two as written. |
| Godot 4.5.1 Standard | `godot --headless --editor --import --quit` | Baseline and fresh source archive imported without engine errors. Tested authored scene instantiation during campaign and unit runs. |
| GdUnit4 6.0.2 | `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://audit_suite --ignoreHeadlessMode -rd reports` | Baseline six tests produced seven failing assertions in three cases. Release suite passed all eight cases with zero failures, errors, skips, or orphans. JUnit XML was generated. |

The toolkit and GdUnit4 were installed in the audit workspace. The GdUnit4 compatibility table includes Godot 4.5.1 for the 6.0 series. [GDToolkit](https://github.com/Scony/godot-gdscript-toolkit) · [GdUnit4 compatibility](https://github.com/godot-gdunit-labs/gdUnit4#supported-godot-versions)

## Bugs fixed and files modified

| Files | Change |
| --- | --- |
| `strike.gd`, `enemy.gd`, `sovereign.gd` | Shared the per-channel hit registration. The first wolf counter's negative ID had collided with the sentinel for an unseen attack. Counters now use the attack's positive ID in their own channel. |
| `throne.gd`, `fighter_art.gd` | Validated the resurrection unlock, defeat, charges, and Death Reversal requirements before consuming resources. Completing or skipping the curse now erases the visible body and plants the original blade using one placement transform. |
| `heir.gd` | Split buffered commands and attack hit windows out of the movement step while retaining the authored timings and synchronous hit responses. |
| `arena.gd` | Culled decorative ash and grain outside padded camera bounds, including during camera zoom and shake. |
| `throne.gd`, `soundscape.gd` | Routed one confirmation cue per menu command and used the fallback track's own volume and start offset when a requested track is missing. |
| `tests/` | Added isolated GdUnit4 scene and boundary tests, including an early ending skip. Extended display verification for unavailable audio. The starting-stat duel now explicitly grants the story-required Ancestral Resurrection unlock. |

## Code simplification

Production script count stayed at 19. Nonblank production lines went from 4,832 to 4,854. Across production and tests, script count went from 22 to 23 and nonblank lines went from 5,631 to 5,793. The additions are primarily the new suite, camera culling, and explicit state guards.

GDRadon rated the player's `simulate()` at 37 before and 23 after. The extracted command and attack-window methods rated 10 and 7. Remaining hotspots include the director physics dispatch (35), interface paint (32), and fighter drawing (30). These coordinate many existing authored states and were inspected as part of the audit.

## Naming and security

The search for AI-tool names and identifier patterns found no project-owned gameplay names that needed renaming. The asset manifest and third-party terms retain factual attribution. A filename and text scan found no matching secret material, private configuration, network client, or debug endpoint in active game source and configuration. This was a pattern-based inspection.

Compared SHA-256 hashes for 76 PNG, MP3, and animation resources against the baseline. All matched, including the approved sword and its runtime texture.

## Gameplay and visual validation

- The baseline and release headless campaign each passed 121 checks. The Windows game pack independently passed 121 checks, and the Windows executable launched with OpenGL and exited normally.
- The scripted OpenGL campaign passed 122 checks and captured 30 frames. The release display suite passed 35 checks, up from 33.
- GdUnit4 covered damage at zero, one, lethal, and overkill values, plus the execution floor, exact phase boundaries, checkpoint restoration, repeat unlocks, the first wolf parry, resurrection guards, ending skip, and resets from the side boss, death, and pause.
- The rendered campaign and display runs exercised the title, opening strikes, The Between, both bridges, Skull Guardian, wolves, fortress boss, One Flash, the erased spirit, embedded sword, heir teaser, credits, and a fresh start. Inspected representative frames directly. The weapon suite checked 25 poses in each direction and eight strike timings.
- The optional boss-art fallback passed 92 checks. The starting-stat duel passed 14 checks, including credits. That fixture initially failed because it assumed resurrection was usable before the unlock. The corrected fixture grants the intended story unlock.

## Performance

Paired OpenGL samples on the local NVIDIA RTX 4050 Laptop GPU at the project's 1280 × 720 window size. The scripted sampler took 240 frames per scenario after warm-up, with VSync disabled. Timings are wall-clock render-frame intervals under that setup.

| Scenario | Median draw calls before → after | Median frame time | 95th percentile |
| --- | ---: | ---: | ---: |
| Werewolf encounter | 543 → 485 | 9.39 → 9.33 ms | 13.91 → 13.10 ms |
| Fortress boss phase 2 | 300 → 284 | 7.67 → 7.50 ms | 11.38 → 10.83 ms |

These short runs show reduced draw submission on this machine. The memory samples cover warm-up and one short window per encounter. They do not establish long-session stability or performance on lower-end hardware.

## Remaining issues

Default toolkit style warnings remain. The full route was driven by scripted inputs with some focused state setup. Human-input playthrough, audio listening, and a hardware compatibility matrix remain unverified. Missing optional audio falls back to the configured music or silence. A dedicated footstep asset is unavailable.

## How to run

Open `Bloodbound.exe` and select **New Game**. To edit, import `Bloodbound/project.godot` in Godot 4.5.1 Standard and press **F5**. Use `godot --headless --fixed-fps 60 -s res://tests/smoke.gd` for the campaign suite and `godot --fixed-fps 60 -s res://tests/display.gd` for the OpenGL checks.

For GdUnit4, copy the project to a QA directory, place the v6.0.2 `addons/gdUnit4` folder there, and copy `tests/gdunit/bloodbound_audit_test.gd` into a new `audit_suite/` folder. Import the QA copy and run the command in the analyzer table. The original suite is editor-ignored so Godot can import and export the game with its existing runtime dependencies.
