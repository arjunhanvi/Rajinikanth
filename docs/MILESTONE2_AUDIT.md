# Milestone 2: audit of the current humans and world

This is based on `bigbanglore_opening_v0.6.mp4` (frames sampled every 4 s, plus targeted stills) and on the code: `scripts/actors/Human.gd`, `tools/humans/*`, `scripts/world/*`.

## 1. Why the characters look immature

1. **They do not stand on the ground.** This is a measured bug, not an impression. Every person's root sits at height 0, but the surfaces they stand on are higher: roads at 0.09 m, side-street footpaths at 0.13 m, arterial footpaths at 0.19 m, and the campus paving at 0.11 to 0.14 m. Everyone is sunk 9 to 19 cm into the ground. Their feet and ankles disappear into the surface, so nobody reads as having weight.
2. **Movement is a sine wave, not a gait.** Legs swing on a timer scaled by speed. Feet are never locked to the ground, so they skate. There is no heel strike or toe-off, the pelvis does not carry weight from leg to leg, and the shoulders do not counter-rotate. Speed changes instantly.
3. **Hair is a helmet.** Hair is made of offset shells of the scalp, so the silhouette is the skull plus a constant thickness. In daylight it looks grey-blue because a white-tinted, fairly glossy material reflects the sky. It never moves.
4. **Skin is plastic.** Standard Lambert lighting with a mild rim, a baked albedo and one normal map. No light bleeds through the skin, there is no pore-scale detail and no roughness variation (nose, forehead and cheeks all shine the same), so the faces look like painted vinyl.
5. **The world is over-bright and flat.** The campus paving is near-white (albedo 0.74 to 0.82), the ambient light is strong, and there is no ambient occlusion and only one soft shadow. People do not appear to touch the surfaces around them.
6. **Bodies rarely change posture.** Most of the crowd has one idle (a sway plus a head turn). Nobody shifts weight from foot to foot, and posture does not change with personality or mood.

## 2. Anatomy and mesh

- The base mesh (MakeHuman, CC0) is anatomically sound: a continuous skin surface, proper hands with five fingers, separate eyes, teeth and tongue. Proportions come from age, weight, muscle and height targets plus face targets.
- **Shoulders and armpits:** the mesh is authored with the arms out. The game rotates the arms down about 70° at runtime with linear-blend skinning, which loses volume at the deltoid and pinches the armpit. This is partly hidden by sleeves.
- **Clothing** is cut from the "tights" helper surface. It reads as a shell painted onto the body: no cloth thickness at the edges, hems from a face selection, and folds faked with vertex noise.
- **Skin under clothing** has been rendered since 0.6.0, so there are no holes. The skin itself is continuous: body parts share vertices and weights at every boundary, and no gaps were found in the extreme poses of the fall.
- **Feet in shoes** were fixed in 0.6.0 (closed shoes). With the ground offset, the feet were not actually visible enough to judge.

## 3. Movement and foot contact

| Problem | Cause |
|---|---|
| Feet sink 9–19 cm | No ground query; roots fixed at y = 0 |
| Feet slide | Legs are animated from a phase, never locked to a world position during stance |
| No heel–toe | The foot angle only compensates the leg angle |
| No weight transfer | Pelvis bob is `abs(cos)`; no lateral shift over the stance foot |
| Turning on the spot | The whole body yaws; the feet rotate with it |
| Start and stop are instant | The player's velocity is set directly from input; NPC movers jump between speeds |
| Kerbs, slopes, stairs | Not handled at all: no per-foot ground height |
| Sitting | The pelvis drops by a fixed amount; seat contact is hand-tuned per scene (`seat_lift`) |

## 4. Hair and skin limitations

- **Hair:** shells give no strand structure and no silhouette. There is no hairline transition (only an alpha fade on the cap) and no motion. Moustaches and beards are shells too.
- **Skin:** in the GL Compatibility renderer there is no built-in subsurface scattering. The current material uses none of the ways to fake it: wrap lighting with a red terminator, roughness variation, or micro-normal detail.
- **Eyes:** one sphere with a texture. Specularity was turned down in 0.6.0 to stop the silver look.

## 5. Interaction and collision

- People keep apart with a 0.52 m separation radius (since 0.6.0). There is no shape awareness.
- Hands never target anything: the push "lands" because two people are staged at the right distance. A hand on a shoulder, a railing or a glass is not reached; it is posed.
- Objects in hands are props on bone attachments with fixed offsets.

