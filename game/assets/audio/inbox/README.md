# Audio inbox — drop-in sounds from creators

Put a sound here, named after its **audio id** and mirroring the id's path, and the game plays it instead of
the shipped procedural sound. No code change, and the original files in `assets/audio/` are never touched.

| audio id            | file to drop here                     | used for                                  |
|---------------------|---------------------------------------|-------------------------------------------|
| `music/ironfront`   | `inbox/music/ironfront.ogg`           | the Ironfront war-table in the basement   |
| `music/tavern`      | `inbox/music/tavern.ogg`              | the Tipsy Wyvern and the Velvet Lantern   |
| `music/lantern`     | `inbox/music/lantern.ogg`             | upstairs at the Velvet Lantern            |
| `amb/harbour`       | `inbox/amb/harbour.ogg`               | the harbour and quay                      |
| `amb/pond`          | `inbox/amb/pond.ogg`                  | the village pond                          |
| `amb/tavern`        | `inbox/amb/tavern.ogg`                | inn murmur (also `amb/tavern_loop`)       |
| `sfx/hammer_1`      | `inbox/sfx/hammer_1.wav`              | any existing effect can be replaced too   |

Rules
- Formats: `.ogg` (Vorbis) or `.wav` (PCM 8/16-bit). `.ogg` wins when both exist.
- Ids in `amb/` and `music/`, and ids ending in `_loop`, loop seamlessly; make the file loop cleanly.
- Every shipped id is listed in `assets/audio/manifest.json`. Context ids without a shipped file of their own
  (`amb/harbour`, `music/lantern`, `sfx/ui_toggle`, …) fall back to a fitting shipped sound — see
  `Audio.ALIASES` in `scripts/autoload/audio.gd` — until a file for them appears here.
- Open the project in the Godot editor once after adding files so they are imported (the game can also read
  un-imported files when run from the project folder).

Resolution order for an id (first match wins):
1. `user://overrides/audio/<id>.(ogg|wav)` — a player's or modder's personal override
2. `res://assets/audio/inbox/<id>.(ogg|wav)` — this folder
3. `res://assets/audio/<id>.(ogg|wav)` — the shipped sound
4. the same three for the id's alias, if it has one
