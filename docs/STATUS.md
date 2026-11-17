# BIG BANG LORE: status

Version **0.6.0** (Android version code 6). The package id is unchanged (`com.hanvisoriginal.rajinikanth`), so the APK installs over the earlier build; the app label is now **Big Bang Lore**.

## Priority 1: the opening sequence

| Step from the brief | State | Notes |
|---|---|---|
| 1. Protect the project | **Done** | Tag `rajinikanth-final` (commit `163479d`); full git bundle `build/rajinikanth-final.bundle` (verified); APKs v0.1.0 to v0.4.0 kept in `build/rollback/` with SHA-256 sums; old story scripts copied to `archive/rajinikanth/`. |
| 2. Audit reusable systems | **Done** | Kept: the human generator and rig, LOD, face morphs, crowd models, streamed city, vehicles (auto, police jeep), weather and light, sound, HUD and touch controls, saves, Android export. |
| 3. Remove the old story from the active game | **Done** | The old `Story.gd`, `TeaSet.gd`, named cast and Harness tests are archived. The named cast is no longer spawned (`People.LEGACY_CAST = false`). Old-story map names are neutralised. Saves now live in `user://saves_bbl/`, and any save older than v3 is refused, so the old story cannot load. The old saves are left untouched on the device. |
| 4. New identity | **Done** | Project and app name "Big Bang Lore"; new icon; menu title in yellow comic lettering (Bangers, OFL); About text. The studio ident (HANVI'S ORIGINAL with the supplied soundtrack) is kept; its old star and RAJINIKANTH title card are removed. The HUD shows the 2007 calendar date. |
| 5. Raja and Lal | **Done (first pass)** | New generated bodies `raja` and `rama` with their own faces, builds, hair, facial hair, skin tone, clothes and walks. Also generated: `rajini`, `shankar`, `kvanand`, `ad`, `umashankar` (a new character, not the old model). These are generic approximations, not likenesses. |
| 6. MSRIT campus and unit | **Done (first pass)** | `scripts/world/Campus.gd`, placed at MSRIT's real position on the Outer Ring Road: compound wall, name arch, security cabin and boom barrier; main block with tower and porch; two wings; lawns, drive, canteen, parked two-wheelers; the film unit (rope line, umbrella and chair, monitor and director's chairs, camera on a dolly track, jib, reflectors, lamp, generator van, flight cases, water cans). |
| 7. The opening, in order | **Done** | `scripts/story/Opening.gd`, scenes 1 to 11 as briefed (details below). |
| 8. Hand-over to the player | **Done** | The cinematic camera blends into the player camera over 1.6 s, with no cut or load. The letterbox bars slide away and the touch controls come up. Raja is free to walk (bounded to the crowd area). Umashankar comes to him; the player picks Raja's reply from two choices while still able to move. |
| 9. Crowd fight and police | **Done** | The player throws the first punch (an on-screen PUNCH prompt in slow motion). There is a high-angle shot of two crowds converging, three ground-level shots, dust, the AD yelling, then a siren heard first and the police jeep arriving after. |
| 10. Auto and title | **Done** | Raja leaves in a black-and-yellow auto (2007 livery); Lal is led deeper into the campus. Both look back. "Yaaru adhu?" / "Aa sule maga…"; "Yaaru avnu?" / "Avn hesru…", then a hard cut to black with sound muted, and BIG BANG LORE comes up out of the black as halftone print dots. |
| 11. Full test | **Done (automated)** | `tools/playtest.sh opening --fast`: 37 checks pass. |
| 12. Android build | **Built** | `build/rajinikanth.apk`, v0.5.0 (code 5), 150 MB, debug-signed (v1/v2/v3 verified), arm64-v8a and armeabi-v7a. The retired RAJINIKANTH hero models are excluded. The exported pack boots with no script errors. **Not tested on a phone.** |

### What plays, shot by shot

