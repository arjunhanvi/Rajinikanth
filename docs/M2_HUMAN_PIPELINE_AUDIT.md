# BIG BANG LORE: human pipeline audit and Phase A foundation

This report covers Phase A (audit and technical foundation) for the Raja quality prototype. Nothing in the character pipeline has been changed for it.

The **evaluation scene** is `tools/dev/lookdev.tscn`. It renders a fixed set of views (anatomy, face, hair, clothing) under nine fixed lighting presets:

| Preset | Light |
|---|---|
| studio | key light, soft fill, rim from behind |
| sun | morning sun with blue-sky fill |
| shade | open shade: sky light only |
| overcast | grey sky, soft top light |
| indoor_warm | tungsten bulb |
| indoor_cool | tube light |
| side | hard side light |
| back | light from behind, face in shadow |
| low | evening: weak warm practical light, cool ambient |

Tone mapping matches the game: filmic, exposure 0.95.

Run it with:
```bash
godot --path . --resolution 1600x900 res://tools/dev/lookdev.tscn -- raja <out_dir>
```

**Baseline renders:**
- individual shots: `docs/m2/baseline/*.jpg`;
- anatomy contact sheet: `docs/m2/sheet_anatomy.jpg`;
- face contact sheet: `docs/m2/sheet_face.jpg`;
- face under each lighting preset: `docs/m2/sheet_light_face.jpg`;
- body under each lighting preset: `docs/m2/sheet_light_body.jpg`.

**Baseline movement footage:** `build/m2/raja_proto.mp4`, 64 s, recorded before the last running fix.

## Classification legend

| Code | Meaning |
|---|---|
| **1** | Implemented and visually verified (it looks right in the renders) |
| **2** | Implemented but visually defective |
| **3** | Implemented but not tested |
| **4** | Missing |
| **5** | Technically unsuitable and needs replacement |

## 1. What Raja is made of today

The model is generated offline (`tools/humans/*.py`) from the MakeHuman 1.x base mesh (CC0) using MakeHuman's morph targets, then exported to `assets/humans/raja.glb`.

**Runtime model at full detail (LOD0):**

| Item | Count |
|---|---|
| Triangles | 75,595 in total (17,174 head and arms; 36,000 hair cards; 4,688 feet; 4,222 shoes) |
| Meshes | 17 (each its own draw call, plus shadow passes) |
| Bones | 55 |
| Face morph targets | 13: blink L/R, brow up/down/sad, smile, frown, jaw open, lips part, pucker, wide, squint, sneer |

**Animation:** all procedural.
- `Human.gd` (1273 lines) handles posture, gestures, face, gaze and blinks.
- `Gait.gd` (711 lines) handles feet, legs, pelvis, sitting and arm reach.
- There are no animation clips or motion capture.

**Renderer:** GL Compatibility (OpenGL ES 3).
- MSAA is off.
- Character textures are imported **uncompressed**, so there is no ETC2/ASTC compression on Android.

## 2. Subsystem audit

