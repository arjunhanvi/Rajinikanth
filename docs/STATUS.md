# Status (v0.2.0, realism and immersion upgrade)

v0.1.0 is kept as the rollback point: git tag `v0.1.0`. Saves from v0.1.0 load in v0.2.0.

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
