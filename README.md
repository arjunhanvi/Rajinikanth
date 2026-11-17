# BIG BANG LORE

**A HANVI'S ORIGINAL production.** Bengaluru, 1 January to 15 June 2007. Two die-hard Rajinikanth
fans, Raja and Ramanna (everyone calls him Rama), and what they turn out to mean to each other.
The story opens on the day a film shoot at M.S. Ramaiah Institute of Technology runs out of reel,
and ends on the day *Sivaji* releases.

This repository is the real game: a native Godot 4.3 project that exports an installable APK.
It is a work of fiction. Real public figures, institutions and places appear in a fictionalised,
alternate-history context. See `docs/2007_CULTURAL_BIBLE.md` for what is verified and what is invented.

**Status:** only the opening sequence is built (see `docs/STATUS.md`). The previous RAJINIKANTH
story is retired and archived in `archive/rajinikanth/`; it no longer loads.

## Get the APK

**One permanent link, always the newest build:**
https://github.com/arjunhanvi/Rajinikanth/releases/latest/download/rajinikanth.apk

Open it in your phone's browser, tap the downloaded file, allow "install unknown apps" once.

- **CI:** every push runs `.github/workflows/android.yml`; download `rajinikanth-apk` from the run's artifacts.
- **Local:** install Godot 4.3 with export templates, a JDK and the Android SDK build-tools, then

```bash
tools/build_apk.sh
```

The result is `build/rajinikanth.apk` (debug-signed, arm64-v8a + armeabi-v7a; the file name is kept so the download link stays the same).
Install with `adb install build/rajinikanth.apk` or copy it to a phone and open it. No network,
account or developer machine is needed to play.

## Run on a desktop

```bash
godot --path .
```

Mouse acts as touch. Keys: WASD move, Shift run, Space jump, C crouch, E interact, F hit, M map, P phone, V camera, Esc pause.

## What is playable now

The opening sequence, from the aerial view of Bengaluru to the BIG BANG LORE title, with player
control of Raja in the crowd and the first punch. After the title you can watch it again, walk the
city as Raja, or return to the menu. Free roam (Bengaluru 2007) is on the main menu.

## Automated test

```bash
tools/playtest.sh opening --fast
```

This plays the whole opening, walks the player around after the hand-over, and checks that every shot is reached. Screenshots go to `/tmp/rk_shots/`.
