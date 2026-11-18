# Raja: quality reconstruction audit and proposal

## 1. Is the MakeHuman foundation sufficient?

**As a topology base, yes. As final geometry, no.** Reconstruction is required.

| Layer | Finding | Verdict |
|---|---|---|
| Base topology | A quad mesh with proper loops round the eyes, mouth and nose, designed to deform; it is used professionally as a sculpting start point. | Keep as the topology base |
| **Face resolution** | Measured: **about 4,100 vertices for the whole face** (4,474 above the neck). At close-up, eyelid thickness, lip edges, the mouth corners, the nostril rims and the ear folds are faceted. No normal map can fix a silhouette. | **Rebuild:** subdivide the head for the close level, then reshape |
| **Proportions and identity** | Raja is a blend of about 25 statistical MakeHuman sliders, so he inherits the generic "MakeHuman face". He was never fitted to the reference. | **Rebuild:** fit to the reference photos |
| High-frequency anatomy | None: the face and body are smooth average surfaces. Pores and creases are only a tiled texture. | **Build:** a sculpt-detail bake |
| Skin textures | Painted procedurally from 3D position. The head shares one 2048 atlas with the whole body, so the face gets only about **a quarter of the texels (roughly 1024 px)**. There is no thickness map (for light through ears and nostrils), and broad-scale roughness is only by region. | **Rebuild:** a head-only texture set and anatomy-driven painting |
| Hair | Cards on a scalp ramp plus fibres. There is no groom (no guide curves, no clumping), cards are a single layer, and the shading has no strand direction (the mesh has no tangents). | **Rebuild** as a guide-curve groom with layered cards and strand-direction shading |
| Facial rig | 60 MakeHuman pose units baked to morphs. Good coverage, but **no corrective shapes** for combinations, and the lid and lip shapes are limited by the low face resolution. | Keep the method; re-bake on the rebuilt head; add correctives |
| Body skeleton and skinning | 55 bones, linear-blend skinning, **no twist bones and no corrective shapes**. The shoulders and wrists lose volume. | **Extend:** twist joints for the forearm and upper arm; corrective shapes for shoulder, elbow, knee and hip |
| Clothing | The shirt is an offset of the body ("tights") with displacement folds, a collar band and hems. **No real pocket or buttons, no seams, no cloth behaviour.** | **Rebuild** as a garment: Blender cloth drape plus pose-space fold shapes |
| Animation | All procedural. In the footage: a wide-legged crouch (along the railing), over-long strides, a running lunge, the heel into a kerb, no finger grip, the railing hand floating. | **Fix the mechanics** (causes in section 3) |
| Renderer | GL Compatibility (Android OpenGL ES 3). **There is no subsurface scattering, no SSAO and no temporal anti-aliasing in this renderer**; in Godot 4.3 those are only in Forward+ (desktop-class GPUs). The rendering method is project-wide and cannot be switched per device at runtime. | Stay on it, and fake those effects in shaders and baked maps. **This caps how far skin and hair can go on a phone.** |
| Performance | Never measured on a device; no phone is attached to this session. The close level is now about 104,000 triangles. Character textures are uncompressed. | Measure with a profiling APK on your phone |

## 2. Honest ceiling

With the current renderer and an Android target, **parity with RDR2 is not achievable**. RDR2's people rely on scanned heads, true subsurface scattering, temporal anti-aliasing and a console GPU. What is achievable, and what I am proposing, is the **best result this engine and renderer allow on a phone**: correct anatomy and identity in the geometry, a full skin texture set with faked light scattering, a groomed hair system, a real garment, and sound body mechanics.

## 3. Animation defects and their causes (from the code)

