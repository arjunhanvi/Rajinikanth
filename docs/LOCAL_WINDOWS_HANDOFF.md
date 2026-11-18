# BIG BANG LORE: handoff to local Windows development

Status labels used here:
- **[DONE]**: completed and visually verified;
- **[UNVERIFIED]**: implemented but not visually verified, or verified only by numbers;
- **[PLANNED]**: not started.

## 1. Project overview
BIG BANG LORE is an Android open-world game set in **Bengaluru, January–June 2007**, by Hanvi's Original. Two Rajinikanth fans, **Raja** (the player; visual reference Shankar Nag) and **Lal** (visual reference Ambareesh). The playable opening (a film shoot at M.S. Ramaiah Institute of Technology) is complete. The story continues only as the user approves it.

## 2. Engine
- **Godot 4.3 stable**, GL Compatibility renderer (rendering method for mobile also `gl_compatibility`).
- Android package `com.hanvisoriginal.rajinikanth`, version `0.7.0`, code `7`.

## 3. Repository
- `https://github.com/arjunhanvi/Rajinikanth`, branch **`claude/focused-archimedes-th4fuw`**.
- No pull request exists. `main` has nothing from this work.

## 4. Latest verified commit
See the commit this document was added in (`git log -1`). The previous commit, `a519280`, is the last pushed state before this handoff.

## 5. Architecture
| Path | Contents |
|---|---|
| `project.godot`, `scenes/` | Godot project and entry scenes |
| `scripts/core/` | `Game.gd` (state, saves, settings), `City.gd` (compressed 1:4 Bengaluru map data), `Sfx.gd` |
| `scripts/world/` | `World.gd`, chunk streaming (`Chunk.gd`), `Campus.gd` (MSRIT), `Landmarks.gd`, `Ground.gd` (walkable surfaces), `Weather.gd` |
| `scripts/actors/` | `Human.gd` (characters: materials, face, body language), `Gait.gd` (procedural locomotion and IK), `Player.gd`, `Crowd.gd`, `NPC.gd` |
| `scripts/vehicles/` | `Vehicle.gd`, `Handling.gd` (handling and suspension), `Traffic.gd` |
| `scripts/ui/` | `HUD.gd`, `TouchPad.gd` (touch controls, RUN LOCK, driving HUD), menus, settings, map |
| `scripts/story/` | `Opening.gd` (the opening sequence; **do not change**), `Story.gd` |
| `shaders/` | `skin`, `hair_cards`, `hair_fiber`, `eye_occlusion` |
| `tools/humans/` | **Character generator** (Python): MakeHuman base, facial pose-unit bake (`faceunits.py`), R1 body (`anatomy.py`), wireframes (`wire.py`), pipeline checks (`verify_body.py`) |
| `tools/dev/` | `Harness.gd` (automated test scenarios), `lookdev.tscn/.gd` (fixed-camera character evaluation scene) |
| `tools/blender/` | `raja_master_setup.py` (Blender project setup, **[UNVERIFIED]**: see section 11) |
| `tools/build_apk.sh` | APK build (Linux/bash) |
| `assets/humans/` | Generated character `.glb` models and textures (`raja.glb` is the current Raja) |
| `assets/references/raja/` | Reference photos (see section 10) |
| `docs/` | All reports and evidence images |

## 6. Character reconstruction history (Raja)
1. **v0.6:** MakeHuman-based procedural models for all heroes. [DONE]
2. **Milestone 2 / B1–B3:** for the face and hair, see `docs/RAJA_PROGRESS.md` and `docs/m2/b1b2`, `docs/m2/b3`. [DONE as rendered; **not approved** as final]
   - fibre eyebrows, moustache, sideburns, eyelashes and hairline;
   - cornea and eye-occlusion shells;
   - closed lips at rest;
   - region roughness and cavity skin map;
   - 60 MakeHuman facial pose units baked to morphs, with an 8-expression library and speech mouth shapes.
