# Art import guide

Open the project in Godot 4.5.1. Put PNGs, audio, and Godot resources under `assets/`. See [ASSET_MANIFEST.md](ASSET_MANIFEST.md) for the current clips and their sources.

The game uses a 1280 × 720 canvas. The daytime 256 × 128 scenery is drawn at 5×, and the night 256 × 144 paintings at 6× to leave camera overscan. Both use nearest filtering and pixel-aligned background scroll. Character clips use separate collision dimensions and uniform scales per character. The interface stays at the full canvas resolution.

## Characters and animations

1. Use a transparent PNG sheet with uniform cells, or one PNG per frame with the same canvas size. For loose frames, use zero-padded names such as `hero_run_01.png`. Keep the feet on the same baseline, and leave room for the weapon and windup.
2. Create a **SpriteFrames** resource in Godot. Use **Add frames from a Sprite Sheet** for an atlas, or drag ordered PNGs onto the frame list. Save the resource as a `.tres` and assign its `res://` path to `[visual] frames` in `resources/heir.cfg`, `resources/sovereign.cfg`, or `resources/demon_overlord.cfg`.
3. Set `source_facing=1` for art drawn facing right and `source_facing=-1` for art drawn facing left. Adjust `scale` and `offset` until the feet sit on the floor. Use `filter="nearest"` for pixel art and `filter="linear"` for painted art. In the 1280 × 720 viewport, the placeholders occupy roughly 75 px of character height for the heir and 150 px for the Sovereign, excluding weapons.
4. Use the state name as the animation name, or map it under `[animations]`, for example `light_1="slash_forward"`. Start with 10–16 FPS for locomotion and 16–24 FPS for fast attacks. Loop idle and locomotion. Use one-shot clips for attacks, transformations, and death. Use `[visual] speed` and the per-state `[animation_speed]` section for playback speed.
5. For combat clips that should follow the gameplay clock, add their **state keys** to `[visual] phase_locked`. The renderer samples the clip across the state's normalized progress, honoring each SpriteFrames frame duration as a relative weight. This is how the supplied Minotaur winds up, swings on the active frames, and settles in recovery. The three Thronebreaker impacts use the beat offsets in `scripts/sovereign.gd`.

Hero keys include `idle`, `run`, `jump_start`, `rise`, `fall`, `land`, `dash`, `dodge`, `light_1`–`light_3`, `air`, `charge`, `heavy`, `parry`, `parry_success`, `hurt`, `knockback`, `death`, `resurrect`, `final_prepare`, `final_dash`, `final_strike`, `finish`, and `victory`. For the boss, use `cleave`, `slam`, `rush`, `teleport`, `ruin`, and `throne` for active attacks, and append `_wind` or `_recover` for either side of the active window. Other boss keys include `idle`, `walk`, `intro`, `turn`, `doom`, `doom_recover`, `stagger`, `crown_break`, `desperate`, `final_attack`, `execution_hit`, and `dissolve`.

A missing SpriteFrames resource, missing state mapping, or empty animation falls back to that actor's procedural body. Leave the frame path empty to preview it. Keep Ilyen's body frames free of baked weapon, scabbard, and sword glow pixels.

## Demon Overlord animation map

| Encounter action | Supplied frames |
| --- | --- |
| Reveal, pursuit, idle | Walk and idle |
| Hellsteel Cleave and Furnace Lunge | Sword attack windup, contact at source frame 7, recover |
| Flame Wave and Infernal Seals | Cast windup, release around source frames 4–5, recover |
| Threefold Execution | Sword attack replayed for three timed strikes |
| Phase changes and stagger | Cast with independent lighting, or hurt for stagger |
| One Flash | Held attack lead-in, hurt recoil, then the complete eight-frame death clip |

The profile uses `authored_death=true` to keep the full death sprite visible during the final beat. Other bosses continue to use their existing dissolve visuals.

## Ketsumei hand attachment

The approved artwork lives in `source-art/ketsumei/approved.png`. The 17 × 60 transparent gameplay texture is `assets/last_oath/heir/ketsumei.png`. It is upright, tip-first, with the grip at `Vector2(8.5,52.5)`. The `WeaponPivot` displays it with nearest filtering, uniform scale, and white modulation. Use that same texture in shots outside the gameplay camera.

