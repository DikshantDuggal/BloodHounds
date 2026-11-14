# BLOODBOUND · Boss roster and restart verification

The existing Godot 4.5.1 project was updated in place. A recoverable Git snapshot was taken before editing at commit `e587621`. The SHA-256 hashes of both the approved Ketsumei source and the transparent gameplay texture match that snapshot.

| Test | Observed result |
| --- | --- |
| Godot headless editor import and script parsing | Completed successfully for both the project and a fresh source ZIP extraction |
| Source campaign, headless | 105 checks passed |
| Embedded Windows game pack, headless | 105 checks passed through One Flash, victory, and a fresh run |
| Scripted OpenGL campaign | 105 gameplay checks passed through victory and reset. Saved 22 frames for visual inspection |
| OpenGL display regression | 22 checks passed, including nine frame captures |
| Boss sprite fallbacks | 75 checks passed through victory with both animations disabled |
| Final duel with initial stats | 14 checks passed, including One Flash and victory |
| Weapon regression | 25 poses in each direction plus eight attack timings passed |
| Windows executable | Started with OpenGL and exited normally |

The campaign suite combines keyboard input with targeted setup for health thresholds, resurrections, and retries. It covered the morning departure and resurrection, both bridge crossings, the forest Hunter, the 350 HP Hollow Sovereign rematch, the 150 and 220 HP wolves coordinating attacks, post-wolf retry and gate state, and the 800 HP Demon Overlord. It observed all five Overlord attacks, checked representative damage values (18, 30, 37, and 40 HP), and verified that a single overkill hit resolves the 65% and 25% phase transitions exactly once before opening the execution at 40 HP.

The display test sampled the rendered title, opening, awakening, resurrection and skip paths. It also covered white flash expiry, pausing during a flash, and restarting. Return to Title discarded the run and its checkpoints. Begin restored 120 HP, initial abilities, full boss health, and the ruined village opening. In this restricted test environment, an unredirected OpenGL launch could log a shader-cache folder warning and still render. With the user-data folder redirected to a writable test folder, the standalone launch and display tests logged no such warning.

The 350 HP shrine rematch took 45.3 seconds of scripted combat. The complete route took about 3 minutes 58 seconds of simulated game time with the regression setup and retry checks. A human-controlled playthrough and an audio listening pass were outside this verification. The supplied Demon Overlord cast is reused for its phase changes. Available sound cues were reused where appropriate, and unavailable dedicated creature sounds are silent.

See [README.md](README.md) for launch and test commands, [ASSET_MANIFEST.md](ASSET_MANIFEST.md) for origins and licenses, and [ART_IMPORT_GUIDE.md](ART_IMPORT_GUIDE.md) for the Overlord's animation mappings.