| Subsystem | Code | Finding (from the baseline renders and the asset inspection) |
|---|---|---|
| Source body mesh | 2 | The MakeHuman base mesh is a sound quad mesh (about 13k vertices) with edge loops round the eyes and mouth, built for subdivision. Proportions are plausible from all four sides. But it is a smooth, average mesh: the clavicles, sternum, scapulae, deltoid edges, knuckles and patella barely register (a01–a05). It reads as a mannequin with a texture. |
| Head and face geometry | 2 | Built from about 20 shape targets ("Shankar Nag reference"). The face is symmetrical. It has a generic MakeHuman look: soft jaw, generic ears, a thin lip outline, flat temples. MakeHuman's **asymmetry targets are available but unused**. |
| Skeleton | 5 | 55 bones, all with identity rest orientation. **Missing:** a jaw bone, eyelid bones, lip and cheek bones, toes, twist bones, a separate chest bone. The full MakeHuman rig (163 bones, with jaw, eyelid, lip, cheek and brow bones, a tongue chain, 10 toe bones, and artist-made weights) is in the source data but not used. |
| Skin weights | 2 | MakeHuman game-rig weights with linear-blend skinning. No twist bones, so the forearm twists like a candy wrapper and the shoulder loses volume. No corrective shapes. |
| Facial rig and blend shapes | 5 | 13 coarse whole-face morphs: one smile, one frown, no visemes, no eyelid shapes for gaze. MakeHuman's **60 facial pose units** are unused: individual brows, lids, cheeks, nasolabial, every lip direction, jaw drop, tongue. |
| Expressions | 2 | Five moods mix those 13 morphs. The faces change, but expressions are mild, mostly mouth and brows, and snap between moods. f10 shows four similar faces. |
| Eyes | 2 | A textured sphere: no cornea, no wet tear line, no eye-occlusion shadow. A hard **painted dark band** under each eye (f04) reads as make-up. Gaze rotates the eye bones toward a target, but there are no idle gaze shifts (saccades). |
| Mouth, teeth, tongue | 2 | Teeth and tongue exist. **The teeth show as a white line through the closed lips** (f05). Lip shape is thin, with no clear vermilion border. Speech is the jaw opening and closing (no visemes). |
| Skin material | 2 | Custom wrap-lit shader: pores as a tiled micro-normal, varied roughness. Problems:<ul><li>a **hard tone edge down the cheek** from the stubble mask's cut-off (f03, all lighting presets);</li><li>the whole face reads airbrushed;</li><li>roughness is not mapped by region;</li><li>no cavity or AO map;</li><li>orange under tungsten light (`l_indoor_warm`).</li></ul> |
| Skin textures | 2 | Painted procedurally from 3D position (2048 px for Raja). Detail does not follow real anatomy, and there are no wrinkles. |
| Head hair | 2 | 3000 alpha-cut strand cards over a black scalp cap. It has volume, but:<ul><li>the hairline is **stepped** at the temples and the nape (f02, f06);</li><li>the mass reads as solid black (no light gets into it);</li><li>there is a white specular streak (f06);</li><li>without MSAA, card edges look hard.</li></ul> |
| Hair movement | 3 | One spring on the head moves the whole hair mass in the vertex shader. Not verified visually. There is no per-region motion and no collision. |
| Eyebrows | 5 | Painted into the skin texture: they read as **painted bars** (f04). |
| Moustache | 5 | Alpha shells cut from the upper-lip skin; the edges break into jagged shards (f08). A shell cannot give a moustache strand direction or a natural silhouette. |
| Sideburns | 4 | Only the edge of the scalp cap. |
| Clothing | 5 | The shirt is cut from MakeHuman's "tights" helper surface: skin-tight, no thickness, folds faked with noise, a flat collar, a painted pocket (a10). The **shoes show moulded toes** (a08, a09) because they follow the foot. The watch is a plain black band. |
| Fabric materials | 2 | One generic cloth material with a tint: no fabric weave, no sheen, no denim or leather response. |
| Locomotion | 2 | Procedural gait (works without animation clips):<ul><li>feet lock in stance; heel strike and toe-off;</li><li>the pelvis shifts weight;</li><li>arms and shoulders counter-swing.</li></ul>Flat walking and stairs look right in the footage. **Running is defective:** a lunge at the walk-to-run switch and a crouched stride. A fix is committed (`8c97b62`) but its recording was cancelled, so it is unverified. Idle weight shift is subtle. Turning goes in steps. |
| Ground contact and IK | 1 / 2 | Ground service, foot locking, two-bone leg IK, slope-aware foot roll, stair footfalls: visually good on flat ground, kerb and stairs. One run of numbers showed a regression after sitting; it was fixed and re-recorded. The ramp toe-off sink is fixed but not re-verified. |
| Sitting and standing | 1 | The pelvis is placed on the seat; hands rest on the thighs; the body leans forward to stand. |
| Hand interaction | 2 | Arm IK lands the palm (1 cm on glass and chest). But:<ul><li>there are **no grip poses**: fingers do not close around the cup;</li><li>no palm orientation to the surface;</li><li>the railing hand floats;</li><li>no doors.</li></ul> |
| Human-to-human contact | 2 | The push lands on the chest. The receiver is moved by script, with no balance reaction. No handshake or shoulder poses. |
| Idle life | 2 | Breathing, blinks, weight shift and posture presets exist. No saccades, no micro-expressions; the chest does not visibly breathe under the shirt. |
| Animation layering | 2 | One large `_process` composes everything by adding and overwriting fixed values in a fixed order (posture, then gesture, then gait, then IK). It works but is hard to extend; layers overwrite one another, for example arm swing against posture arms. |
| Lighting (character) | 2 | The game scene is over-exposed and flat on pale paving. In the evaluation scene:<ul><li>side and back light hide the face (expected);</li><li>indoor warm light goes orange;</li><li>no contact shadows or AO, so feet and hands lack grounding.</li></ul> |
| LOD | 1 | Three levels (75k, 20k and 3k triangles). Hair cards are dropped at LOD2. Distance-based update skipping exists. |
| Android performance | 3 | **Never measured on a phone.** Problems visible without a device:<ul><li>uncompressed textures (a 2048 texture is about 21 MB of video memory with mipmaps);</li><li>36k hair triangles;</li><li>17 draw calls per character.</li></ul>Requires a real device (none is attached to this session). |

