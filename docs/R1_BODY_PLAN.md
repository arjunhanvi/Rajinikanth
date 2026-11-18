# R1: body geometry, anatomy and topology (technical plan)

**Revised order:**
- R1 body;
- R2 head (fitted to the reference photos);
- R3 skin;
- R4 hair;
- R5 rig, weights and correctives;
- R6 movement;
- R7 clothing;
- R8 integration and Android profiling.

The movement work is **paused and preserved** at commit `a869b66` (untested last changes are marked so in the commit message).

**References:** the two photos attached to the conversation were copied by me from this session's attachment files into `assets/references/raja/`:
- `raja_ref_front_smile.png`: a byte-identical copy, 553×555;
- `raja_ref_34_book_original.webp`: the original book cover, 918×1441, plus a JPEG copy.

You did not add them to the project yourself. They are head photos only. **There is no full-body reference**, so body proportions come from anthropometric data for an adult South Indian man of Raja's height (1.78 m) and lean-to-medium build. That choice is mine and is open to your correction.

## 1. Existing mesh: measured limits

The body is the MakeHuman base mesh: 13,380 vertices, quad topology, one continuous surface. Dominant-bone vertex counts:

| Region | Vertices (both sides) | Consequence |
|---|---|---|
| Head | 4,076 | Handled in R2 |
| **Whole torso** (spine, chest, back, abdomen) | **1,230** | Clavicles, sternum, pectoral edge, ribcage, shoulder blades and spinal groove cannot exist as shape; the torso is a smooth tube |
| Neck | 243 | No sternocleidomastoid or trapezius ridge; the neck-to-shoulder slope is a single curve |
| Clavicle region | 68 | The shoulder girdle cannot express the clavicle |
| Upper arms | 586 | The deltoid, biceps and triceps masses are rounded over |
| Forearms | 494 | Forearm taper and wrist flattening are approximate |
| Hands (palm) | about 235 per hand | The palm is a flat slab: no thenar mound, no heel of the palm, no knuckle ridge |
| Fingers | about 1,360 per hand | Dense enough, but the joint creases and nail beds are not shaped |
| Pelvis | 220 | The iliac crest and hip bones are absent |
| **Thighs** | **677 (about 340 each)** | No quadriceps or hamstring masses; **the knee and kneecap cannot be shaped** |
| Calves | 459 | Calf belly and shin approximate; no ankle bones |
| Feet | about 1,070 per foot (mostly toes) | The toes are dense; the arch, heel and ankle bones are weak |

**Topology quality:** good. There are clean quad loops round the joints, designed for subdivision and deformation, and it is widely used as a sculpting base. **Density distribution: poor.** It is spent on the fingers, toes and head, and starved on the torso and limbs. There are no extra loops at the elbow, knee or shoulder for deformation.

## 2. Can the MakeHuman body be sculpted into the result?

**Yes, as a topology base, but not at its current density, and not by moving its existing vertices alone.** Its loops and continuity are worth keeping (they deform cleanly, and every later stage depends on them). It needs:
1. **More geometry where anatomy must exist as shape:** one level of Catmull–Clark subdivision on the torso, neck, shoulders, arms, pelvis and legs; extra edge loops at the joints.
2. **Anatomical volume sculpted into that geometry.**
3. **A sculpt-resolution version** (two to three further subdivision levels, offline only) baked to normal maps for detail too fine for runtime geometry.

Hands and feet are already dense. They need re-shaping, not more vertices, apart from the palm.

## 3. Geometry versus normal maps

| Geometry (it changes the silhouette or must deform) | Normal map (fine, surface-level detail) |
|---|---|
| Neck: sternocleidomastoid, trapezius slope, Adam's apple | Skin folds at the neck and throat |
| Clavicles and the suprasternal notch | Subtle bone rims, tendon lines |
| Deltoid cap and its separation from the arm; pectoral mass and edge; ribcage barrel | Fine muscle striation, the deltoid–biceps groove depth |
| Shoulder blades and the spinal groove; latissimus taper; waist | Back skin texture |
| Iliac crest and hip; buttock mass | — |
| Biceps and triceps volumes; forearm taper; elbow point (olecranon); flat wrist | Elbow skin creases, forearm veins and tendons |
| Palm volumes (thenar and hypothenar mounds, heel of the palm); knuckles; finger pad and joint shapes; nail plates | Palm creases, knuckle wrinkles, nail edges |
| Quadriceps and hamstring masses; **the kneecap and the knee's shape**; calf belly; shin line | Knee skin folds, fine shin detail |
| Ankle bones (malleoli); Achilles; heel; arch; toe shapes | Toe and sole creases |

