# Raja: Stage A (audit, decisions, rebuild plan)

The full subsystem audit, with baseline renders under nine lighting setups, is in [`M2_HUMAN_PIPELINE_AUDIT.md`](M2_HUMAN_PIPELINE_AUDIT.md). This page records:
- the causes found in the generator code;
- the four decisions, now resolved;
- what is kept, what is rebuilt, and the order of work.

**Raja is the only active workstream.** The map, vehicles, NPCs and polish are paused. Their work stays committed and unchanged.

## Causes found (from `tools/humans/*`)

| Defect seen | Cause in the generator | Action |
|---|---|---|
| Painted, bar-like eyebrows | Painted into the skin texture as noise strips | **Rebuild** as groomed fibre geometry |
| Moustache: jagged shards, or a black strip | Shells cut from the upper-lip skin, hard alpha cut. The one earlier fibre try used 3.5 mm-wide cards (about 30 strands each) with a hard cut, so it went blocky. | **Rebuild** as about 2,500 fibres (1.2 mm wide, 1–3 strands each), alpha-blended, groomed down and out |
| Stepped temple and nape hairline | The scalp cap is selected face by face and cut with a hard alpha threshold | **Rebuild** the cap with an alpha-blended density ramp, plus fine hairline fibres |
| No sideburns | None exist (only the cap edge) | **Build** sideburn fibres |
| Dark band under the eyes | Eyelid mask and eye-socket darkening in the painter: hard-edged and too strong | Soften, and let geometric eye occlusion do the work |
| Eyes look pasted on | A single textured sphere | **Build** a cornea shell, an eye-occlusion shell and a wet tear-line strip |
| White line of teeth through closed lips | Bright teeth, sitting slightly forward | Mouth occlusion darkening on teeth and gums; teeth set back |
| Hard tone edge down the cheek | The stubble mask cut by a hard depth plane | Smooth falloff following the face |
| Skin reads airbrushed and evenly lit | No per-region roughness or cavity map | **Build** region roughness and cavity maps |
| Few, mild expressions; jaw-only speech | 13 morphs from 34 symmetric MakeHuman expression units | **Rebuild**: bake MakeHuman's 60 facial pose units (left/right brows, lids, cheeks, nasolabial, all lip directions, jaw) through its full 163-bone face rig into morph targets; build expressions and speech shapes from them |
| Mannequin body | Smooth, average base mesh | **Refine**: muscle, proportion and asymmetry targets, plus a baked anatomy normal map (clavicles, sternum, scapulae, knuckles, patellae, tendons) |
| Shirt painted on the body, shoes over toes | Clothes cut from the "tights" surface; shoes follow the toes | **Rebuild** the shirt as a garment shell (thickness, collar, placket, sleeve hems) and the shoes as shoe shells |
| Run lunge and crouch | Fixed in commit `8c97b62`, but not visually verified | Verify in footage |

**Kept, not patched:**
- **The MakeHuman base topology.** It is a production-proven quad mesh with proper loops round the eyes and mouth, designed for deformation. Replacing it with a hand-made mesh I cannot sculpt would lower quality.
- **The 55-bone body skeleton**, with the gait, foot-locking and arm IK built on it. The face gets its deformation from baked morph targets rather than extra runtime bones, which costs Android far less.

## The four decisions, resolved

1. **Head source:** built **in-house and procedurally**. The project has no budget for outside assets, the established rules avoid third-party content, and the network cannot reach asset sites. The pipeline stays able to accept an artist-sculpted head later; it would wrap onto the same topology.
2. **Hair edges:** no global MSAA by default, since its cost on the target phone is unmeasured. Hair edges use **alpha-blended** fibre layers (soft by construction) over an alpha-cut core. MSAA can be added as a "High" graphics option once measured.
3. **Motion capture:** **not used**. The download hosts are blocked from this environment, and licences are unverified. Movement stays procedural, with IK, layered posture and gesture.
4. **Phase plan:** the order below.

## Stage B order (Raja only), each step with in-engine renders through `tools/dev/lookdev.tscn`

- **B1, face surface:** skin painter fixes; region roughness and cavity maps; eye cornea, occlusion and tear line; mouth occlusion and teeth.
- **B2, hair:** scalp density ramp; hairline fibres; groomed eyebrow, moustache and sideburn fibres; alpha-blended fibre shader; motion check.
- **B3, face rig:** the 60 pose units baked into morphs; an expression library (neutral, happy, irritated, angry, confused, nervous, tired, surprised, …); speech shapes; saccades and gaze.
- **B4, anatomy:** proportion, muscle and asymmetry targets; baked anatomy normal map; shoulder and knee correctives.
- **B5, clothing:** shirt garment shell; trousers hem and waistband; shoes; fabric materials.
- **B6, motion:** verify and polish idle, walk, run, turns, stops, sit and stand, reach, drink, push. Hair and clothing secondary motion.
- **B7, inspection:** the full view and footage suite under all lighting; comparison with v0.6; frame-time and memory measurement (needs your phone).
- **Stage D:** your visual approval. Raja is not declared done before that.
