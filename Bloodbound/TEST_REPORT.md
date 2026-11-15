# BLOODBOUND · The Between and final curse verification

The revision builds on prototype commit `0cc5694` in Godot 4.5.1. SHA-256 verification confirmed the approved Ketsumei source and gameplay texture retain their original bytes.

| Test | Observed result |
| --- | --- |
| Godot headless editor import and script parsing | Completed successfully for both the project and a fresh source ZIP extraction |
| Source campaign, headless | 121 checks passed through credits and a fresh run |
| Embedded Windows game pack, headless | 121 checks passed through credits and a fresh run |
| Scripted OpenGL campaign | 121 gameplay checks passed, with 30 captures. This full render preceded the final sword-descent adjustment, which was covered by the release display and headless tests |
| OpenGL display regression | 33 checks passed, including 13 frame captures |
| Final duel with initial stats | 14 checks passed, including One Flash and credits |
| Weapon regression | 25 poses in each direction plus eight attack timings passed |
| Windows executable | Started with OpenGL and exited normally |

The campaign combines scripted keyboard input with targeted setup for combat thresholds and checkpoint checks. It verifies the Demon Overlord in both encounters, the first and repeat visits to The Between, the four powers in order, the Phantom Step ward, the Soul Sever target, both bridges, and the coordinated wolf fight. It checks both boss phase thresholds, One Flash, the single curse activation, and the rejection of movement, attacks, resurrection, and retry during the curse. Body and spirit reach zero visibility before the sword is planted. Both sequel cards display in order. New Game starts a fresh run at 120 HP with the Demon Overlord as the opening villain.

Rendered frames were sampled for the off-white regression across the title, both versions of The Between, resurrection, both skip paths, the curse, sword placement, the future heir, credits, and the next run. The tests checked that both appearances of The Between render as a predominantly black scene and that One Flash's white pulse clears on its own. The complete route took about 4 minutes 16 seconds of simulated game time, including retry checks.

The fatal strike and heir teaser reuse imported sprites and in-engine poses. The voices in The Between and the ending use subtitles over existing sound cues. Human-controlled play and audio listening were outside this verification.

See [README.md](README.md) for launch and test commands, [ASSET_MANIFEST.md](ASSET_MANIFEST.md) for origins and licenses, and [ART_IMPORT_GUIDE.md](ART_IMPORT_GUIDE.md) for the Overlord's animation mappings.
