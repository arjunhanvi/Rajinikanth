# BIG BANG LORE: Bengaluru world reconstruction and controls overhaul

## Stage 1: audit and plan (for approval)

Status: plan only. **No world or control code has been changed.**

**Historical window:** 1 January to 15 June 2007.

**Network blocker.** This environment's network policy refuses the hosts needed for real map data:
- `overpass-api.de`
- `download.geofabrik.de`
- `opentopography.s3.sdsc.edu` (elevation)
- `www.openhistoricalmap.org`
- Wikimedia Commons
- the Wayback Machine

My requests to allow them were rejected by the environments service. They can be added under the environment's network settings (session title bar → cloud environment → Edit → Network access → Allowed domains). Until then, no real geography can be imported, and I will not substitute invented data.

---

## 1. Audit of the current world and controls

### 1.1 World (`scripts/core/City.gd`, `scripts/world/*`)

| Area | What exists | Verdict |
|---|---|---|
| Geography | 44 localities as single points from real latitude/longitude. **The whole city is compressed 1:4** (`SX = 27,000 m per degree` instead of about 108,000), so MG Road's 1 km is 250 m. | Unsuitable: not real scale |
| Arterial roads | About 65 "roads", each a **straight line between two locality centres**, snapped to a 50 m grid. No curves, no real alignment, no real junctions. | Unsuitable |
| Side streets | A procedural 50 m grid generated per 100 m chunk. | Unsuitable (the brief forbids a random network) |
| Buildings | Procedural per chunk: archetypes chosen by locality type (old, commercial, residential, industrial, cantonment, government), boxes with painted windows, random signs. | Unsuitable: generic, repeated everywhere |
| Landmarks | A few hand-built sites (`Landmarks.gd`): a bus station, railway station, "Vidhana" block, market, parks, lake, temple, airport. Simple boxes, not recognisable architecture. | Unsuitable |
| Terrain | Flat: the world sits at y = 0. Roads are flat slabs at 4–19 cm. Lakes and green spaces are circles drawn on the map only. | Missing |
| Railways, flyovers, bridges | Railways are map-only polylines; none exist in 3D. No flyovers or underpasses. | Missing |
| Trees | One generic tree (cylinder trunk plus sphere crown) and a palm, scattered along streets. | Unsuitable |
| Street lighting and wiring | Generic poles; a dynamic light pool turned on by the clock; wires strung between electric poles. | Defective: generic, not period-specific |
| Shops | Painted signboards on block fronts. A few enterable shops via `Interiors.gd`. | Partial |
| Traffic | Vehicles follow straight centre-lines on arterial edges (`Traffic.gd`). A realistic 2007 mix: autos, bikes, scooters, cars, hatchbacks, taxis, BMTC and private buses, lorries. No lanes, junction logic, signals or crossings. | Partial: the mix is right, the paths are not |
| Map UI (`MapView.gd`) | Draws the same compressed `City.gd` data, so it matches gameplay, but it is not real geography. | Rebuild with the master map |
| Story location | The opening plays at the **M.S. Ramaiah Institute campus (`Campus.gd`)**, placed through the compressed coordinates. | **Must be preserved** (see 2.4) |

**Summary:** the current world is a stylised, compressed, procedurally generated Bengaluru. It cannot be "upgraded" into a geographically accurate one. The road network and the building placement must be rebuilt from real data. The systems around them can be kept:
- chunk streaming;
- the ground service;
- shops and interiors;
- weather and day/night;
- the traffic manager;
- the map UI.

### 1.2 On-foot controls (`scripts/ui/TouchPad.gd`, `HUD.gd`, `Player.gd`)
- **Movement:** a floating stick that appears wherever the left thumb lands, with a 90 px radius scaled by a size setting. No dead zone or smoothing. Direction follows the raw finger offset, so small jitter turns the character.
- **Run:** a separate **hold-to-run "RUN" button** on the right. There is no run lock, and no run triggered by the stick.
  - There is no rotating movement bar in the current code. The closest control is this floating stick; please tell me if you meant something else.