In `resources/heir.cfg`, `[identity] weapon` sets the display name. The `[weapon] tracks` dictionary keys an animation or a specific gameplay pose. Each `Vector3(x,y,angle)` gives the hand in local atlas-cell pixels and clockwise degrees from the upright artwork. Add one marker per frame when replacing the body art. The renderer mirrors the complete transform for left-facing poses and interpolates the angle between frame markers. Keep the hand on the grip and the sword in the active swing at the attack's configured `start` time. Keep glow, trails, and spectral copies in the effects layer.

## Hero expressions

The hero rig accepts independent PNG textures under `[faces]` in `resources/heir.cfg` for `neutral`, `focused`, `hurt`, and `returning`. Draw each expression facing right and align it to the same 34 × 29 local rectangle. Empty paths use the editable face rig. A full hero SpriteFrames set can include its own expressions. The real-time opening uses `draw_blade` and `intro_slash` poses. The dash slash uses the first slash clip after a light attack during a dodge. `sever` emits its projectile at the attack impact in `[combat]`.

## Enemy sprites

Set `frames`, `offset`, `scale`, `source_facing`, `filter`, and `animations` in the matching enemy section of `resources/enemies.cfg`. Use the same SpriteFrames import workflow as for the hero. Map `idle`, `walk`, `stagger`, `death`, and each attack with `_wind` and `_recover` variants. Tune clip duration to the corresponding windup, active, and recovery times. The `body` setting controls collision independently of the artwork.

## Combat alignment

The body origin is at its feet. `[body] size` is independent of the art. In the heir's `[combat]` section, set each attack's `start`, `end`, and `total` in seconds, plus `reach` and `height`. For an FPS-driven clip, frame index 4 at 24 FPS starts at 0.167 seconds at 1× speed. For phase-locked animations, match frame weights to the fraction of the state duration at which the hit occurs.

The boss's `[attacks]` entries define `wind`, `active`, `recover`, `reach`, `height`, and `damage`. The player attacks and the boss's direct melee swings accept an optional `"offset":Vector2(x,y)` relative to the origin. Positive X points forward and negative Y moves upward. Run a debug build with `-- --dev` and use the F9 hitbox view to check the visual contact against the hitbox. Settings for projectiles and shockwaves are independent of the body artwork.

## Story, backgrounds, and sound

- In `resources/encounter.cfg`, each item in `[story] ending` specifies an illustration key, line, and duration. Add `track`, `cue`, or a `voice` resource path to start audio when the panel appears. Panel options include `background`, `foreground`, `mask`, `pan` as a Vector2, `zoom`, and a hero `animation` cue. Edit `[illustrations]` to point each key at a PNG or JPG. Panels with no illustration leave the live arena visible behind the dialogue. Use 1280 × 720 or larger and keep important details away from the edges to allow the camera to pan.
- Replace the active backgrounds with `[backgrounds]` paths for `courtyard`, `road`, `shrine`, `underworld`, `frozen`, and `throne`. World Y=572 is the floor. `[visual] background_opacity` blends replacement textures into their procedural environment.
- Set keys in `[audio]` to imported WAV, OGG, or MP3 paths. Sound effects play once. The music player loops MP3 tracks and accepts the import loop settings for other formats. Missing audio paths are silent. `[music_db]` and `[music_start]` accept overrides per cue in dB and seconds. `[music_settings] fade_db_per_second` controls the fade rate.
- Set `charge_limit` in `resources/player_progression.tres`. Set `[resurrection]` for duration, return timing, and post-return invulnerability. Adjust Death Reversal damage, radius, and cooldown in the same section. Set `[timing]` for the opening death, afterlife, and Final Flash. Keep `soul_departure < soul_return < awakening_flash < awakening_total` and `final_freeze < final_slash < final_shatter < final_victory`.
- Edit `resources/oath_gradient.tres` to tune the gradient used for awakened swings and Final Flash. Its colors were sampled from the supplied VFX reference.

The supplied [Boss: Minotaur](https://chierit.itch.io/boss-minotaur) sheet is by chierit under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The game slices, mirrors, scales, tints, and retimes the frames. The source atlas and attribution are in `assets/minotaur/`.