3. **B5 step 1:** tailored shirt (collar, hems, folds). [DONE as rendered; first pass only]
4. **Audit:** `docs/RAJA_RECONSTRUCTION_AUDIT.md`. MakeHuman is sufficient as topology only; face resolution about 4,100 vertices; renderer limits.
5. **Production order agreed:** R1 body, then R2 head, R3 skin, R4 hair, R5 rig, R6 movement, R7 clothing, R8 integration. Each is approval-gated.

## 7. Current Raja R1 status: **NOT APPROVED**
- The procedural R1 body is in `raja.glb` now. It uses selective subdivision plus anatomy shapes placed from skeleton landmarks (`tools/humans/anatomy.py`).
- Evaluation: `docs/R1_BODY_EVALUATION.md`, `docs/m2/r1body/`.
- **User verdict:** "still a generic MakeHuman body with additional anatomical shapes". The procedural approach is **rejected as the final foundation**.
- **Decision:** move to a **local Blender 5.3 sculpting pipeline** based on Blender's **Human Base Meshes v1.4.1** (section 12).

## 8. Existing MakeHuman and R1 work (kept, not deleted)
- **Generator:** `tools/humans/gen_humans.py`, `build.py`, `tex.py`, `faceunits.py`, `anatomy.py`. It needs the MakeHuman/MPFB source data, which is **not in the repository** (it lived in the cloud scratch area). Regenerating characters locally needs MPFB2 data and MakeHuman 1.x data. Everything already generated is committed in `assets/humans/`.
- **Comparison models (excluded from the APK):**
  - `raja_v06.glb`: the v0.6 Raja;
  - `raja_preR1.glb`: the face and hair work before R1.
- **Evaluation tools:**
  - `tools/dev/lookdev.tscn`, with modes `all`, `face`, `anatomy`, `light`, `body` (body = clothes off, clay);
  - `tools/humans/wire.py`;
  - `tools/humans/verify_body.py`.

## 9. Movement work: **FROZEN** (preserved, last commit `a869b66`)
- **On foot:** step width about 11 cm, the hip drop fix, heel-strike distance cap, 1.4 m/s walk, palm orientation, grip profiles, running posture. [UNVERIFIED for the last tweaks]
- The R1 movement reel is `build/m2/raja_r1_movement.mp4` (cloud only).
- Controls overhaul: touch stick, **RUN LOCK**, contextual buttons, driving HUD, vehicle handling and suspension. Simulated tests pass (18/18 and 42/42); **not yet tested on a real phone**. See `docs/CONTROLS_REPORT.md`.
- Do not develop further until R6.

## 10. Reference images (in the repository)
- `assets/references/raja/raja_ref_front_smile.png`: front-facing smiling portrait, 553×555, a byte-exact copy of the conversation attachment.
- `assets/references/raja/raja_ref_34_book_original.webp`: three-quarter book cover, 918×1441, the original attachment. **It is not a profile.**
- `assets/references/raja/raja_ref_34_book.jpg`: a JPEG copy of the book cover.
- These are excluded from Godot import (`assets/references/.gdignore`).
- **No true side profile and no full-body reference exist.** Body proportions so far are assumptions (stature 1.78 m, provisional).

## 11. Blender 5.3 local production
- Blender 5.3 is on the user's Windows PC. The production workspace is `D:\BIG_BANG_LORE_PRODUCTION`, with folders `00_PROJECT_CONTROL` … `09_SCRIPTS`.
- `tools/blender/raja_master_setup.py` builds `03_BLENDER\RAJA_R1_MASTER.blend`. The project contains:
  - metric units;
  - a locked original base mesh;
  - a working copy with Multires;
  - the current Raja imported for comparison;
  - reference image empties;
  - six orthographic cameras;
  - studio and raking light rigs;
  - topology statistics;
  - Workbench clay and wireframe evidence renders;
  - a dated backup;
  - a reopen check.

  It never overwrites an existing master.