- **Actions:** round text buttons, always shown, even when not relevant: JUMP, DUCK, HIT, interact, plus TEL, MAP, CAM and pause.
- **Camera:** dragging on the right half rotates yaw and pitch, with no acceleration curve. The orbit camera has a raycast collision pull-in. Smoothing is position-only, which causes jitter on fast drags.
- **Settings:** button scale, left-handed mode and steering mode exist (`SettingsPanel.gd`). No sensitivity or opacity setting. No haptics.

### 1.3 Driving (`scripts/vehicles/Vehicle.gd`)
- **Physics:** a **kinematic CharacterBody3D, with height forced to y = 0**. No wheels, no suspension, no body roll.
  - Vehicles therefore sit 9 cm *inside* the roads and cannot react to bumps, kerbs or speed breakers.
- **Handling:** every type uses the same formula. They differ only in top speed, acceleration and turn rate. Two-wheelers lean.
  - Steering ramps to the input at a fixed rate. Turn rate is scaled by speed.
- **Controls:** on-screen "<" and ">" steering buttons (or the stick, as an option), GAS, BRAKE, H-BRK, HORN, EXIT, RADIO. Throttle is all or nothing.
- **Camera:** an orbit camera with the distance set by vehicle length. No look-ahead and no speed-based framing.

---

## 2. Proposed master-map boundaries

### 2.1 Principle
Build a **small, real-scale (1:1) Bengaluru first**, then expand it. Regions outside the boundary are shown on the map as "outside the playable area", never as finished.

### 2.2 Phase 1 playable area: Central Bengaluru, about 3.3 × 3.3 km
Bounding box, roughly 12.960–12.990 N by 77.585–77.618 E. It contains:

**Streets and parks**
- Cubbon Park
- M.G. Road
- Brigade Road
- Church Street
- Residency Road
- St. Mark's Road
- Richmond Road and Richmond Circle
- Lavelle Road
- Kasturba Road
- Cubbon Road
- Cunningham Road
- Queen's Road
- Infantry Road
- Commercial Street and Shivajinagar (edge)
- Vittal Mallya Road
- Museum Road
- Rest House Road

**Landmarks**
- Vidhana Soudha
- Attara Kacheri (High Court)
- Mayo Hall
- St. Mark's Cathedral
- St. Mary's Basilica
- Visvesvaraya Museum
- Planetarium (edge)
- Chinnaswamy Stadium

**Hotels and malls**
- The Oberoi (at the eastern edge of M.G. Road)
- Garuda Mall (Magrath Road)
- Bangalore Central (Residency Road), to be verified

This one area covers deliverables 7–10, 13–19 and the landmark and hotel requirements.

### 2.3 Later expansions, each its own approved stage
1. **West:** K.G. Road to Majestic (Kempegowda Bus Station, City Railway Station), Gandhinagar, Chickpet, Avenue Road, K.R. Market, Bangalore Fort, Tipu's Summer Palace.
2. **South:** Lalbagh (Glass House), Basavanagudi, Gandhi Bazaar, Jayanagar.
3. **North:** Palace Road, Bangalore Palace, Sadashivanagar, Mekhri Circle, Malleshwaram.
4. **East:** Ulsoor, Indiranagar, Domlur, Old Madras Road.
5. **South-east:** Koramangala (Forum), Madiwala, Hosur Road, BTM Layout.
6. **Far regions:** Hebbal, Yeshwanthpur, Whitefield: road connection only, until approved.

### 2.4 The opening and the existing world
The opening plays at M.S. Ramaiah Institute of Technology (Mathikere, north). Its real position (about 13.03 N, 77.565 E) is outside the Phase 1 area.

**Proposal:**
- The existing compressed world, with the campus, stays exactly as it is, as the game world, until the new central area passes its quality gate. Then the campus is placed at its real 1:1 position and connected through the North expansion.
- Nothing in the opening changes.
- Saved positions in the old coordinates get a one-time migration: they are mapped to the nearest equivalent place, with the player's own home and vehicles kept.

---

## 3. Geographical data and historical reference approach

