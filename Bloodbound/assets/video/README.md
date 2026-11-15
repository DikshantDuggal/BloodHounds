# Opening movie

`opening.ogv` is the user-supplied 10-second WhatsApp video, converted from
1920×1080 H.264/AAC to 1280×720 Ogg Theora/Vorbis for Godot's native player.
The full clip and its audio are retained. `menu.png` is its clean first frame.

`scenes/Startup.tscn` plays the movie before the title screen. Enter, Escape,
Space, or the Skip intro button go straight to the menu. It does not replay
when returning to the title or retrying. For development, pass `-- --skip-intro`.

To replace it, encode a 16:9 clip using FFmpeg:

```sh
ffmpeg -i input.mp4 -map 0:v:0 -map '0:a:0?' -vf 'scale=1280:720,setsar=1' -c:v libtheora -q:v 7 -pix_fmt yuv420p -c:a libvorbis -q:a 5 opening.ogv
```
