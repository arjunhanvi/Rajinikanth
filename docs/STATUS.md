# Status (v0.1.0, first playable milestone)

## Verified in this build

Checked by running the game under a software renderer with `tools/playtest.sh`:

- Chapter One plays from the opening to "End of Chapter One" (all five missions), including both
  slow-motion sequences, with the choices exercised by the script.
- Save, wipe state, load: money, flags and owned vehicle are restored.
- Named characters are at their scheduled places (tea stall at dawn, booth at 9:30, bar at night).
- Intro, menu, character creator, phone, map, dialogue, pause, driving and night/rain rendering
  were screenshotted and looked at.
- The APK exports, is zip-aligned and signature-verified (v1/v2/v3), and the exported game pack
  boots without script errors on desktop.

## Not verified

- **The APK has not been run on a physical Android device or emulator.** The build machine had
  neither. Frame rate on real phones, touch feel and audio latency are untested; the 30 FPS target
  on mid-range hardware is a design intent, not a measurement.
- Multi-touch (stick + camera + button together) is implemented but was only exercised with a
  single emulated pointer.

## Thin or simplified

- Characters and vehicles are low-poly procedural models, not sculpted assets. Art direction is
  stylised rather than photoreal.
- The city covers all of Bangalore's main localities, but outside the handcrafted places the
  buildings are generated; roads are straight segments between junctions; there are no flyovers,
  signals or one-ways. Scale is compressed 1:4.
- Traffic drives only on arterial roads and does not obey signals; AI vehicles do not avoid each
  other across different roads at junctions. Moving traffic cannot be hijacked (parked vehicles can
  be taken).
- Five interiors (room, bar, police station, tailor, godown). Other shops are served at the door.
- Combat is a simple punch/health exchange. No weapons.
- Vehicle customisation is limited to choosing what you buy; there is no garage or repaint.
- First-person camera exists on foot and in vehicles but has no dedicated interior models.
- Signage is in English/transliterated Kannada; there is no Kannada-script text or voice acting.

## Not built yet

- Chapters Two onward: the rise through the underworld, the election, betrayals and the multiple
  endings. The flags that will drive them (who got the bag, Kitty's path, the tip to the press,
  faction standings, Meena) are already recorded.
- Cloud saves.
- More interiors, more handcrafted neighbourhoods, railway and airport activity.
- Property as a second home, vehicle storage and customisation.
- Controller support, localisation, accessibility options beyond subtitles and control sizing.
- A release-signed build and Play Store packaging (the current APK is debug-signed).