### 3.1 Data pipeline (offline Python tool, `tools/map/`; output is the source of truth)
1. **OpenStreetMap extract** (Geofabrik southern India, clipped to the boundary) for:
   - road centre-lines with names, hierarchy (`highway=*`), lane counts, one-way tags;
   - building footprints and heights where tagged;
   - parks, water, railways, landuse, amenities and shops.

   OSM is © OpenStreetMap contributors, under the ODbL. **Credit on the title or about screen is required.** Any database we derive and ship is subject to share-alike; the game's code and art are not.
2. **Elevation:** SRTM 30 m (public domain), smoothed. Central Bengaluru varies by roughly 20–30 m across the area. Roads are fitted to it with gradient limits.
3. **2007 validation layer**, recorded per feature in `docs/world/HISTORY_REGISTER.csv`:
   - OpenHistoricalMap, where it covers Bengaluru;
   - Google Earth historical imagery for 2006–2008 (viewed by you or me; not redistributed);
   - Wikimedia Commons photographs dated 2005–2008;
   - archived 2007 web pages on the Wayback Machine (hotel and mall sites, BMTC, newspapers);
   - Survey of India and municipal ward maps where available.
4. **Change detection:** features built after June 2007 are removed or replaced by what stood there, with "plausible reconstruction" status where the earlier state is unknown. Known examples to handle:

   | Feature | Built or opened | 2007 treatment |
   |---|---|---|
   | Namma Metro viaduct and stations | after 2007 | none; the M.G. Road boulevard and promenade are intact |
   | UB City | opened 2008 | under construction in 2007, to be verified |
   | Later flyovers and underpasses | various | to be dated individually |
   | Malls | Mantri Square 2010, Orion 2012, Phoenix 2011 | excluded |
   | Road widenings, one-way systems, renamed roads | after 2007 | reverted |
5. **Master-map output:** one GeoJSON-like file per region in a local metre grid (an equirectangular projection around Vidhana Soudha). It holds roads (centre-line, width, lanes, sidewalks, surface, condition), junctions, plots and footprints, landmarks, trees, poles and lights, and terrain height. Godot reads it at build time into streamed chunks.
6. **Master-map document** (`docs/world/MASTER_MAP.md`, plus generated images):
   - region boundaries;
   - road network view;
   - landmark positions;
   - asset coverage;
   - per-region status: research / data / built / verified.

**Credit and asset rules:**
- No assets, code or map style are taken from Nande Kano Bengaluru or any other game.
- Photographs are references only; nothing is copied into the game as a texture.

### 3.2 Confidence levels
Each feature in the history register is tagged with one of:
- **V:** verified for 2007, from a dated source;
- **P:** plausible reconstruction (it existed, but its exact 2007 look is unknown);
- **X:** excluded (did not exist in the window).

The source is recorded beside each one.

---

## 4. 2007 landmark and commercial-building verification plan

For each item: confirm it existed in the window, its 2007 name, its footprint and orientation (from OSM), its height and storeys, its distinctive elements, and its materials. It is modelled from dated photographs only.

What I already know, to be confirmed against sources:

| Item | Status before research |
|---|---|
| Vidhana Soudha (1956) | Existed |
| Attara Kacheri, now the High Court (1868) | Existed |
| Mayo Hall (1883) | Existed |
| St. Mark's Cathedral (1812) | Existed |
| St. Mary's Basilica | Existed |
| Visvesvaraya Museum (1962) | Existed |
| Nehru Planetarium (1989) | Existed |
| Bangalore Palace | Existed |
| Lalbagh Glass House (1889) | Existed |
| Bangalore Fort | Existed |
| Tipu Sultan's Summer Palace | Existed |
| City Railway Station | Existed; 2007 frontage to be verified |
| Kempegowda Bus Station | Existed; 2007 frontage to be verified |
| K.R. Market | Existed |
| Taj West End (1887) | Existed |
| The Oberoi, Bangalore (1992) | Existed |
| The Leela Palace (2001) | Existed (outside Phase 1) |
| ITC Windsor | Existed; **2007 name to be verified** (it was earlier the Windsor Manor) |
| Hotel Ashok (ITDC, Kumara Krupa) | Existed |
| Garuda Mall (2005) | Existed |
| The Forum, Koramangala (2004) | Existed |
| Bangalore Central, Residency Road | Opening date to be verified |
| "Eva Mall" | Name, location and date to be verified; not used until confirmed |
| UB City | Under construction in the window, to be verified |
| Namma Metro | No visible structures in the window (any early works to be checked) |

