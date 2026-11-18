# Raja rebuild: progress and honest status

Every image here is the **real Godot-rendered character**, from:
- the fixed evaluation scene `tools/dev/lookdev.tscn` (the same cameras and nine lighting setups as the Phase A baseline);
- the game itself (motion footage).

Raja is **not finished**, and I am not asking for final approval. I am asking for your verdict on the direction of the face and hair work before the remaining stages.

## Done and visually checked

| Stage | What changed | Evidence |
|---|---|---|
| **B1: face surface** | <ul><li>Eye cornea shells (real wet highlight).</li><li>Eye-occlusion shells.</li><li>The **painted dark under-eye bands removed**. The cause was MakeHuman's eyelash helper strips drawn as a half-transparent solid.</li><li>**Lips meet at rest**, with the teeth set back and darkened: no white line of teeth.</li><li>A region roughness and cavity skin map (oilier T-zone, drier cheeks, pores and creases).</li><li>Softer eye sockets.</li><li>The skin shadow edge softened, as light scattering in skin does, so there is **no hard line across the cheek**.</li><li>Deliberate facial asymmetry (brow, eye, cheek, nose, mouth, jaw, ear, temple).</li></ul> | `docs/m2/b1b2/before_after_face.jpg`, `sheet_face.jpg`, `sheet_light.jpg` |
| **B2: hair** | <ul><li>**Eyebrows, moustache, sideburns, eyelashes and hairline** rebuilt as groomed fibres. Each is about 1 mm wide and carries 1–3 tapered strands. They are rooted by a density map, so edges thin naturally, and grown in the real direction of each region.</li><li>The scalp is an alpha-blended density ramp.</li><li>Hair-card roots fade in, so **there is no stepped hairline anywhere** (front, temples, sides).</li><li>Hair now has a broad sheen plus a tight highlight, so it reads as volume, not a helmet.</li></ul> | same sheets |
| **B3: face rig** | <ul><li>MakeHuman's **60 facial pose units**, skinned through its full 163-bone face rig (jaw, lids, lips, cheeks, brows), are **baked into morph targets** on Raja's own mesh. The body stays on the light 55-bone skeleton for the phone.</li><li>Expressions: **neutral, happy, irritated, angry, confused (asymmetric), nervous, tired, surprised**, plus smirk. The brows, lids, cheeks and mouth corners all take part, not just the jaw.</li><li>**Speech is a sequence of mouth shapes** (open, wide, round, closed, lip to teeth) instead of a jaw sine wave.</li><li>The hair fibres follow every expression.</li></ul> | `docs/m2/b3/sheet_expressions.jpg` and the individual frames |
| **B5 step 1: shirt** | A collar band that turns down into points; turned hems (visible fabric thickness); folds placed where a worn shirt makes them (over the belt, from the armpits, on the sleeves); a looser fit. | `docs/m2/b5/sheet_shirt.jpg` |
| **Motion (verify)** | **Running fix confirmed** in footage: planted-foot ground error 0.3 cm, slide 0.5 cm. Walking on flat ground and stairs, sitting, standing, reaching, drinking and the push all read correctly. | `build/m2/raja_motion_b3.mp4`, `docs/m2/b3/motion_1fps_sheet.jpg` |

## Defects found in the footage and renders (not fixed yet)

1. **Walking along the railing:** Raja walks with a **wide-legged crouch**, at 45–50 s in the footage.
2. **Running:** one **deep lunge** stride still appears, at about 57 s.
3. **Kerb:** stepping down off the far edge of the kerb block, one sample shows the heel 13 cm into the kerb.
4. **Front hairline:** the hair is swept back but shows some scalp. It may read a little thin for Raja; your call.
5. **Shirt:** the pocket is painted and the buttons are dots. There is no cloth thickness except at the hems, and no secondary motion.
6. **Hands:** no finger grip on the glass (it rests against the palm). The railing hand floats beside the rail.
7. **Body:** still the smooth MakeHuman form. The anatomy normal map (clavicles, sternum, scapulae, knuckles, kneecaps) is not done.

## Remaining stages

- **B4, anatomy:** an anatomy detail normal map baked from a subdivided, displaced source (Blender runs headless here); corrective shapes for the shoulders and knees.
- **B5, clothing:** real button and pocket geometry; a cotton weave and sheen material; trousers waistband and hem; shoes rebuilt as shoes; shirt-tail secondary motion.
- **B6, motion:** fix defects 1–3 and 6 above; finger grips; head-led turns.
- **B7, inspection:** the full suite again, a v0.6 versus final comparison, and **frame time and memory measured on your phone**. I can't measure that here, since no device is attached.

Full detail: **about 104,000 triangles** at the close level (up from 75,600 in v0.6). The added facial hair and the face morphs cost memory on the phone, and the levels of detail cut them away at distance. This is to be measured on your device.

## What I need from you (Stage D, interim)

Look at `before_after_face.jpg`, `sheet_expressions.jpg` and the motion video, and tell me whether the **face, hair and expression direction** is right. In particular:
- moustache thickness;
- eyebrow density;
- hairline fullness;
- skin tone.

I will carry on with B4–B7 either way. Your answers decide the tuning.
