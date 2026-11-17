# Milestone 2-A: completion report (Raja quality prototype)

Date: 2026-11-17. Build under test: branch `claude/focused-archimedes-th4fuw`.

Evidence:
- `docs/m2/before_after_raja.jpg`: the v0.6 Raja and the current Raja, rendered through the same viewer under the same light.
- `docs/m2/raja_*.jpg`: close-ups.
- `build/m2/raja_proto.mp4`: one continuous recorded run of the prototype course.
- `build/m2/proto_*.jpg`: stills from that run.

Every "visually verified" entry below was judged by looking at those rendered frames, not from code or numbers. The numbers are listed only as supporting data.

## Honest summary

Raja is **better than v0.6, but not yet at the standard you asked for**:

- **Movement and contact** are the strongest part. Feet are locked to the ground, he steps over kerbs, ramps and stairs, and his hands reach real targets (glass, railing, another man's chest).
- **Appearance** improved but remains a stylised, mid-2000s game look:
  - the skin is cleaner and has pores;
  - the hair has strand cards and sways;
  - the moustache is dark and soft-edged.
- The face mesh, eyebrows, shirt and hands are essentially the v0.6 assets.

It is **not** comparable to Red Dead Redemption 2, and I do not claim it is. Section 3 explains the main limits.

## 1. Requirement status

Legend:
- **VV**: implemented and visually verified.
- **IV**: implemented, not visually verified.
- **P**: partially implemented.
- **N**: not implemented.
- **F**: tried and failed (or reverted).

| Area | Status | What the rendered frames show |
|---|---|---|
| Anatomical mesh | P | MakeHuman CC0 base with Raja's face targets. Proportions are plausible. Not sculpted: no muscle definition, generic ears, simple teeth. |
| Body-part connections | VV | One continuous skin surface: no gaps at neck, wrists or ankles in any frame, including sitting and reaching. |
| Shoulder/elbow/knee deformation | P | Linear-blend skinning. The elbow and knee are acceptable. The shoulder loses volume when the arm is raised (the push, reaching for the rail). There are no corrective shapes. |
| Hands and feet | P | Five-finger hands with a relaxed curl. Closed shoes. The fingers do not wrap around the glass; it sits against the palm. |
| Neck-to-torso | VV | Continuous, with a believable collar line. |
| Facial structure | P | Long oval face, high cheekbones, straight nose, as specified. It reads as a generic CG face rather than a specific person. |
| Skin | VV (partly) | 2048 px texture for Raja (was 1024). Pores from a tiled micro-normal, wrap-lit shader, varied roughness. No more orange speckle. Still smooth and slightly airbrushed up close. |
| Eyes | P | Textured sphere with a wet highlight. No separate cornea and no eye occlusion, so the eyes look slightly pasted on. |
| Lips | VV | Natural, low saturation, with a darker line (was a red patch). |
| Age detail | P | Subtle forehead and crow's-foot lines from the generator. Raja is young, so there is little to show. |
| Hair: volume, density, silhouette | VV (partly) | 3000 strand cards on a scalp tint. Real volume and a ragged natural silhouette. Up close the card tips still show some blockiness. |
| Hairline | F (partly) | The scalp tint ends in a stepped edge at the temples (visible in 3/4 view). |
| Sideburns | P | Part of the scalp tint; no separate strands. |
| Moustache | P | Dark and soft-edged (was grey and shiny), with painted strands under it. The shell layers are still visible as layers in profile. |
| Eyebrows | P | Painted into the skin with strand noise. They read as painted bars. Card eyebrows were tried and looked worse at game distance, so they were reverted. |
| Hair movement | IV | Spring-driven sway with the head, walking, stopping and wind is implemented. It is subtle and hard to judge in stills; check the video. |
| Standing idle and breathing | VV | Weight shifts between the feet, breathing and blinks. Seven postures are distinguishable (confident, nervous, defensive, frustrated, curious, tired, relaxed). |
| Walking | VV | Heel strike, flat foot and toe-off. The pelvis shifts over the stance foot, and arms and shoulders counter-swing. |
| Running | VV | Flight phase, short contacts, forward lean, bent arms. Ground error 0.3 cm, slide 0.6 cm. |
| Accelerating/decelerating | VV | Speed ramps; he leans into acceleration; the feet settle side by side when he stops. |
| Turning | VV | Turns in steps. A planted foot does not spin. |
| Sitting / getting up | VV | Leans forward, lowers onto the seat and sits back; hands rest on the thighs; reverse to stand. The pelvis is placed on the seat by construction; buttock-to-seat contact was checked by eye only. |
| Reaching / holding | VV | The palm lands 1.3 cm from the grip point on the glass, which then travels in the hand. The fingers do not close around it (see Hands). |
| Pushing another person | VV | Both palms land within 1 cm of the chest; the other man is driven back about 1 m. |
| Recovering balance (the pushed man) | P | He is moved back and his feet re-plant, but the movement is scripted rather than reactive balance. |
| Ground contact on flat ground | VV | Planted feet stay within about 1 cm and do not visibly slide. |
| Slopes, kerbs, stairs | VV (with one exception) | No visible sinking or floating. Worst measured error 1.7 cm, at the ball of the foot during toe-off on the ramp, just over the 1.5 cm target. A fix was made after this measurement and has not been re-measured. |
| Railing | F | The hand travels near the rail but floats beside it instead of resting on top. The diagnostic run was stopped before the cause was found. |
| Chair | VV | Seated on it; does not pass through it. |
| No interpenetration with the other person | VV | Not in the push frames. There is no general body-to-body collision; separation is a radius. |
| Clothing deformation | N | The shirt is a skin-tight shell with painted folds. It stretches with the body; there is no cloth simulation and no secondary motion. |
| Facial expressions | P | Smile, angry, surprise, sad and talking morphs work. They are mild and read through the eyebrows and mouth only, with no wrinkle maps. |

## 2. Before and after

See `docs/m2/before_after_raja.jpg`.

What changed visibly:
- **Skin:** cleaner tone, finer detail, natural lips.
- **Hair:** strand cards with volume instead of a glossy helmet.
- **Moustache:** dark and matte instead of grey and shiny.

What did not change: body, shirt, hands, eyebrows.

The biggest improvement is in motion, which stills cannot show. Planted feet, weight transfer and hand contact are visible only in the video.

## 3. Why this is not Red Dead Redemption 2, and what it would take

1. **Renderer.** The game uses Godot's GL Compatibility renderer so it runs on most Android phones. It has:
   - no subsurface scattering, screen-space ambient occlusion or contact shadows;
   - no temporal anti-aliasing (so alpha-cut hair looks stepped);
   - no strand hair.

   RDR2's people depend on all of these. A custom shader fakes some of the skin effect. Switching to the Mobile/Vulkan renderer would add contact shadows and better anti-aliasing, but it drops older phones and still lacks subsurface scattering.
2. **Assets.** RDR2's characters are scanned and hand-sculpted:
   - 4K texture sets per character (albedo, normal, cavity, roughness, subsurface);
   - wrinkle maps and corrective shapes on every joint;
   - simulated cloth.

   Raja is generated procedurally from a CC0 base mesh. The next real jump in quality needs an artist-made or scanned head, and hair cards authored in a DCC tool, not more procedural code.
3. **Motion.** RDR2 uses motion capture blended by a runtime IK layer. We have the IK layer (planted feet, hand reach) but no captured motion underneath, so the body language is procedural and somewhat mechanical.

## 4. Recommended next steps (for your decision)

**Option A: stay procedural, polish Raja further.** About 1–2 more working sessions:
- separate cornea and eye occlusion;
- fix the hairline edge and add strand sideburns;
- corrective shapes on the shoulder;
- finger wrap on held objects;
- a looser shirt with secondary motion;
- fix the railing hand.

**Option B: higher ceiling.** Bring in an artist-made head, hair and clothing (for example a commissioned model or a licensed scanned asset). Keep all the motion and contact systems built here. Consider the Mobile renderer for high-end phones.

**Gate:** no NPC mass production and no large world-prop work until you approve the prototype.