1. Fiction card. Aerial: an eagle's view straight down over north Bengaluru, descending in one move to the MSRIT gate. The card reads BENGALURU, MONDAY, 1 JANUARY 2007.
2. The camera falls in behind a unit boy walking in through the gate (about 6 s, one continuous shot). He tells the assistant director the reel is finished (Tamil, subtitled). The AD's frustration (a hand to the forehead), then to Shankar and K. V. Anand at the monitor. Shankar sighs: "Inform sir." with a small, low gesture.
3. A wide shot, then one move across the set round behind Rajinikanth under the unit umbrella, left of frame in shades. Over the shoulder, the AD bends down: "Sir, pack up. We didn't get reel." A slow nod and a small calm hand.
4. Following the AD away: "Push that guy back!" "Ask these guys to stand behind the line!" Raja in the crush: "Thalaiva! Thalaiva!" Security shoves the man beside him; he goes down, gets up, steps out and dusts himself off. That man is Lal, unannounced.
5. **Control.** Umashankar: "Enna bhakthare… saami dharisanam aachaa?" The player chooses Raja's reply.
6. Slow motion: Lal's smile (extreme close-up), his back, his feet, the approach. Raja turns. A top-and-bottom split screen, faces at equal size, eye-lines matched; a bead of sweat runs down Lal's temple; heartbeat.
7. Both scream and run; Raja leaves the ground; **the player throws the punch**. Flash and shake, a high angle of the crowds meeting, then ground-level chaos.
8. A siren from down the Outer Ring Road before anything is seen; the jeep turns in; constables pull the sides apart.
9. Raja walked out to an auto; Lal walked further in; each looks back (medium close-ups).
10. Inside the moving auto: "Yaaru adhu?" "Aa sule maga…". Lal walking: "Yaaru avnu?" "Avn hesru…", then **cut to black**.
11. The title rises out of the black, dot by dot. Then: watch again, walk Bengaluru as Raja, or the main menu.

## Evidence

- `docs/opening/video_frames_*.jpg`: one frame every 6 s from a real-time recording of the full opening (Godot movie writer, 24 fps, 1024×576, software renderer in this container). The recording itself, `build/bigbanglore_opening.mp4` (3 min 44 s, with sound), is not committed because of its size; it was sent with this build.
- `docs/opening/shots_*.jpg`: one frame per shot from the automated play-through.
- `docs/opening/title_reveal.jpg`: the title at two screen sizes. `docs/opening/raja_and_rama_models.jpg`: the two new bodies.

## Corrections in 0.6.0 (Directive: critical opening corrections)

| Item | State | How it was checked |
|---|---|---|
| Rama renamed **Lal** everywhere active | Done | `grep` finds no active "Rama"; documents updated; the old name is kept only in the rename note |
| **Raja** is the one pushed, falls, gets up, dusts off; Lal absent | Done | Security steps square in front of Raja across the rope, hands land on his chest, and he staggers back still facing him, sits down hard onto his hands, holds, goes to one knee and stands (a 3.2 s keyframed fall), then dusts himself off. Control is handed over at that moment. The harness checks the fall plays on the player's own body and that Lal is invisible at that beat; frames inspected. |
| Lal's entrance separate, after Umashankar | Done | Lal first appears in scene 6, entering through the gate alone |
| Raja from the Shankar Nag reference | Done (approximation) | New generated body: long lean oval face, high cheekbones, strong nose, deep-set eyes under heavy brows, thick moustache, dense side-swept hair, darker skin; khaki-beige half-sleeve shirt tucked into dark trousers |
| Lal from the Ambareesh reference | Done (approximation) | Big, broad and taller, round full face, wide jaw, full cheeks, broad nose, a big crown of wavy hair, thick moustache; dark sweatshirt and jeans. A different sculpt, build, hair, skin and walk from Raja's (same base topology, as for every human in the game) |
| Rajinikanth from the Sivaji reference | Done (approximation) | Bald head, grey goatee and moustache, shades, black turtleneck, long black coat, black trousers |
| Rajinikanth never shown from the front | Done | He sits facing into the campus, back to the crowd and the gate. The camera moves are all behind him, and the OTS sits just behind his left shoulder with him on the left of frame. A per-frame check counts any frame where the active camera is in front of him within 30 m with his head in view: **0**. He leaves during the fight, so no later shot can catch him. |
| Medical students | Done | 15 students in white coats (12 with stethoscopes) in three groups (at the rope, on the porch steps, at the canteen). They talk among themselves, watch the star and laugh; they react to the fall ("Ayyo, biddbitta paapa!") and to the fight ("Ayyo, hodedaadtidaare! Yaaradru police ge phone maadi!") and do not join it |
| ₹1,000 and US $ notes on set | Done | 70 ₹1,000 (Mahatma Gandhi series, pink-red, 177 × 73 mm) and 50 US $100 (1996 series) prop notes lie where a money-rain take came down around the camera and set, with a tail towards the rope, plus two banded bundles on the props table. Stylised textures, not facsimiles |
| Kannada for everyone but the film crew | Done | Umashankar, Raja, security, students, police and friends all speak Kannada; the unit speaks Tamil or English. Every line has an English subtitle. **A native speaker should still review the lines.** |
| Whistle at the blackout | Done | Whistle onset measured in the supplied track at **20.47 s** (a 1.2 to 1.4 kHz glide, full level by 20.6 s, running to the end at 33.6 s). On the frame the screen goes black, every ambience, siren and engine is stopped and the track starts at 20.47 s. The harness checks it is the same frame. |
| Title in the Portia manner, yellow star logo, old animation | Done | Portia is commercial, so Six Caps (OFL) stands in with a dark extrusion; drop a licensed `Portia.otf` in `assets/fonts/` and it is used automatically. The intro again has Hanvi's logo, the star rising, and the title letter by letter. |
| Main menu plays the supplied track on loop | Done | Checked by the harness (`s_intro`): the theme is playing, looping, from the supplied file |
| Anatomical continuity | Improved | The skin under clothing is now always rendered (it used to be cut away), so a lifting hem, sleeve or collar shows body, not a hole. Collarless necklines are snapped to a clean ring. Body parts were already one continuous skinned mesh; no gaps were found in the extreme-pose fall frames. |
| Hair | Improved | A new 1024² strand texture with thousands of individual strands, with density chosen per shell (dense at the scalp, wispy at the edge). Heroes have 12 shells (was 7), the crowd 7 (was 4), face hair 4 to 6 with a denser cut. All 19 active models regenerated. |
| Human-to-human contact | Improved | Bodies keep a personal radius and give way to each other, so nobody walks through anybody. Deliberate contact (push, hold, fall) allows hands to land. The push is staged at arm's length so the hands meet the chest. |
| Human-to-object contact | Improved | Rajinikanth's pelvis rests on the chair seat (seat lift); auto passengers sit on the bench; the notes lie on the ground. |