## 3. Technical approach per subsystem (for approval)

The plan keeps everything that works: the procedural locomotion and IK, the ground service, LODs, the opening, the story and all game systems. It replaces the unsuitable parts in the agreed order.

**New capability:** Blender 5.3 runs here as a Python module (`bpy`). That makes possible:
- subdivision and sculpt-style displacement;
- baking normal, AO and cavity maps from a high-resolution source onto the runtime mesh;
- weight transfer;
- cloth simulation baked into fold shapes.

All of it stays scripted and reproducible.

### Phase B: anatomy, skeleton, skinning
- **Rig:**
  - Switch Raja to MakeHuman's full 163-bone rig and its artist-made weights, reduced for mobile to about 110 bones: body, jaw, eyelids, lips, cheeks, brows, tongue, 2 toes per foot.
  - Add upper-arm and forearm twist bones.
  - The gait, IK and posture code is retargeted to the new bone names; the logic is unchanged.
- **High-resolution source mesh:** the MakeHuman base subdivided twice in Blender, about 200k vertices, offline only. Add anatomy with region-masked displacement layers placed from the skeleton and landmarks:
  - clavicle and sternum, trapezius edge, deltoid separation, scapula;
  - abdominal and oblique planes;
  - patella, tibial crest, ankle bones;
  - knuckles, finger pads, palm creases, nail beds.
- **Runtime mesh:** the existing roughly 13k-vertex mesh, with all that detail baked into a 2048 normal map and an AO map.
- **Asymmetry:** apply MakeHuman's asymmetry targets at low strength (brow, eye, cheek, ear, mouth, nose), different for Raja and for Lal.
- **Correctives:** shoulder, elbow, knee and hip shape keys, generated in Blender by volume-preserving smoothing of the posed mesh. Godot blends them by joint angle (pose-space deformation) in `Human.gd`.
- **Feet:** shoes become a real shoe shell with a toe box and a sole, not a sock over toes.

**Gate B:** neutral-pose renders front, side, back and three-quarter, plus hands and feet, compared with the baseline.

### Phase C: face and skin
- **Facial expressions:** built from the 60 MakeHuman facial pose units on the new face bones, plus a corrective morph for each key shape.
  - An expression library combines them: neutral, relaxed, alert, suspicious, confused, angry, frustrated, sad, amused, nervous, focused, exhausted, pain, subtle smile, laugh.
  - Transitions blend over 0.2–0.6 s.
  - Micro-expressions are small random brow, lid and mouth weights.
