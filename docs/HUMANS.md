# Human characters (milestone: human realism)

## What was wrong (audit of v0.3.0)

People were boxes, spheres and cones parented to joint nodes. There was no continuous
surface, no skeleton, no skinning and no morph targets, so no amount of added detail could
make them read as human. The architecture was replaced, not extended.

## What replaced it

- **Source anatomy.** The MakeHuman base mesh and its data, released CC0: a 13,380-face body
  with full hands, feet, ears, teeth, tongue and eyelashes, helper surfaces for clothing and
  hair, a 53-bone game skeleton with skin weights, and several hundred morph targets
  (ethnicity, sex, age, weight, muscle, height, individual facial features, expression units).
  Source: github.com/makehumancommunity/mpfb2 at 9de0707fdc88 (directory src/mpfb/data) and
  github.com/makehumancommunity/makehuman at a8bc2d54ff0a (eyes). The data is not copied
  into this repository; only the generated models are.
- **Generator** (): sculpts each person from morph targets, splits the skin into
  regions, fits eyes, builds clothing from the clothing helper surface (shirts, an open
  over-shirt, trousers with a straight leg, belt, lungi, saree with pleats and pallu, blouse,
  kurta, kameez), adds buttons and pockets as geometry, grows hair and facial hair as layered
  strand shells from the scalp and face, builds footwear, bakes skin albedo and normal maps in
  UV space from 3D position maps (pores, creases by age, brows, stubble, lips, nails), creates
  13 expression morphs and 8 identity morphs, decimates to lower levels of detail and writes
  rigged binary glTF.
- **Runtime** (): same interface as before, so story, crowd, vehicles,
  saves and the character creator are unchanged. It drives the skeleton (arms re-posed from the
  authored A-pose to a natural hang, fingers curl per joint, feet held level through the stride),
  blends the face morphs (irregular blinking, speech, moods that ease in and out), turns the
  eyes on their own bones, and swaps detail levels by distance.

Rebuild everything: 

## Models

| | Full detail | Mid | Far |
| --- | --- | --- | --- |
| Rajinikanth | 42,852 tris | 14,998 | 2,912 |
| Kamakshi | 57,935 | 19,532 | 4,023 |
| Umashankar | 40,278 | 14,220 | 2,735 |
| Devaraj | 43,256 | 15,194 | 2,935 |
| 12 crowd bodies | (none) | about 20,000 each including every garment and hair option; roughly 5-8,000 shown at once | about 4,400 |

Full detail is shown within 5 m, mid to 15 m, far to 115 m. Crowd faces differ by body model
plus per-person identity morphs, skin tone, hair, facial hair and clothing.

Acceptance images are in  (A close-ups, B full body, C expressions, D hands and
clothing, E movement, F before/after, G in game).

## Measured

Desktop software renderer only (no GPU, no Android device available): a busy street with 21
people drew 239,000 triangles in 787 draw calls at about 155 ms per frame; v0.3.0 measured
roughly 70-80 ms in comparable scenes. Texture memory 93 MB. **This is not an Android
measurement.** Real-device frame rate is unknown; the new people cost roughly twice the frame
time of the old ones on this renderer.

## Not good enough yet

- Hair is a layered shell: it reads as a solid mass, not strands, and women's styles (bun,
  plait) are weak from the front. Kamakshi's hair in particular looks like a short crop.
- Skin is a baked colour and normal map with rim lighting; there is no subsurface scattering
  on this renderer, so faces look waxy in flat light. Shadow maps leave hard-edged patches on
  faces at some angles.
- Clothing is fitted and has stitched hems, buttons and pockets, but folds are mostly in the
  normal map; there is no cloth simulation and garments stretch at extreme poses.
- Animation is still procedural. Foot contact is held level but there is no inverse
  kinematics, so feet can slide slightly on turns; sitting and standing blend rather than
  play a proper transition.
- Expressions work but are subtle; lip movement is rhythmic, not matched to words.
- Devaraj's spectacles are left off because the fitted frames were wrong.
- Rajinikanth uses his own tailored body in story mode, so wardrobe changes there only affect
  the over-shirt and coat; the free-play creator uses the crowd bodies with all options.
- Models add about 50 MB to the project.
