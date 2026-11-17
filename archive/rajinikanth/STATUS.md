# Status (v0.3.0, new canon and living-world upgrade)

Same application (`com.hanvisoriginal.rajinikanth`), same project, same build pipeline. Rollback
points: git tags `v0.1.0` and `v0.2.0`.

## Completed in v0.3.0

**Story (Chapter One rebuilt around the new canon)**
- Opening tea sequence with no controls: water, leaves, boil, milk, stirring, the long pour between
  tumblers, the glass filling, the tray; the tray carried down the street into Upparpet Police
  Station; glasses handed to officers; the last glass taken to the lock-up, where Rajinikanth is revealed.
- Backstory told in the station: the harassment on bus 27E was real and happened to a student,
  Shwetha; the F.I.R. names the conductor because Kamakshi had stopped Devaraj's Peenya land deal.
  The complaint is never treated as a joke.
- Kamakshi serves the bail order and faces down the Sub-Inspector. Control begins inside the station:
  look around, talk to the writer, the head constable, Lokesh and the Inspector, walk out.
- Umashankar (surety, best friend, driver of 27E) and Kamakshi wait outside. She drives the family
  scooter; Rajinikanth rides pillion, leaning back and looking around, while they talk all the way to
  Malleshwaram. Rides are repeatable: to the depot, to any known place, to the evening show.
- Five chapters: Bail; Back on the Route (the ticketing game, the man who jumps off the last bus);
  Eighteen Lakhs (police, hide it, or let Kamakshi deposit it in court); Wrong Number (Umashankar
  can come along; Thimmaiah's godown; the raid); The Conductor's Bag (ends face to face with Devaraj).
- Devaraj is a businessman with an office, a finance company, a nephew, a temple committee and a
  collector; his offer at the end can be accepted, refused or taken home to "ask my wife".
- Side stories: Umashankar's loan from Devaraj Finance (pay, fight, or Kamakshi's legal notice),
  the reporter, the film with Kamakshi, work shifts, a promise to tell Kamakshi before going anywhere.
- New and reworked cast: Kamakshi, Umashankar, Girija, Putti, Devaraj, Vicky, Advocate Mohan Rao;
  every named person has family, money circumstances, a personal gait and a voice pitch.
- New places: your house in Malleshwaram (new interior), Umashankar's vatara, the High Court,
  Sri Devaraj Enterprises.
- Old saves load. v0.1/v0.2 saves keep money, standing, clothes, vehicles, statistics and calendar;
  the story restarts from the new opening and the player is told so.

**Music rule**
- No background score anywhere on foot, in dialogue, in missions or in cinematics; the generated
  music has been removed from the build. The supplied intro soundtrack is unchanged.
- Vehicle radio: plays only user-supplied tracks from `assets/audio/radio/` (or the app's `radio`
  folder), only while driving a car or auto-rickshaw; RADIO button for next track, volume and mute in
  Settings, track remembered between sessions. **No Kannada tracks have been supplied yet, so the
  radio is currently silent** and says so.

**People**
- Faces: iris, pupil with catch-light, eyelids that blink at irregular intervals (double blinks,
  faster when nervous), eyes that move before the head, teeth, lip and jaw movement while speaking,
  brow movement, moods (surprise, nervous, angry, sad, tired, smile), age lines, per-face asymmetry.
- Bodies: heavier builds (Umashankar), fingers and knuckles, buttons and lash lines on important
  characters, skin and woven-cloth textures, hems that sway with the stride, an advocate's coat.
- Movement: personal walking styles (stride, sway, arm swing, lean), leaning into turns, a pillion
  pose, tray carrying, tea pouring, umbrellas, children playing.
- Three tiers: hero (player and named cast) with extra detail; nearby people; distant people with
  reduced detail and throttled animation.

**World**
- Tea stall with vessel, stove, milk can, glasses, tumblers, biscuit jars, sugar tin, cash box,
  papers, hanging packets, price board, stools; the owner pours.
