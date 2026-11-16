# Architecture

## Engine decision: Godot 4.3 (Compatibility renderer)

| Requirement | Unity | Godot 4.3 |
| --- | --- | --- |
| Reproducible, scriptable APK builds from a clean checkout | Needs a licensed, activated editor on every build machine | One binary + export templates, no account |
| Mid-range Android target | Fine | Fine with the GLES3 "Compatibility" renderer |
| Project as plain text in git | Binary scenes/meta noise | Text scenes and scripts |
| Cost / licence | Per-seat terms, runtime fee history | MIT |

Unity has the richer asset ecosystem, but this game generates its world, characters, vehicles,
textures and audio procedurally, so that advantage does not apply. Godot was chosen and the whole
game is GDScript built in code (no editor-authored scenes beyond the boot stub).

## Layout

```
scripts/core      Game (state, saves, settings), City (geography, routing), Sfx (audio)
scripts/world     World (streaming, clock, interaction), Chunk (generation), Landmarks, Interiors,
                  Weather (sky, rain, lamps), MB (mesh builder), Mats (materials)
scripts/actors    Human (procedural body + animation), Player, NPC, Crowd (population), People (cast)
scripts/vehicles  Vehicle (models + driving), Traffic (road AI, parked, owned)
scripts/story     Story (missions, scenes, events), Shops (economy, travel, wardrobe)
scripts/ui        Boot, Intro, MainMenu, Creator, HUD, TouchPad, MapView, Phone, SettingsPanel, UI
tools             gen_art.py, gen_textures.py, gen_audio.py, build_apk.sh, check.sh, playtest.sh
```

## The city

`City.gd` projects real latitude/longitude of 43 localities to world space at 1:4 scale and joins
them with 66 named arterial roads. The world is cut into 100 m chunks. `Chunk.gd` builds a chunk
deterministically from its coordinates: ground, arterial strips with footpaths, a 50 m side-street
grid, building lots whose style depends on the district kind (old pete, commercial, residential,
industrial, cantonment, government, outskirts), signs, hoardings, lamps, trees, collision.
All buildings in a chunk share one facade atlas material, so a chunk is a handful of draw calls.
Handcrafted places are "zones" that suppress generic lots and are built by `Landmarks.gd`.
`World.gd` loads chunks in a radius set by the graphics preset, one per frame.

## People

Named characters (`People.DB`) have a schedule of `[hour, place, mode]`. `Crowd.gd` simulates them
abstractly along street paths when far from the player and spawns a physical `NPC` when near, so
they are where their day says they should be. Ambient pedestrians walk the street grid, wait for
gaps in traffic, loiter in pairs, flee from trouble. Memory is a short per-character list in the save.

## Story

Mission progress is `Game.s.active` / `step` / `mvars` / `flags`, all plain JSON, so any beat
survives a save. Scenes are coroutines (`await say(...)`, `await choose([...])`).

## Saves

`user://saves/slotN.json`, written atomically (temp file + rename). Four slots, each a full,
independent profile. Settings are separate in `user://settings.json`.