## 4. Topology changes

- **One level of subdivision** on the torso, neck, arms, pelvis and legs (hands, feet and head excluded): about **+16,000 runtime vertices**.
- **Joint edge loops**, kept exactly as quad loops: two extra loops on each side of the elbow and knee, one each at the shoulder (under the deltoid) and hip crease, and one at the wrist. This gives volume-preserving deformation and supports R5's corrective shapes.
- **Palm:** one subdivision of the palm faces only, with a loop round the thenar mound, so a cupped hand reads.
- **Levels of detail:** the close level gets the new mesh; the middle and far levels are re-decimated from it, so distant crowds don't pay for it.
- Clothing is rebuilt in R7 on top of this body, so the garments' silhouettes follow real anatomy.

**Budget, to be measured in R8:** the skin close level goes from about 26,700 to about 50,000 triangles. Most of the torso and thigh skin is hidden under clothing, so a **hidden-surface mask** will drop covered faces at runtime. The visible budget then goes to the neck and collar opening, forearms, elbows and hands (half sleeves), and the face.

## 5. Tools and asset-generation method

1. **MakeHuman targets first, for proportions and broad masses.** There are 141 arm and leg targets (muscle, fat, scale per segment), torso targets (pectoral, latissimus, V-shape), and neck, hip, stomach and measurement targets. These fit Raja's proportions to the anthropometric table: shoulder breadth, arm and leg segment ratios, chest depth, waist and neck.
2. **Blender 5.3 as a Python module** (bpy, installable here; the wheel downloaded successfully in an earlier check, install not yet verified):
   - subdivision of the chosen regions and insertion of the joint loops;
   - **anatomy sculpt layers**: displacement fields for each structure, positioned from the skeleton and anatomical landmarks (bone heads, joint centres, the measured landmark table), and applied as smooth, falloff-shaped volumes, not noise;
   - a multiresolution sculpt level baked to **tangent-space normal and AO maps** for the fine-detail column;
   - weight transfer from the original mesh onto the new one, so skinning stays valid until R5 improves it.
3. The existing generator (`tools/humans/*`) consumes the result, so export, levels of detail and Godot import are unchanged.

**What this method cannot do:** it is procedural, scripted sculpting placed by anatomy, not an artist's hand sculpt. It will give correct anatomical structure and silhouette. It will not give the individual idiosyncrasies of a specific person's body, and there is no body reference anyway.

## 6. Evaluation in Godot

The evaluation scene `tools/dev/lookdev.tscn` gets a **body-inspection mode**: clothing hidden, a neutral grey-skin material, and the same fixed cameras and lights as the baseline.

- **Views:** front, back, left and right profile, both three-quarters, from above.
- **Close-ups:** shoulders and clavicles (front and back), neck, elbow, open hand (palm and back), fist, knee (front and side), foot (top, side, sole).
- **Anatomical poses:** neutral A-pose; arms raised overhead; elbow at 90° and fully bent; wrist flexed; fist; knee at 90° (sitting) and deep bend; hip flexed. These are inspected for collapse and candy-wrapping now, and are the input to R5's correctives.
- **Lighting:** studio, hard side light (it shows form) and soft overcast (it shows silhouette).
- **Wireframe:** the topology rendered from Blender on the exact exported mesh, front, back and joint close-ups, because Godot's Compatibility renderer has no wireframe view.
- **Comparison:** the same cameras with the v0.6 / current body, side by side.

## 7. Evidence that proves completion

1. Side-by-side Godot renders (old body versus new) for every view and close-up above, under studio and side light.
2. Wireframe sheets showing the new density and the joint loops.
3. The anatomical-pose sheet with no collapsing, intersection or volume loss beyond what R5 is scheduled to correct (any remaining items listed by name).
4. A table of the fitted proportions against the anthropometric targets.
5. Triangle and vertex counts for each level of detail, and the hidden-surface savings.
6. A defect list. R1 is complete only when you approve the body from these renders.

Then R2: the head, fitted to the two reference photos, with the limits of having no true profile stated.