Street-level commercial life is researched per street from dated photographs and archived listings, and only verified long-running names are used: for example Koshy's on St. Mark's Road and Higginbothams on M.G. Road. Everything else gets **fictional but period-plausible** businesses, with no unlicensed real brand logos. Real 2007 brands (Airtel, Hutch, BPL, Bharat Petroleum, IOCL) appear only as generic period signage styles unless you approve trademark use.

---

## 5. Road and building asset architecture

### 5.1 Roads (generated from the master map at build time, then streamed)
- **Road mesh generator:**
  - curved centre-lines become a carriageway with camber, and a kerb and footpath on each side, with drain channels;
  - widths and lane counts come from the master map;
  - junctions get proper corner radii, kerb returns, zebra crossings and stop lines;
  - roads follow terrain heights with smoothed gradients.
- **Surface variety:** a single road shader on a material atlas (old asphalt, patched, worn, concrete, interlock, stone, dusty edge). A per-vertex condition index picks the mix. Wet puddles are masked by weather.
- **Markings:** decals, worn by condition, in period style (painted, not thermoplastic everywhere).
- **Road details** placed by rule: manholes, gutters, speed breakers (from OSM `traffic_calming`), patches, potholes where the condition is low.
- **Collision:** one simplified collision mesh per chunk (carriageway plus footpath slabs), used by the ground service for feet and wheels.
- **Traffic lanes** are derived from the same data: lane centre-lines with direction, turn connectors at junctions, stop lines, signals, crossings.

### 5.2 Buildings
- **Landmarks:** hand-modelled, one asset each, in Blender, scripted where possible. Silhouette and major elements first. LOD0, LOD1 and an impostor at distance.
- **Architectural families**, as modular kits per neighbourhood:
  - cantonment bungalows (tiled hip roofs, verandas);
  - colonial institutional buildings;
  - 1970s–90s concrete commercial blocks (Brigade and Commercial Street type);
  - 1990s–2000s glass-front office buildings;
  - old pete shophouses;
  - Jayanagar and Basavanagudi houses;
  - apartment blocks.

  Each kit has wall, window (with real depth), balcony, railing, cornice, roof, shutter and shopfront pieces. They are assembled on the real footprint, with storeys from OSM height or an estimate from photographs.
- **Shopfronts:** a kit of shutters, glass doors, display windows, awnings, signboards (Kannada and English, in period fonts), steps, AC units and tube lights. Interiors only where the shop can be entered; otherwise an interior-mapping shader fakes depth behind the glass.
- **Batching:** a family kit shares one texture atlas, so buildings in a chunk merge into a few meshes per material, with LOD per chunk.

### 5.3 Vegetation and infrastructure
- **Trees:** 8–10 species modelled as branch structure plus leaf-card clusters: rain tree, gulmohar, copperpod, neem, banyan, peepal, coconut, mast tree (Ashoka), pongamia, Indian cork (tabebuia). Each has 3 LODs plus an impostor. Placed from OSM trees and parks, plus avenue rules per road, verified against photographs.
- **Lights and poles:** period types (concrete and steel poles, single and double arms, sodium lamps with an orange tint, heritage lamps for Cubbon Park). Placed along roads at measured spacing.
- **Electrical network:** wires generated only between consecutive poles on the same side, with transformers at junctions.

---

## 6. Mobile on-foot HUD and RUN LOCK design

### 6.1 Layout (landscape, adjusted for safe areas and notches)
- **Left zone, the lower 60% of the left 40% of the screen: the movement stick.**
  - **Floating origin** with a **re-centre rule**: if the thumb drags beyond the outer ring, the origin follows it, so the stick never jumps.
  - A **dead zone of 12%** of the radius, and an **input curve**: gentle near the centre, full at the rim.
  - **Direction smoothing** at about 60 ms, plus a **±8° angular hysteresis**, so small jitter does not turn the character.
  - Movement is relative to the camera.
  - **Walk / run:** a push past 85% of the radius means run. Lighter means walk, with speed scaled to the push.