- Streets: tar patches, potholes, manhole covers, faded markings, puddles that appear in rain,
  litter, weeds, torn film and election posters, newspaper stands, coin telephones.
- Homes: chappals at the step, buckets or flower pots and plastic chairs by household, old
  bicycles, nameplates, people sweeping in the morning, children playing, a television heard from inside.
- Rain: umbrellas come out, vendors' carts get blue tarpaulins, puddles form, fewer people about.
- Animals: stray dogs that trot, sleep, bark and move for traffic; pigeons and crows that take off.
- Positional sound: tea stall, eating houses, market, bus station, bars, televisions.

## Verified in this build

By automated play-through and by looking at the captured frames:
- New Chapter One from the tea sequence to the meeting with Devaraj (34 checks), including the
  first playable moment, the pillion ride, the home scenes, both conductor runs, the raid.
- Save and load; a v1 save migrating correctly.
- Music rule: nothing playing on foot; radio available in a car, not on a scooter, off on exit.
- APK: same package name, zip-aligned, signature verified; exported pack boots without script errors.

## Not verified

- **No Android device or emulator has ever run this game.** Frame rate, memory, touch and audio on
  real hardware are unmeasured. This version adds more people detail, props and sounds; on the
  software renderer busy scenes run slower than v0.1. Treat performance as unknown; try the Low preset first.
- The opening's pacing and framing were checked from still frames, not watched in motion.
- The radio has only been tested with no tracks installed.
- Traffic, animals and rain behaviour were not observed over long periods.

## Requested but not achieved

- Photographic human realism (pores, wrinkles in cloth, simulated fabric, articulated fingers,
  blendshape faces, motion-captured or IK movement, recorded voices). People are still procedural
  low-poly figures; they are more expressive, not realistic.
- Depth of field and liquid or steam simulation in the tea sequence: the mobile renderer in use has
  no depth of field, so close-ups use long lenses, and liquids and steam are animated meshes and particles.
- Interactive shop interiors for grocers, mechanics, barbers and clothing shops; only the tea stall
  got a full inventory. Shopkeepers do not physically hand over goods or take coins.
- Obstruction-aware audio, heat haze, wet clothing, water spray, drips, flowing drains.
- Occlusion culling and asynchronous loading. Level of detail, instancing, atlases and streaming exist.
- The story beyond Chapter One: the gradual rise, betrayals and endings are set up by recorded
  choices but not written.

---

# Earlier: v0.2.0

## What changed in v0.2.0

- **Intro and music.** The supplied soundtrack (`assets/audio/user/intro_theme.ogg`, 67.6 s) is the only
  music in the intro and menu. The picture follows the track's own clock: HANVI'S sets letter by letter,
  ORIGINAL is drawn in, black at 10 s, star from 12.5 s, RAJINIKANTH lands on the swell at 23 s. It carries
  into the menu, fades over its last 2.5 s, and is faded out when gameplay starts. If the file is missing
  the menu says so and nothing is substituted. The source was AAC inside an MP4; Godot cannot play that,
  so it is transcoded once to Ogg Vorbis (quality 8). The composition is untouched; the original file is
  kept beside it.
- **Buildings.** 15 archetypes chosen by neighbourhood (pete house, shop row, commercial complex with
  colonnade, office, eating house, lodge, government office, school, apartment block, independent house,
  corner shop, hut, bungalow, workshop, godown) with real geometry: balconies, sunshades, awnings,
  pilasters, parapets, stair towers, water tanks, aerials, washing lines, compound walls, gates, porches.
  The facade atlas grew from 16 to 32 tiles (arched windows, glass, red brick, jaali, workshop, tiled
  fronts, painted wall adverts, weathered plaster).
- **Streets.** Kerbs and footpaths, open drains with slabs, electric poles with sagging wires and house
  connections, transformers, vendor carts, petty shops, dustbins, stone benches, post boxes, resting cows,
  coconut palms, rangoli at gates.
