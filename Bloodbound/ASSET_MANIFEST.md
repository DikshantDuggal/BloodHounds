# BLOODBOUND · Asset manifest

The supplied archives were opened and inspected. Original archives were left in place. Imported files live under `res://assets/last_oath/` unless noted.

| Original archive | Inspected content | Runtime use and import path |
| --- | --- | --- |
| `Sunset.zip` | Ten 256 × 128 PNGs. Opaque sky and composite preview, with transparent cloud, sun, and six ridge/forest layers | `sunset/*.png`. Nine layers for morning, afternoon, and the fade into Moonlit Pass. No author or license file was supplied. This build is for the asset-supplying team. Confirm the original terms before public distribution. |
| `moonwake.zip` | Four opaque 256 × 144 backgrounds, their 4× versions, a contact sheet, README, and license | `01_the_rise.png` for Moonlit Pass, `03_the_veil.png` at the wolves' gate, `02_the_vigil.png` at the fortress, and `04_the_wane.png` for the ending. Author Firepious. The [original license](licenses/Moonwake.txt) includes permission to ship in a game and the creator's provenance disclosure. |
| `Free-Bridges-Top-Down-Pixel-Art-Asset-Pack.zip` | Transparent 656 × 672 atlas, Tiled sample, water variants, PSDs, and license link. The Tiled sample uses 16 × 16 tiles | `stone_bridge.png`, `wood_bridge.png`, `rock_platform.png`. Cropped side-facing parts of the atlas for two bridge decks and raised stone platforms. Native Godot collision supports both directions. |
| `craftpix-net-123681-free-samurai-pixel-art-sprite-sheets.zip` | Three characters, transparent 128 × 128 cells in horizontal strips, PSDs, and license link | `heir/frames.tres` uses Samurai (idle 6, run 8, jump 9, guard 2, attack strips 4/5/4, hurt 3, death 6). The Commander (former Ashen Warden) and Archer (former forest Remnants) resources and configurations are archived in `source-art/unused/`. They can be restored by returning their folders to `assets/last_oath/` and reusing the archived configuration sections. Clip ranges split windup from impact. Ilyen's resurrection uses reverse death frames. |
| `free-werewolf-sprite-sheets-pixel-art.zip` | Black, red, and white variants, transparent 128 × 128 cells. Each has 8 idle, 9 run, 11 walk, 11 jump, 7 running attack, 6/4/5 claws, 2 hurt, and 2 death frames | `hunter/frames.tres` uses black idle/run, running attack, second claw, hurt and death. `brute/frames.tres` uses red idle/walk, first and third claws, hurt and death. The white variant stays in the source archive. |
| `daviddumaisaudio-sword-slash-and-swing-185432.zip` | Nine MP3s, all loaded in Godot and checked for positive duration | `audio/*.mp3`. See the cue map below. |
| `B000_nyknck.zip` | Ten sequential, nonempty 64 × 24 transparent PNGs (`B001`–`B010`) | `blood_impact.png`. Ten-frame impact and scripted-death effects. Pixel Art Blood Effect FX020 by **NYKNCK (@nyk_nck)**. [Publisher and credit requirement](https://nyknck.itch.io/bloodfx). |
| User-supplied official Ketsumei artwork | Original 453 × 1600 opaque PNG, byte-for-byte under `source-art/ketsumei/approved.png` | `heir/ketsumei.png` is a transparent reconstruction of the 17 × 60 source pixel grid using original cell colors. The same texture drives hand poses, the dropped weapon, cutscene art, and spectral VFX. The samurai body atlas copies have their embedded equipment removed. |
| `mino_v1.1_free.zip` | Transparent 4608 × 480 Minotaur atlas, matching the existing imported PNG byte for byte. The source lists idle, walk, and attack | `res://assets/minotaur/sovereign_frames.tres`. The Hollow Sovereign appears in the morning and returns as the afternoon side boss. [Attribution and CC BY 4.0](assets/minotaur/ATTRIBUTION.txt). |
| `Demon Overlord 2D Pixel Art v1.0.0.zip` | Six transparent 8-frame strips, with 160 × 160 cells in the Godot edition and 320 × 320 cells in the high-resolution edition. Idle, walk, sword attack, cast, hurt, and death | `res://assets/demon_overlord/demon_overlord_frames.tres`. The true final boss uses the original 160 px sheets. The [original license](licenses/Demon-Overlord.txt) permits use in games and prohibits standalone asset redistribution. It discloses machine-generated base frames with manual cleanup and alignment. |

CraftPix's [freebie license](https://craftpix.net/file-licenses/) allows use in personal and commercial games. The team project also retains the archived Commander and Archer variants for future use. Keep the loose source art inside the authorized team workflow and distribute the packaged game to players. [Included license link](licenses/CraftPix.txt)

The license pointers, coupon art, coupon PDFs, and some accompanying links were byte-identical across CraftPix archives. Duplicate basenames such as `Idle.png` refer to different characters and are isolated by import folder. Moonwake's matching 1× and 4× names are separate resolutions. No blank cells were found in the animation ranges used. The top-down water previews have numbering gaps and are unused. The original Photoshop and Tiled files, unused clips, coupons, and alternate resolutions stay in their archives.

## Audio cue map

| Source | Duration | Usage |
| --- | ---: | --- |
| DavidDumaisAudio · Sword Slash and Swing · 185432 | 1.58 s | Sword draw, swing, One Flash release |
| DavidDumaisAudio · Sword Slash with Metallic Impact · 185435 | 1.63 s | Impact, parry, execution shatter |
| Dragon Studio · Haunting Wolf Song · 515269 | 7.10 s | Title, celestial vision, wolves' gate approach, ending, victory |
| Dragon Studio · Spooky Sound · 410562 | 2.42 s | Initial death, boss reunification, buildup |
| Dragon Studio · Spooky Transition · 401719 | 3.31 s | Awakening, gate opening, phase change |
| Dragon Studio · Spooky Wolf Howl · 410547 | 4.10 s | Wolves first come into view |
| Freesound Community · Spooky Ambience · 49850 | 194.35 s | Village, forest, shrine, pass and Abyss |
| fronbondi_skegs · Frenzied Panic-Stricken Riser · 251191 | 26.78 s | Boss transformation cue |
| tatamusic · Battle Warrior Fighting Drums · 478210 | 44.75 s | First encounter, shrine, wolves and final phases, with per-cue start points and gain |

Source credits are recorded using the archive's filenames. The publisher marks the [sword swing](https://pixabay.com/sound-effects/film-special-effects-sword-slash-and-swing-185432/) as usable under the [Pixabay Content License](https://pixabay.com/service/license-summary/). The supplied audio archive had no separate license file.

The Demon Overlord pack supplies no separate transformation, cinematic close-ups, or audio. Phase changes use its cast frames with lighting and existing audio cues. The wolves use the supplied howl and swing sounds. Dedicated footstep, death, and creature reaction sounds are unavailable. Other gaps include a separate fortress scene, hero eye-narrowing frames, morning field recordings, landing, dodge, bridge creak, and a credits track. The fortress uses the existing arena with Moonwake lighting. Missing cues are silent. The attached sunset reference informed the warm-to-cold color transition without being included as a runtime texture.