### What is still short of the benchmark

The brief names Red Dead Redemption 2 as the quality bar. These parts are not at that level, and it would be wrong to say they are:
- **Hair** is shell-based (layered offset surfaces with strand alpha), not strand or card geometry with physics. It does not move independently of the head. At gameplay distance it reads well; in extreme close-up the layering shows.
- **Animation** is procedural and keyframed, with no motion capture, no IK foot planting on uneven ground and no physics ragdoll. The push and fall are hand-keyed; the hands land on the chest because the actors are staged at the right distance, not because a solver places them.
- **Collision between people** is a separation radius, not body-shape collision; arms can still cross each other in a dense scrum.
- **Cloth** is skinned to the body, with no cloth simulation.
- The faces are approximations of the references built from MakeHuman morph targets, not scans or likenesses.

## Honest limits

- **Not run on Android hardware.** Performance on phones is unknown. The opening adds about 50 to 75 animated people (scaled by the graphics preset: 26, 40 or 56 crowd plus the cast). On the software renderer in this container it is slow. Try the Low preset first. Shadows (including the umbrella's) are off on Low.
- **No recorded voices.** Dialogue is subtitled (romanised Tamil or Kannada plus English) with ambient sound. Every line needs native-speaker review.
- The models of real people are generic and seen mostly from behind or at a distance. They are not likenesses.
- Hair and beards are still shell-based and look coarse in extreme close-up (Lal's lips shot shows it). Faces are morph-driven, not performance-captured.
- The campus is an impression of MSRIT, not a survey. The department names on the wings are placeholders.
- The crowd fight is staged: people surge, push and hold, with non-graphic contact only. There is no physics.
- The old `tools/playtest.sh story`, `people` and `humans` scenarios were tied to the old story and are archived with it.
- GitHub pushes from this environment have been refused with HTTP 403 since v0.1.0, so the work exists in this session's repository, the git bundle and the APK.

## Not started (by instruction)

The rest of the story, any further missions, and any new characters beyond the opening are waiting on the author. The proposed backgrounds for Raja and Lal are in `docs/BIG_BANG_LORE_CHARACTERS.md`, for approval.