- **People.** Rebuilt body (tapered torso, shoulders, jaw, eyes, nose, hands, feet, collars, belts,
  sleeves), ages from schoolchild to elderly, and clothing by occupation (office, vendor, student,
  mechanic, porter, priest, shopper, police). Animation: weight shift, hip and shoulder counter-rotation,
  head look-at, mouth and brow movement, and activities (tea, eating, reading, telephone, working,
  repairing, waiting, arguing, laughing, listening, sweeping, carrying, head-loads).
- **Crowd.** People occupy places: vendors at carts with customers, mechanics at workshops, diners,
  bus queues that board when a bus halts while others get down, benches, school gates. Pairs converse in
  turns; companions walk side by side; passers-by greet each other and glance at the player.
- **Traffic.** Per-vehicle lane position with a little wander, overtaking by lighter vehicles, one vehicle
  at a time through a junction, early choice of exit with turn indicators, brake lights, body dive and
  roll, headlight throw at night, buses drawing in to the kerb.
- **Light.** Re-graded day (dawn, misty morning, hard noon, golden hour, purple dusk, night), pools of
  sodium light under lamps and tube-light in front of open shops, softer shadows, less grain.
- **Map.** Full-screen map drawn live from world coordinates: railways and 11 stations, 10 tanks and
  lakes, greens, 27 landmarks, bus stops, route 27E, numbered Cross / Main side streets, city blocks,
  road names along roads, legend, scale bar, north point. Smooth zoom about the finger, inertial pan,
  City / Area / Street presets, tap anything for name and distance, set a destination and get a route.
  Unvisited places show as grey question marks.
- **Camera.** Close / normal / wide / first-person on the CAM button, over-the-shoulder framing with
  eye contact during conversations, distance to the objective on screen.

## Verified in this build

By running the game under a software renderer (`tools/playtest.sh`) and looking at the screenshots:

- Chapter One still plays from the opening to its end, and save / load still round-trips.
- Intro frames at six points; soundtrack present, playing in the intro, still playing in the menu, and
  stopped after entering the world.
- Six neighbourhoods by day, night and rain; a line-up of ten character types; the map at city, area and
  street zoom with a destination and route.
- The APK is zip-aligned and signature-verified and the exported pack boots without script errors.

## Not verified

- **Still never run on a physical Android device or emulator.** No frame-rate, touch, audio-sync or
  memory measurement exists. This upgrade adds geometry and nodes; on the software renderer the frame
  rate fell in the busiest scenes. Whether mid-range phones hold 30 FPS is unknown until measured. If it
  does not, start with the Low preset.
- Intro picture-to-music sync was checked by logic and by frame captures, not by ear.
- Traffic behaviour (junction waiting, overtaking, indicators) was exercised only in passing; it was not
  watched for long periods and may deadlock or look wrong in places.

## Where it still falls short of the directive

- People are much better but still low-poly and procedural, not sculpted or motion-captured. There is
  no skeleton, inverse kinematics or foot planting; cadence is matched to speed to limit sliding.
  Opening doors and getting into vehicles are not animated.
- NPCs do not path around obstacles; they follow the street grid.
- Buildings vary by archetype but are still generated, not individually designed.
- Vehicles have no modelled interiors, rotating wheels or steering animation. Traffic still uses
  main roads only and there are no signals.
- No occlusion culling; level of detail is visibility ranges and animation throttling.
- The map's main roads, railways, lakes and landmarks are placed from real coordinates, but roads are
  straight between junctions and the numbered side streets are schematic. It is not a survey-accurate
  2002 street map.
- Colour grading is done through lighting and sky, not a post-process.

## Not built yet

- Chapters Two onward and the multiple endings.
- Cloud saves, more interiors, property as a second home, vehicle customisation.
- Controller support, localisation, a release-signed build.
