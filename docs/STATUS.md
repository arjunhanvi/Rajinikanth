# BIG BANG LORE: status

Version **0.5.0** (Android version code 5). The package id is unchanged (`com.hanvisoriginal.rajinikanth`), so the APK installs over the earlier build; the app label is now **Big Bang Lore**.

## Priority 1: the opening sequence

| Step from the brief | State | Notes |
|---|---|---|
| 1. Protect the project | **Done** | Tag `rajinikanth-final` (commit `163479d`); full git bundle `build/rajinikanth-final.bundle` (verified); APKs v0.1.0 to v0.4.0 kept in `build/rollback/` with SHA-256 sums; old story scripts copied to `archive/rajinikanth/`. |
| 2. Audit reusable systems | **Done** | Kept: the human generator and rig, LOD, face morphs, crowd models, streamed city, vehicles (auto, police jeep), weather and light, sound, HUD and touch controls, saves, Android export. |
| 3. Remove the old story from the active game | **Done** | The old `Story.gd`, `TeaSet.gd`, named cast and Harness tests are archived. The named cast is no longer spawned (`People.LEGACY_CAST = false`). Old-story map names are neutralised. Saves now live in `user://saves_bbl/`, and any save older than v3 is refused, so the old story cannot load. The old saves are left untouched on the device. |
| 4. New identity | **Done** | Project and app name "Big Bang Lore"; new icon; menu title in yellow comic lettering (Bangers, OFL); About text. The studio ident (HANVI'S ORIGINAL with the supplied soundtrack) is kept; its old star and RAJINIKANTH title card are removed. The HUD shows the 2007 calendar date. |
| 5. Raja and Rama | **Done (first pass)** | New generated bodies `raja` and `rama` with their own faces, builds, hair, facial hair, skin tone, clothes and walks. Also generated: `rajini`, `shankar`, `kvanand`, `ad`, `umashankar` (a new character, not the old model). These are generic approximations, not likenesses. |
| 6. MSRIT campus and unit | **Done (first pass)** | `scripts/world/Campus.gd`, placed at MSRIT's real position on the Outer Ring Road: compound wall, name arch, security cabin and boom barrier; main block with tower and porch; two wings; lawns, drive, canteen, parked two-wheelers; the film unit (rope line, umbrella and chair, monitor and director's chairs, camera on a dolly track, jib, reflectors, lamp, generator van, flight cases, water cans). |
| 7. The opening, in order | **Done** | `scripts/story/Opening.gd`, scenes 1 to 11 as briefed (details below). |
| 8. Hand-over to the player | **Done** | The cinematic camera blends into the player camera over 1.6 s, with no cut or load. The letterbox bars slide away and the touch controls come up. Raja is free to walk (bounded to the crowd area). Umashankar comes to him; the player picks Raja's reply from two choices while still able to move. |
| 9. Crowd fight and police | **Done** | The player throws the first punch (an on-screen PUNCH prompt in slow motion). There is a high-angle shot of two crowds converging, three ground-level shots, dust, the AD yelling, then a siren heard first and the police jeep arriving after. |
| 10. Auto and title | **Done** | Raja leaves in a black-and-yellow auto (2007 livery); Rama is led deeper into the campus. Both look back. "Yaaru adhu?" / "Aa sule maga…"; "Yaaru avnu?" / "Avn hesru…", then a hard cut to black with sound muted, and BIG BANG LORE comes up out of the black as halftone print dots. |
| 11. Full test | **Done (automated)** | `tools/playtest.sh opening --fast`: 37 checks pass. |
| 12. Android build | **Built** | `build/rajinikanth.apk`, v0.5.0 (code 5), 150 MB, debug-signed (v1/v2/v3 verified), arm64-v8a and armeabi-v7a. The retired RAJINIKANTH hero models are excluded. The exported pack boots with no script errors. **Not tested on a phone.** |

### What plays, shot by shot

1. Fiction card. Aerial: an eagle's view straight down over north Bengaluru, descending in one move to the MSRIT gate. The card reads BENGALURU, MONDAY, 1 JANUARY 2007.
2. The camera falls in behind a unit boy walking in through the gate (about 6 s, one continuous shot). He tells the assistant director the reel is finished (Tamil, subtitled). The AD's frustration (a hand to the forehead), then to Shankar and K. V. Anand at the monitor. Shankar sighs: "Inform sir." with a small, low gesture.
3. A wide shot, then one move across the set round behind Rajinikanth under the unit umbrella, left of frame in shades. Over the shoulder, the AD bends down: "Sir, pack up. We didn't get reel." A slow nod and a small calm hand.
4. Following the AD away: "Push that guy back!" "Ask these guys to stand behind the line!" Raja in the crush: "Thalaiva! Thalaiva!" Security shoves the man beside him; he goes down, gets up, steps out and dusts himself off. That man is Rama, unannounced.
5. **Control.** Umashankar: "Enna bhakthare… saami dharisanam aachaa?" The player chooses Raja's reply.
6. Slow motion: Rama's smile (extreme close-up), his back, his feet, the approach. Raja turns. A top-and-bottom split screen, faces at equal size, eye-lines matched; a bead of sweat runs down Rama's temple; heartbeat.
7. Both scream and run; Raja leaves the ground; **the player throws the punch**. Flash and shake, a high angle of the crowds meeting, then ground-level chaos.
8. A siren from down the Outer Ring Road before anything is seen; the jeep turns in; constables pull the sides apart.
9. Raja walked out to an auto; Rama walked further in; each looks back (medium close-ups).
10. Inside the moving auto: "Yaaru adhu?" "Aa sule maga…". Rama walking: "Yaaru avnu?" "Avn hesru…", then **cut to black**.
11. The title rises out of the black, dot by dot. Then: watch again, walk Bengaluru as Raja, or the main menu.

## Honest limits

- **Not run on Android hardware.** Performance on phones is unknown. The opening adds about 50 to 75 animated people (scaled by the graphics preset: 26, 40 or 56 crowd plus the cast). On the software renderer in this container it is slow. Try the Low preset first. Shadows (including the umbrella's) are off on Low.
- **No recorded voices.** Dialogue is subtitled (romanised Tamil or Kannada plus English) with ambient sound. Every line needs native-speaker review.
- The models of real people are generic and seen mostly from behind or at a distance. They are not likenesses.
- Hair and beards are still shell-based and look coarse in extreme close-up (Rama's lips shot shows it). Faces are morph-driven, not performance-captured.
- The campus is an impression of MSRIT, not a survey. The department names on the wings are placeholders.
- The crowd fight is staged: people surge, push and hold, with non-graphic contact only. There is no physics.
- The old `tools/playtest.sh story`, `people` and `humans` scenarios were tied to the old story and are archived with it.
- GitHub pushes from this environment have been refused with HTTP 403 since v0.1.0, so the work exists in this session's repository, the git bundle and the APK.

## Not started (by instruction)

The rest of the story, any further missions, and any new characters beyond the opening are waiting on the author. The proposed backgrounds for Raja and Rama are in `docs/BIG_BANG_LORE_CHARACTERS.md`, for approval.
