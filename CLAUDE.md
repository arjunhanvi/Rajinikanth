# BIG BANG LORE — project instructions for Claude

**Continue this existing game. Never recreate, replace or restart the project.**

- Engine: **Godot 4.3** (GL Compatibility renderer, Android target).
- Android identity: package `com.hanvisoriginal.rajinikanth`. **Never change the package ID or the signing configuration.**
- Repository: `arjunhanvi/Rajinikanth`. Development branch: `claude/focused-archimedes-th4fuw`.
- Read `docs/LOCAL_WINDOWS_HANDOFF.md` first. It holds the full state, history, decisions and next task.

## Working rules

1. **Character reconstruction is approval-gated.** The phases run in this order: R1 body; R2 head (from the reference photos); R3 skin; R4 hair; R5 rig, weights and correctives; R6 movement; R7 clothing; R8 integration and Android profiling. **Do not start a phase until the user approves the previous one from actual renders.**
2. **Raja (the protagonist) is the only active workstream** until he is approved. The world map, vehicles, NPCs, story and opening sequence are paused. Do not modify them.
3. Do not replace Raja in the game until the user approves the new body and the Blender-to-Godot pipeline has been validated.
4. **Movement and animation work is frozen** (commits up to `a869b66`). Preserve it; do not develop it further until R6.
5. **Show evidence, not claims.** A phase is not complete because a script ran, the mesh has more polygons, it exported, or tests passed. Use real Godot or Blender renders from fixed cameras and lighting, with before/after comparisons. Report defects honestly. Never claim RDR2-level quality without visual proof.
6. Do not hide defects with lighting, camera angles, post-processing or textures.
7. Commit tested work in logical milestones, keep backups, and never discard existing work.
8. Use only user-supplied audio. Do not invent story beyond what the user has approved.
9. Make no performance claims for Android without measuring on a real device.
