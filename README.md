# RAJINIKANTH

**A HANVI'S ORIGINAL production.** An Android-first, third-person, open-world crime drama set in
Bangalore, 2002. You are Rajinikanth, conductor on Route 27E, just out on bail for something
another man did. Your wife Kamakshi argued you out. Your friend Umashankar stood surety. Then a
passenger jumps off the last bus and leaves a bag behind.

*One city. Countless stories. One man's unexpected transformation.*

This repository is the real game: a native Godot 4.3 project that exports an installable APK.
Every character, gang, party, film and business in it is fictional; real place names are geography only.

## Get the APK

**One permanent link, always the newest build:**
https://github.com/arjunhanvi/Rajinikanth/releases/latest/download/rajinikanth.apk

Open it in your phone's browser, tap the downloaded file, allow "install unknown apps" once.

- **CI:** every push runs `.github/workflows/android.yml`; download `rajinikanth-apk` from the run's artifacts.
- **Local:** install Godot 4.3 with export templates, a JDK and the Android SDK build-tools, then

```bash
tools/build_apk.sh
```

The result is `build/rajinikanth.apk` (debug-signed, arm64-v8a + armeabi-v7a, about 57 MB).
Install with `adb install build/rajinikanth.apk` or copy it to a phone and open it. No network,
account or developer machine is needed to play.

## Run on a desktop

```bash
godot --path .
```

Mouse acts as touch. Keys: WASD move, Shift run, Space jump, C crouch, E interact, F hit, M map, P phone, V camera, Esc pause.

## What is playable now

v0.3.0 rebuilds Chapter One around the new canon and adds a living-world pass (see [docs/STATUS.md](docs/STATUS.md)). Rollback points: tags `v0.1.0`, `v0.2.0`.

**Music:** the game has no background score. Put your own Kannada tracks (`.ogg` / `.mp3`) in `assets/audio/radio/` before building; they play only while driving a car or an auto.

- Animated HANVI'S ORIGINAL opening, yellow-star title, main menu, 4 independent save slots.
- Character creation with live 3D preview (face, skin, hair, facial hair, build, clothes, accessories).
- Touch controls (stick, camera drag, contextual buttons) that switch for walking, driving and conducting; layout, size, opacity and sensitivity settings; Low/Medium/High graphics.
- A streamed city laid out from real Bangalore coordinates (43 localities, 66 named arterial roads, side-street grid, generated buildings) plus handcrafted places: Kempegowda Bus Station, City Railway Station, Vidhana Soudha, K.R. Market, Cubbon Park, Lalbagh, Ulsoor Lake, H.A.L. Airport, a temple, and the shops of the starting neighbourhood. Five interiors.
- Day/night, weather, rain with wet roads, street lamps, shops that shutter at night, power cuts.
- 22 named characters with jobs, homes, daily schedules, friends and memory; ambient pedestrians with generated identities; police response.
- Left-hand traffic with 10 period vehicle types, buses that halt at stops, parked and ownable vehicles, a dealer.
- **Chapter One, "Ticket"** (five chapters): the tea-sequence opening and bail, riding pillion behind Kamakshi, the conductor ticketing game with Umashankar, the last-trip incident, the bag, Thimmaiah's godown and the raid, the courier job that ends in Devaraj's office. Choices change money, relationships, faction standing and later scenes.
- Side stories: Umashankar's loan, the evening show with Kamakshi, the reporter, repeatable work shifts, chain-snatchers, street-corner rallies.
- In-game 2002 mobile phone (contacts, messages, call register, missions, profile, people) and a pannable, zoomable city map with waypoints and routes.
- Economy: wages, tea stall, darshini, bar, tailor and wardrobe, cinema, buses and autos for travel, rent, property.

See [docs/STATUS.md](docs/STATUS.md) for what is tested, what is thin, and what is not built yet.
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) explains the engine choice and the code layout.

## Tests

```bash
tools/check.sh              # parse every script
tools/playtest.sh story     # automated playthrough of Chapter One + save/load (needs xvfb)
tools/playtest.sh tour      # screenshots: street, tea stall, bus station, traffic, night, rain
tools/playtest.sh streets   # six neighbourhoods
tools/playtest.sh people    # character line-up
tools/playtest.sh panels    # phone, map at three zooms, dialogue, pause, driving
tools/playtest.sh ui        # intro frames, soundtrack checks, menu, creator
```