| Defect | Cause | Fix |
|---|---|---|
| Wide-legged crouch | The stance width is fixed at 11.5 cm per foot regardless of speed. When the body is moved sideways (the railing path), the feet are placed for a diagonal heading, so the stance widens and the hips drop to reach | Make stance width depend on speed and heading. Plant feet relative to the direction of travel, and turn the body toward it before stepping |
| Over-long strides | The footfall prediction uses (remaining swing + half a stance) × speed, plus an acceleration term. At start-up the acceleration term over-reaches | Cap step length with a stride-length versus speed curve taken from human gait data (about 0.75 m per step at 1.4 m/s) |
| Running lunge | At the switch from walking to running, a foot planted during the walk can sit more than 0.5 m behind | Catch-up swing (added), plus a cap on stride length while running |
| Heel into the kerb | At the far edge of the kerb, the "keep the whole foot on one tread" check samples only along the direction of travel. A foot placed at an angle straddles the edge | Sample heel, ball and toe in the foot's own direction; slide the step to one level |
| No finger grip; railing hand floats | The arm IK places the palm only. There are no finger poses, and the railing target is aimed beside the rail | Grip library (cylinder, bar, flat), each finger curling until it touches; the railing target on top of the rail, with the palm turned down |
| Stiff upper body | The torso counter-rotates by a single value | Split it across the spine, chest, neck and head; stabilise the head; delay the arm swing slightly behind the legs |

## 4. Reconstruction stages (each one: generate, render in Godot, compare, inspect from every angle, list defects, commit)

| Stage | Work |
|---|---|
| **R1: body mechanics** (no dependencies, start now) | Fix every defect in section 3; grips; head stabilisation; spine distribution. **Gate:** walk toward, away and side-on, plus run, stop, turn, kerb, stairs, sit, stand, cup, railing and push footage, all from fixed cameras. |
| **R2: head geometry** (needs the reference photos) | <ol><li>Detect 478 face landmarks on the reference photos (MediaPipe, available here).</li><li>Optimise MakeHuman's face targets, then a smooth free-form correction, so the 3D head matches the front and profile proportions.</li><li>**Subdivide the head once** for the close level, giving about 16,000 face vertices.</li><li>Build eyelid thickness, the lip vermilion edge and corners, nostril cavities and ear folds into the geometry.</li><li>Asymmetry from the photo itself.</li></ol>**Gate:** front, profile, three-quarter, high and low views beside the reference. |
| **R3: skin** | A head-only texture set at 2048 (about **4×** the current face resolution): albedo with real colour regions (redness, pigment, beard shadow), a three-scale normal map (anatomy bake + creases + pores), roughness, cavity and a **thickness map** (backlit ears and nostrils), and specular occlusion. Compressed for Android. **Gate:** all nine lighting setups, plus close-ups. |
| **R4: hair groom** | Guide curves (parting, crown whorl, a hairline traced from the photo); clumping and stray hairs; three card layers; mesh tangents exported so highlights run along the strands; a scalp root-density texture; facial hair re-groomed on the new head. **Gate:** front, back, profile, three-quarter and from above; a motion clip. |
| **R5: body anatomy** | Muscle and definition targets; an anatomy normal map baked in Blender (clavicles, sternum, scapulae, deltoids, knuckles, kneecaps, tendons); corrective shapes for shoulder, elbow, knee and hip; twist joints. **Gate:** neutral and extreme poses, from four sides. |
| **R6: clothing** | The shirt and trousers modelled in Blender as garments: thickness, collar, placket, real buttons and pocket, seams; cloth simulation for the drape and for fold shapes (arm up, elbow bent, sitting, twisting); blended by joint angle in the game; a sprung shirt-tail. **Gate:** clothing motion clips. |
| **R7: integration** | A full evaluation run with before/after from identical cameras, plus a **profiling APK** with a frame-time, draw-call and memory overlay for you to run on your phone. |

## 5. What I need from you

1. **The Raja reference photos (Shankar Nag)**, ideally a front view and a profile. They existed only as chat attachments and are not in the project. Please add them to `assets/references/raja/` or attach them again. **R2 (identity and face geometry) cannot be done properly without them**, and I will not invent the face.
2. **Texture and geometry budget for Raja alone:** a separate 2048 head texture set (about 5–8 MB of video memory when compressed) and about 12,000 more face triangles at close range only. Both will be measured on your phone in R7 and reduced if needed.

I start **R1 (body mechanics)** now, since it depends on neither.
