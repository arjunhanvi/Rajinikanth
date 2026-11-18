# R1 body reconstruction: evaluation (for your decision; not declared complete)

Every image is a **Godot render** of the exported model, in neutral grey clay with the clothes off. The original MakeHuman body (pre-R1, kept as `raja_preR1.glb`, excluded from the APK) and the R1 body are shot from **identical cameras** under two lighting setups:
- **studio**: a key light, soft fill and rim;
- **raking**: a key light at about 55° to the side with a dim fill, to show form.

| Evidence | File |
|---|---|
| Six full views, raking | `docs/m2/r1body/full_raking.jpg` |
| Six full views, studio | `docs/m2/r1body/full_studio.jpg` |
| Torso close-ups (shoulders, collarbones, chest, back, abdomen, pelvis) | `docs/m2/r1body/close_torso.jpg` |
| Limb close-ups (arm and elbow, hand back and palm, thigh, knee front and side, calf, foot) | `docs/m2/r1body/close_limbs.jpg` |
| Wireframe (the exact exported mesh) | `docs/m2/r1body/wireframe.jpg` |
| Pipeline checks | `docs/m2/r1body/pipeline_checks_*.txt` |

## Method

1. **Selective Catmull–Clark subdivision** on MakeHuman's real quads, built from welded topology so UV seams don't become creases. It covers the torso, neck, arms, palms, pelvis and legs. The head, fingers and toes are excluded. The region border stays fixed, so neighbouring meshes keep meeting.
2. **Anatomical forms built into the geometry**, all of them smooth, falloff-shaped volumes rather than noise:
   - placed from the skeleton's joints;
   - limb landmarks (kneecap, back of the knee, elbow point and inside, ankle bones, inner thigh, calf heads) **projected onto the actual skin surface**;
   - normals welded across all parts, so a seam vertex moves the same way in both.
3. **Welded normals exported** across the skin parts, so shading is continuous over part borders.

## Iterations (each one rendered and inspected)

| Pass | Finding in the renders | Correction |
|---|---|---|
| 1 | The body was almost indistinguishable from the original. The relief was only 1–3 mm. The "side" light preset blacked out half the body. | Relief scaled to the anatomical range; a raking light preset added |
| 2 | Forms visible, but the **spinal groove and shoulder-blade ridges rendered as hard straight lines**, and the **breastbone and midline as a crease**. **Shading rings at part borders** (wrist, mid-shin), also present in the original. | Midline and back forms widened and softened; welded normals exported |
| 3 | **The knee, elbow and ankle forms were missing.** Their landmarks were joint-centre offsets of about 1 cm, so they sat inside the limb. | Landmarks projected onto the skin surface; forms sized to real anatomy (kneecap about 3.5 cm across, calf heads about 5–6 cm) |

## Pipeline verification (measured on the exported `.glb`)

| Check | Original | R1 |
|---|---|---|
| UVs within 0–1; degenerate or flipped UV triangles | yes; 0 / 0 | yes; 0 / 0 |
| Skin weights: sum per vertex, invalid values | 1.000 / none | 1.000 / none |
| Face morph targets on the face and arms mesh | 27 | 27 (deltas carried over by linear stencils; the face itself is not subdivided) |
| Border vertices shared exactly with the neighbouring part | all | all |
| Normal agreement at part borders (minimum dot product; vertices below 0.999) | 0.851; **406** (the shading rings) | **1.000; 0** |
| T-junctions where subdivided regions meet the head, fingers and toes | — | 368 (face and arms mesh) + 184 (feet). **Geometrically closed** (each extra vertex lies exactly on the neighbour's edge), but not ideal topology |

**Vertex mapping:** every original vertex of a subdivided region is kept (moved by subdivision smoothing and then the anatomy), and new edge and face vertices are added. The game code does not depend on vertex numbers. Skinning follows from the stored weights, which are interpolated and checked above.

## Regional topology and geometry (close level, skin only)

| Mesh | Original vertices / triangles | R1 vertices / triangles |
|---|---|---|
| Head, neck, arms, hands (`skin_a`) | 9,349 / 17,174 | 14,988 / 27,860 (the head and fingers are unchanged; neck, arms and palms 4×) |
| Torso (`skin_torso`) | 1,430 / 2,594 | 5,453 / 10,376 |
| Pelvis and thighs (`skin_legs`) | 1,254 / 2,300 | 4,807 / 9,200 |
| Calves and feet (`skin_feet`) | 2,700 / 4,688 | 5,358 / 9,704 (toes unchanged) |
| **Skin total, close level** | 14,733 / 26,756 | **30,606 / 57,140** |
| Middle / far level (skin) | 8,025 / 1,872 triangles | 17,138 / 3,998 triangles |

The **Android cost is unmeasured**; it comes in R8. The hidden-surface culling of skin under clothing is planned, not yet built.

## Proportions (assumed versus derived)

None of the body proportions come from the reference photos, which show the head and shoulders only. **All are assumptions:** a stature of 1.78 m (provisional) and MakeHuman's lean-to-average adult male settings (weight 0.34, muscle 0.58), unchanged in R1.

## Defects

**Corrected:**
- invisible relief;
- hard spinal and shoulder-blade lines;
- the midline crease;
- shading rings at part borders;
- missing knee, elbow and ankle forms;
- the unreadable inspection lighting.

**Still remaining (visible in the attached renders):**
1. **Hands:** essentially unchanged. The palm mounds, palm hollow and knuckles are too weak to read, and the fingers are untouched MakeHuman fingers.
2. **Feet:** essentially unchanged. The arch, heel and toes are still the MakeHuman forms.
3. **A mottled, bumpy patch above the left groin**, where the hip-bone, groin-groove and flank forms overlap.
4. **The deltoid-to-arm transition** is soft. The deltoid insertion and the groove between deltoid and biceps barely read.
5. **The neck:** the sternocleidomastoid reads only weakly. The neck-to-trapezius slope is improved but still smooth.
6. **Forearm and wrist:** some forearm muscle form shows, but the wrist bones barely read.
7. **T-junctions** at the head, finger and toe borders (closed, but not clean topology).
8. **The levels of detail were not visually checked** for silhouette at distance.

## Limitations of the scripted sculpting approach

- It builds anatomy as placed, smooth volumes from landmarks. That gives correct structure and silhouette, but **no artist-level surface subtlety**: the interplay of overlapping forms, asymmetry within the muscle groups, and the soft-tissue sag that a hand sculpt carries.
- Forms that **overlap** (as at the groin) can interfere, and need individual tuning.
- **Hands and feet** need dedicated work, probably a finer, region-specific subdivision and carefully shaped forms for each finger. That is the next refinement if you want R1 continued.
- Fine detail (skin folds, veins, tendons) is deliberately **not** in the geometry. It belongs to the baked detail maps in R3.

**R1 is not declared complete.** Please judge the renders. If you want the remaining defects fixed first (hands, feet, the groin patch, deltoid, neck, wrist), I will do so before R2.