## 6. Rendering and lighting

- The renderer is GL Compatibility (chosen for Android reach). It has no SSAO, SSR, SDFGI or volumetric fog, and no built-in SSS.
- Available tools: custom `light()` shaders (so skin and hair lighting can be written by hand), directional shadow splits, filmic/ACES tone mapping, exposure, sky-based ambient light, vertex colour AO, and baked AO in textures.
- The current setup overexposes pale ground, and the ambient light flattens form.

## 7. Technical approach for Godot 4.3 on Android

| Area | Solution |
|---|---|
| **Ground** | A walkable collision layer for roads, footpaths, kerbs, campus paving and steps. A `Ground` service raycasts the true surface height and normal. Every human's body follows it. |
| **Locomotion** | A procedural, physically driven gait (`Gait.gd`): each foot has stance and swing phases. In stance the foot is **locked to its world position**. In swing it travels an arc to a predicted footfall on the real ground (per-foot raycasts, so kerbs, slopes and stairs work). Analytic two-bone IK puts the leg on the foot. The pelvis carries the weight (bob, sway over the stance foot, yaw, roll); spine and shoulders counter-rotate; arm swing is driven by the legs. Heel strike, flat foot and toe-off come from the foot's position relative to the body. Turning on the spot takes real steps; stopping settles the feet. It is cheaper than motion capture plus root motion and avoids foot sliding by design. |
| **Speed** | Acceleration and deceleration on the player and on scripted walkers, plus lean into acceleration. |
| **Hair** | Hair **cards**: strips grown from scalp roots along a style flow field, a clumped strand texture with alpha, root-to-tip colour, and a custom light (Kajiya-Kay style highlight along the strand). A spring on head motion drives a vertex-shader sway weighted root to tip: cheap and mobile-safe. Cards are also used for eyebrows, moustache and sideburns. Fewer cards at distance. |
| **Skin** | A custom skin shader: wrap diffuse plus a warm subsurface terminator, tiled pore micro-normal, roughness varied by face region, low specular, eyelid and lip detail from the baked texture. |
| **Interaction** | Analytic arm IK for reaching (glass, table, railing, a shoulder or chest in a push). Pelvis-to-seat IK for sitting, with the feet planted by leg IK. Balance recovery after a push uses real catch-steps from the gait. |
| **Lighting** | A darker, warmer paving albedo, a tuned exposure and ambient split, tighter contact shadows, a stronger soft blob shadow under feet, and filmic tone mapping. |
| **Performance** | Full gait, hair sway and skin shader on near characters (under about 25 m). Distant crowd keeps the cheap path and updates at lower rates. LOD meshes as before. |

## 8. Prototype character

**Raja**, the player's own body and the character the camera is on most.

## 9. Acceptance criteria for the prototype

Measured by an automated run of the prototype course **and** checked in rendered footage:

| # | Criterion | Measure |
|---|---|---|
| 1 | Feet on the ground | The planted foot's sole stays within ±1.5 cm of the real surface (paving, kerb top, ramp, stair tread) |
| 2 | No foot sliding | A planted foot drifts under 1 cm during its stance phase (walking and running) |
| 3 | Kerbs, ramp, stairs | Steps up and down a 14 cm kerb, a ramp and four stair treads without sinking or floating |
| 4 | Start and stop | Speed ramps up and down (no instant top speed); the feet settle side by side when stopped |
| 5 | Turn on the spot | A 180° turn is made in steps; the feet do not rotate while planted |
| 6 | Idle | Breathing, weight shifts with both feet planted, and gaze and blinks, varied over 20 s |
| 7 | Sit and stand | The pelvis rests on the seat surface within ±2 cm; feet planted; a transition with forward lean |
| 8 | Hand on an object | The hand reaches the glass and the railing within 3 cm, and the glass travels in the hand |
| 9 | Human contact | In a push, both hands land within 4 cm of the other person's chest; that person takes catch-steps |
| 10 | Hair | Card hair with a hairline, volume and silhouette; it sways with head motion and settles |
| 11 | Skin | No plastic sheen; shading wraps softly; pores visible in close-up; varied roughness |
| 12 | Rendered evidence | A recorded video of the course plus close-ups, reviewed frame by frame |