- **Right zone:** camera drag (anywhere not on a button) and **contextual action buttons**:
  - one large primary context button (Talk, Enter, Sit, Pick up, Get in), shown only when relevant, with an icon and a short label;
  - **Jump** and **Crouch** as small secondary buttons;
  - **Hit** only where fighting is allowed.
- **Top right:** pause, phone, map and camera mode as small icon buttons.
- **Style:** monochrome line icons, translucent discs (opacity setting 20–80%), a subtle ring when pressed, optional haptics (Android vibrate, 10–20 ms).

### 6.2 RUN LOCK interaction
1. The player pushes the stick upwards (within ±25° of camera-forward) past 85% of the radius and **holds it for 0.6 s** (configurable, 0.4–1.2 s). Short flicks never qualify.
2. A **lock chip** slides out **above the stick ring**, never under the thumb: a small padlock with a "RUN LOCK" label and a filling arc that shows the hold progress.
3. To engage, the player **slides the thumb up onto the chip and releases** there, or taps it with the thumb within 2 s.
   - The chip turns solid, with a running icon and a padlock.
   - A small icon also appears near the minimap.
4. **While locked:** the character keeps running with the thumb lifted. Touching the stick again **steers without cancelling** the lock; the direction follows the stick, and with no touch, the camera's forward.
5. **Cancel** by any of:
   - tapping the chip, which shows an "×" while locked;
   - pulling the stick firmly backwards, more than 60% of the radius toward the player;
   - context stops: a cutscene or dialogue, interaction prompts that take control, entering a vehicle, swimming or falling, the run stamina system (if one is added);
   - running into a wall, detected as a blocked velocity for 0.3 s: the character stops and the lock releases.
6. **States** are distinguishable at a glance:

   | State | Stick ring | Chip |
   |---|---|---|
   | Walk | thin grey | none |
   | Run | bright | none |
   | Run lock available | bright | appears and fills |
   | Run lock active | bright | solid amber |
   | Run lock off | — | fades out |

7. **Tests:**
   - automated injected-touch tests: flicks under 0.6 s must never lock; holds must; steering keeps the lock; a backward pull cancels it; a wall cancels it;
   - **on your phone**, with an on-screen touch-trace overlay in a test build.

### 6.3 Camera
- Drag input runs through a velocity curve with acceleration and an exponential decay of about 80 ms. Sensitivity is in settings.
- Smoothing on the angles, not on the positions, so fast drags don't jitter.
- Auto-recentre behind the character after 2 s without touching the camera while moving.
- **Collision:**
  - a sphere cast instead of a ray, so the camera doesn't clip into walls at the edges;
  - pull in fast, ease out slowly;
  - fade near objects instead of popping;
  - the character shows through thin occluders (a dither-fade shader on foliage and poles).
- Smooth blends into conversation and interaction framing (already partly present).

### 6.4 Settings (saved in the existing settings file; the save format stays compatible)
- camera sensitivity (X and Y);
- stick size;
- button size;
- HUD opacity;
- left-handed mirror;
- run-lock hold time;
- haptics on/off;
- reset layout.

---

## 7. Driving control architecture

### 7.1 Vehicle physics (replacing the kinematic y = 0 model)
- Keep `Vehicle` as the gameplay object, but give it a **raycast-wheel model**: a light custom solver, chosen over Godot's VehicleBody3D for stability and cost on mobile.
  - Per wheel: a suspension spring and damper, contact on the ground and road collision, and a tyre force from slip angle and slip ratio (a simplified Pacejka curve).
  - The body is a RigidBody3D with a lowered centre of mass, so it pitches, rolls and responds to speed breakers and kerbs.
- **Handling profiles** (data, per type):

  | Parameter | Examples |
  |---|---|
  | Mass, wheelbase, track | |
  | Centre-of-mass height | |
  | Spring and damper rates | |
  | Steering | maximum angle, rate, return speed, speed-sensitive reduction |
  | Engine | torque curve, gear ratios (automatic shifting) |
  | Brakes | brake force and bias |
  | Grip | tyre grip |
  | Body | roll stiffness |
  | Quirks | auto: three wheels, easy to tip in sharp turns; two-wheelers: balance and lean model; bus and lorry: slow steering, long braking, high centre of mass |

  Ambassador saloon, Maruti 800 type, Omni or Qualis type, Hero Honda / Bajaj two-wheelers, Bajaj RE auto and Tata or Ashok Leyland buses are all modelled as fictionalised period-style vehicles, without brand names or logos.