- **Tested in the cloud on Blender 5.3 (Python module), up to and including the topology statistics** (bundle discovery, base-mesh selection, Raja import, scale, references). **The render step failed in the cloud** because there is no GPU or EGL there. On a desktop Windows Blender, Workbench rendering normally works, but **this has not been verified**. The save, backup and reopen steps run after the render step, so they have not been reached in testing either.
- **Interactive sculpting is done by the user, or an artist, in the Blender GUI.** Claude prepares the files, scripts, inspection renders and pipeline, and can drive Blender through command-line scripts when running locally.

## 12. Human Base Meshes v1.4.1 plan
- Source: `https://mirror.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip`, from blender.org's demo files page. CC0 per Blender Studio; confirm in the bundle.
- **The cloud environment could not download it** (the host is blocked), so the user downloads it on Windows into `D:\BIG_BANG_LORE_PRODUCTION\02_BASE_MESHES\`.
- The setup script lists every object in the bundle (`00_PROJECT_CONTROL\base_mesh_inventory.txt`) and picks the realistic male full body by name. **Check that choice by inspection; if wrong, choose manually.**
- **Plan:**
  1. inspect the mesh: proportions, quad flow, hands, feet, UVs, Multires and density;
  2. compare it with the current Raja;
  3. once you approve the foundation, fit it to Raja's proportions;
  4. you sculpt interactively;
  5. retopologise or keep the game-resolution mesh;
  6. bake details;
  7. transfer to Godot (glTF export, weights and rig mapping onto the game skeleton, face morphs re-baked).

## 13. Exact next task (R1-A)
1. On Windows: clone the repository, then download the Human Base Meshes bundle into `02_BASE_MESHES`.
2. Copy `assets\humans\raja.glb` and the reference images into `D:\BIG_BANG_LORE_PRODUCTION\01_REFERENCE\`.
3. Run `tools\blender\raja_master_setup.py` with local Blender. If rendering fails, debug that step first.
4. Inspect `08_EVIDENCE` renders and `00_PROJECT_CONTROL` statistics. Compare the base mesh with the current Raja (torso, shoulders, arms, hands, pelvis, legs, feet).
5. Report and recommend a foundation. **The user approves the foundation before any sculpting.**

## 14. Unfinished work
- **R1:** the body foundation (the Blender pipeline is the next step). [PLANNED]
- **R2–R8:** head fitted to the references; skin; hair; rig, weights and correctives; movement; clothing; integration and profiling. [PLANNED]
- **Bengaluru 1:1 map reconstruction:** `docs/WORLD_STAGE1_PLAN.md`, approved, but **blocked** (OpenStreetMap and SRTM hosts were blocked in the cloud). It may be possible locally. Paused.
- **Touch controls:** on-device test still to do (checklist in `docs/CONTROLS_REPORT.md`).
- **Human realism gate:** decisions are recorded in `docs/RAJA_STAGE_A.md`.

## 15. Restrictions: do not modify without the user's approval
- Story, the opening sequence (`scripts/story/Opening.gd`), saves, world, controls, movement code, other characters.
- The Android package ID and signing.
- Do not replace Raja in Godot before approval.
- Use only user-supplied audio.

## 16. Known bugs and limitations
- **Renderer:** GL Compatibility has no subsurface scattering, SSAO or temporal anti-aliasing. That caps skin and hair realism on Android.
- **Movement:** one running segment slides 5.4 cm. The pushed character's reaction is scripted, not physical. The bike rider's pose is wrong in a hard lean. Wheels don't spin or steer visually.
- **R1 body:**
  - hands and feet are generic;
  - a bumpy patch above the left groin;
  - the deltoid-to-arm transition is soft;
  - T-junctions where the subdivided regions meet the head, fingers and toes.
- **Character textures are imported uncompressed** (Android memory). The close-level Raja is about 135,000 triangles. **Never measured on a device.**
- The `.godot` import cache and `build/` are git-ignored. **APKs, videos and git bundles under `build/` exist only in the cloud.** Videos referenced in the docs (for example `build/m2/*.mp4`) will be missing locally.
- **Signing:** APKs so far were signed with the cloud's debug keystore (alias `androiddebugkey`, standard debug password). To install updates over the app already on the phone, use **that same keystore**. It was sent to the user separately and is **not** in Git; keep it out of the repository.