- **Visemes:** about 9 mouth shapes (AA, E, I, O, U, M/B/P, F/V, L, rest) from the same pose units. They are driven from the line's text timing, since the Kannada dialogue has no phoneme data.
- **Eyes:**
  - separate cornea mesh (glossy, transparent);
  - iris with a parallax depth shader;
  - sclera with veins and a warm rim;
  - a tear-line strip;
  - an eye-occlusion mesh (a soft shadow wedge under the lids);
  - eyelids follow vertical gaze;
  - saccades (small eye jumps) and attention targets.

  The painted under-eye band goes.
- **Mouth:**
  - lips with a proper vermilion border and lip-crease normal detail;
  - teeth and gums pushed back and darkened by an inner-mouth occlusion term, so closed lips never show a white line.
- **Skin:**
  - textures painted per anatomical region: forehead lines, crow's feet, under-eye folds, nasolabial folds, lip lines, pore density varied by region;
  - a separate roughness map (oily T-zone, drier cheeks), a cavity map, and a thickness map (ears and nostrils glow at the light terminator);
  - stubble as a follicle density map without hard masks;
  - all 2048 for the face, compressed with ASTC/ETC2.

  The shader keeps wrap lighting plus a terminator glow (subsurface scattering is not available in this renderer) and adds region specular.
- **Lighting test:** every lighting preset, with skin tone checked against a reference card under each.

**Gate C:** face close-ups (front, side, three-quarter, eyes, mouth), the expression sheet, and the face under all nine lighting presets.

### Phase D: hair
- **Groom:**
  - guide curves grown from a scalp density map (hairline falloff, crown whorl, side parting, sideburn transition), with clumping and noise;
  - root-to-tip colour and a grey-brown variation in the black;
  - cards generated along clumps in 3 layers (base, mid, fly-aways), with tapered tips;
  - the hairline uses thin, single-strand cards instead of a hard scalp edge;
  - the scalp gets a soft root-density texture instead of a solid black cap.
- **Shading:** Kajiya-Kay-style highlight with a shifted secondary highlight (anisotropic look) using per-vertex tangents, plus root occlusion.
  - **MSAA 4×** with alpha-to-coverage for card edges. This is a project setting; its cost on a phone must be measured first.
- **Eyebrows and moustache:**
  - groomed fibre geometry: about 400–700 thin strands, each 1–3 hairs wide;
  - the direction is groomed (brow: medial up, lateral out; moustache: down and out from the philtrum);
  - density falls off at the edges, and the colour is varied.

  This replaces the painted brows and the shell moustache.
- **Motion:** 6–8 spring chains (fringe, crown, sides, back), simulated in GDScript on the CPU.
  - Each chain is driven by head acceleration and wind, with damping.
  - A sphere collider on the head and one on each shoulder keeps hair out of the body.
  - The vertex shader skins each card by its chain weight.
  - Turned off beyond 15 m.

**Gate D:** hairline, top and side close-ups, plus a video of the hair turning, walking, running, stopping and in wind.

### Phase E: clothing
- **Garments:**
  - the shirt is modelled as a real garment shell in Blender: thickness by solidify, a collar band and points, placket, yoke and shoulder seams, sleeve hems, a pocket, button geometry;
  - the trousers likewise: waistband, fly, hem, belt loops.
- **Fit and folds:**
  - one cloth simulation in Blender drapes the shirt in the rest pose;
  - five more simulations give fold shapes: arm raised, elbow bent, torso twisted, sitting, bending;
  - in the game these are blended by joint angle, the same way as the body correctives;
  - the shirt-tail is weighted to the pelvis with a small spring.

  There is no real-time cloth simulation; on Android it would cost too much.
- **Fabric materials:**
  - cotton: weave normal, low sheen;
  - denim: twill weave, darker in the folds;
  - leather belt and shoes: polished roughness and creases;
  - each with fabric-scale detail textures, mixed in the shader by a material ID.