- **Traffic AI** vehicles use the same physics near the player and a cheap kinematic lane-follower when far away.

### 7.2 Driving HUD (separate layout from on foot)
- **Left thumb, steering:** a **horizontal slider pad**. The thumb lands anywhere on it; left–right offset gives an analogue steer with a dead zone, and the wheel returns to centre on release.
  - Alternative options in settings: tilt steering (accelerometer, with a calibration step) and arrow buttons.
- **Right thumb:**
  - **accelerator:** a tall pedal; variable throttle by vertical position on the pedal;
  - **brake:** a pedal; holding it at a standstill engages reverse after 0.4 s, and the indicator shows "R";
  - **handbrake:** a small button;
  - **horn:** a large, easy button (Bengaluru driving requires it).
- **Top area:** exit vehicle, camera, radio, indicators.
- **Gauges:** a speedometer and gear indicator in a corner, period-styled.

### 7.3 Driving camera
- A spring-arm chase camera tuned per vehicle class (height, distance, field of view).
- **Look-ahead** in the turn direction and toward the velocity.
- Distance and field of view grow with speed.
- Sphere-cast collision.
- Recentres after manual orbiting.
- A low, close bike camera for two-wheelers.

### 7.4 Tests (each vehicle class)
Automated scripted runs and recorded footage of:
- start from rest, slow movement, full throttle;
- gentle and sharp turns, braking distance, reverse, parking;
- narrow streets, junctions, speed breakers, kerbs, uneven surfaces;
- collisions, getting in and out.

**Feel on a touchscreen must be tested on your phone.** I will provide a test APK with input traces.

---

## 8. Performance risks and mitigation

| Risk | Mitigation |
|---|---|
| Real-scale streets mean many more buildings and props in view | Chunk streaming (kept); per-chunk merged meshes by material; MultiMesh for trees, poles and props; visibility ranges per class; impostors for distant buildings |
| Draw calls on mobile GL ES | Texture atlases per family kit; shared road shader; at most about 300 visible draw calls (**target, to be measured**) |
| Detailed trees | 3 LODs plus impostor; leaf-card counts capped; no shadows from trees beyond about 40 m |
| Dynamic streetlights at night | Only the nearest 8–12 real lights; others are emissive lamps with baked light pools (decals) on the road |
| Shadows | One directional light with 2 splits (current); short shadow distance; static objects' AO baked into vertex colour |
| Raycast-wheel physics for traffic | Full physics only within about 60 m of the player; kinematic lanes beyond |
| Texture memory | ETC2/ASTC compression for all world textures (currently character textures are uncompressed); mipmaps; 1024 maximum for kits, 2048 for landmarks |
| Loading hitches | Chunk builds spread over frames; prebuilt chunk scenes from the build-time map instead of generating at runtime |
| Data licence | OSM credit and ODbL compliance noted above |
| Measurement | No figures without measurement. A profiling build with an on-screen overlay (frame time, draw calls, memory) for your device. No phone is connected to this session. |

---

## 9. What I need from you

1. **Network:** allow `overpass-api.de` and `download.geofabrik.de` (map data), plus `opentopography.s3.sdsc.edu`, `commons.wikimedia.org`, `upload.wikimedia.org` and `web.archive.org` (elevation and historical references), in the environment's network settings. Stage 1's real master map cannot be built without them.
2. **Approve the Phase 1 boundary:** Central Bengaluru, about 3.3 × 3.3 km, at **real 1:1 scale**, with the existing compressed world kept until it passes its gate.
3. **Approve the OSM licence credit** (ODbL attribution on an about/credits screen).
4. **Brands:** fictional period-style shop and vehicle brands (my default), or real 2007 brands where you hold permission.
5. **The "rotating movement bar":** confirm that it means the floating left stick, or describe the control you had in mind.
6. **Order:** the controls (Stages 6–7) do not depend on the map data. With your approval they could proceed while the network access is being sorted out.
