# BLOODBOUND · Windows release validation

## Project and assets

- Godot 4.5.1 Standard, GL Compatibility. The main scene remains `scenes/Throne.tscn` and the project uses no autoloads or video plugin.
- The arena drew the marked shrine clutter in repeated loops. Twelve supplied prop cutouts now sit on the same floor as the characters. Terrain, obstacles, exits, and bridge collision are independent of the new visuals. All twelve cutouts have binary alpha and zero opaque bright-magenta pixels. The original marked JPEGs are in `source-art/scenery/`.
- Ketsumei's source and runtime texture hashes match the prior build. A 60-pixel blade at 1.20× is 72 game pixels. Shinegen's idle silhouette is about 95 game pixels, so the blade is about 76% of his height. Hand markers and authored combat reach remain independent. Slash effect reach now follows combat reach.
- The opening uses the supplied Overlord strike frames, chest armor and stone overlays, and a planted-foot lean for the ground hit. The collapse moves four fortress pillars and two roof sections with timed cracks and debris. The permanent curse and heir teaser continue afterward.

## Opening video

The selected 6:30:37 AM clip contains embedded lore text and stereo AAC audio. The source is 1920 × 1080 H.264 at 30 fps and runs 10.01 seconds. The game plays a 1280 × 720 Ogg Theora and stereo Vorbis conversion on the Music bus. The original MP4 is preserved byte-for-byte. Godot 4.5.1 held this stream's last frame past its duration during testing, so a measured playback-position fallback advances the cutscene if the native completion signal is absent.

## Executed validation

| Test | Result |
| --- | --- |
| Godot headless editor import and fresh source archive import | Passed |
| Headless source campaign | 127 checks passed |
| Scripted OpenGL campaign | 128 checks passed, with 34 frame captures |
| Campaign with unavailable video | 125 checks passed through credits and a fresh run |
| Sword attachment | 27 poses in both directions and eight attack timings passed |
| Final Windows executable's embedded game pack | 127 campaign checks passed |
| Final embedded pack with OpenGL at 1024 × 768 window size | 42 display checks passed, including full video text, measurable video audio on the Music bus, a second video start, and video stop on Return to Title |
| Standalone Windows executable | Launched with OpenGL and exited normally |

Inspected frames of the shrine, chest and ground impacts, first-death caption, complete video text, fortress collapse, and sword in stone. The packaged campaign covered both bridge directions, the Skull Guardian, both werewolves, the Overlord's thresholds, One Flash, the curse, credits, and restart.

The same 240-frame OpenGL sample on the local RTX 4050 Laptop GPU measured median draw calls of 254 for the wolves and 251 for the fortress boss, down from 485 and 284 in the prior audit. The release samples measured 7.18 ms and 8.70 ms at the 95th percentile. These are short local samples.

## Known limits

The inputs were scripted. Human-input balance and a listening pass remain unverified. Capture confirmed that the clip plays audio through the game mixer. Dedicated footstep and collapse recordings were unavailable. The collapse uses existing impact and shatter cues. The new sheets and video arrived without separate licensing metadata, so confirm public distribution rights before publishing.

[Controls and launch instructions](README.md) · [Asset manifest and attributions](ASSET_MANIFEST.md) · [Story canon](STORY_CANON.md)