**Gate E:** shirt close-up; arm raise, twist and bend; sit and stand.

### Phase F: movement
Keep and extend the gait system:
- head stabilisation (counter-rotation keeps the gaze level);
- stride variation;
- anticipation before a start (a weight shift onto the support foot);
- deceleration steps with body settle;
- head-leading turns: eyes, then head, then shoulders, then pelvis, then feet;
- a run that is its own motion: knee lift, push-off, landing compression;
- posture sets that change pelvis tilt, spine curve, shoulder height, foot spacing and hand tension per state (relaxed, confident, defensive, nervous, angry, tired, alert, curious).

The animation code is reorganised into explicit layers (base locomotion, then posture, then gesture, then look-at, then IK, then secondary motion), each with its own weight, so they blend instead of overwriting.

**Gate F:** fixed-camera videos of each movement (toward, away from and side-on to the camera; run; stop; turn; stairs and ramps).

### Phase G: interactions
- **Grip library:** finger poses for cylinder (cup), bar (rail), flat (table, door, chest), handshake and shoulder.
- Contact alignment: the palm normal is set to the surface normal, and fingers curl until they touch the object's collision shape (a ray per finger).
- A door with a handle.
- Hand-to-hand and hand-to-shoulder contact.
- A push response on the receiver: the impulse drives the gait's balance steps, upper-body sway and a hand that comes up to protect.
- Body separation becomes capsule-against-capsule.

**Gate G:** cup, railing, door, handshake, push footage.

### Phase H: integration and optimisation
- Character textures compressed with ETC2/ASTC.
- Material count reduced through atlases (skin, eyes and mouth in one atlas).
- LOD rebuilt from the new mesh.
- Animation LOD: face and hair off beyond about 15 m; the full gait near the camera only.
- Lighting pass on the campus (paving albedo, contact shadow blob, ambient).
- A profiling build, which requires a phone. I cannot measure phone performance here and will not claim any figure until it has been measured.

## 4. Limits I want you to know about before approving

1. **Renderer.**
   - GL Compatibility has no subsurface scattering, no SSAO and no temporal anti-aliasing. In Godot 4.3 those are in the Forward+ renderer (desktop-class GPUs), not in Mobile or Compatibility.
   - Everything above is designed to fake them in shaders and baked maps.
   - Close-up skin will still look a step below RDR2, which uses true subsurface scattering, ray-traced or baked lighting and temporal anti-aliasing.
2. **Sculpting.**
   - I can build anatomy procedurally (placed displacement layers, MakeHuman targets, asymmetry), and that will clearly improve on the mannequin look.
   - It is not a substitute for an artist sculpting a specific face. For the closest likeness to the Raja reference, the best result would come from an artist-sculpted head (commissioned, or a licensed scan) dropped into this same pipeline:
     - the pipeline can wrap any head onto the MakeHuman topology;
     - all rigs, maps, hair, eyes and animation would carry over.
   - Note that Epic's MetaHuman licence restricts those characters to Unreal Engine, so MetaHumans cannot be used in this Godot game.
3. **Motion.** There is no motion capture. Movement stays procedural with IK, which is good for contact and terrain but less nuanced than captured performance. Adding a small set of CC0 or licensed mocap clips (idles, gestures) as a base layer under the procedural system would help body language most.
4. **Performance.** All of this must be profiled on your target phone. I can build a profiling APK with an on-screen frame-time and draw-call overlay for you to run, since no device is connected to this session.

## 5. Decisions needed from you at this gate

1. **Approve the approach** for Phases B–H as written, or change it.
2. **Head source:** procedural improvement only (fully in-house; likeness limited), or plan for an artist-made or licensed head later (higher ceiling; outside cost).
3. **MSAA 4×** for hair edges: accept that it costs GPU time on phones (to be measured), or keep it off and rely on alpha-blended hair edges.
4. **Mocap base layer:** allowed (CC0 or licensed clips), or keep everything procedural.
