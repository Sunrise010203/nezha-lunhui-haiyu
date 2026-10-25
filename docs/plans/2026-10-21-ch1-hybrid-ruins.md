# Chapter 1 Hybrid Ruins Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace chapter 1's full-reference-image backdrop with real near/mid-ground ruins and a distant palace matte, preserving gameplay.

**Architecture:** Keep LevelBase, player/camera, combat, platform collision and hazard coordinates unchanged. A chapter-local visual Node3D dresses existing platforms and builds separated colonnades/arches; only a cropped, atmosphere-blended palace painting remains in the far distance. Derive lightweight GLBs from existing assets without overwriting the originals.

**Tech Stack:** Godot 4.6 / GDScript / spatial shaders, Blender batch Python, Pillow.

---

### Task 1: Establish regression checks and prepare assets
- Create `001/tools/test_ch1_hybrid.gd`: verify scenery layers, no scenery colliders, rail orientation, expected terrain heights, checkpoint/Boss preservation, and absence of the full reference painting.
- Run it against the existing chapter and confirm the scenery checks fail.
- Create `tools/blender/prepare_ch1_ruins.py`: decimate existing T16–T24, dragon capital and coral to purpose-specific budgets, resize embedded textures to 512px, export into `001/art/models/ch1_ruins/`.
- Create `tools/prepare_ch1_matte.py`: crop only distant palace roofs from the existing reference, excluding its character, foreground walkway and giant eye; build a seamless, low-contrast far matte into `001/art/ref/ch1_palace_far.png`.
- Verify generated GLB triangle counts and inspect the matte.

### Task 2: Build chapter-local layered scenery
- Create `001/scripts/ch1_ruins.gd` and `001/shaders/ch1_far_matte.gdshader`.
- Modify only chapter 1 visual hooks in `001/scripts/level_1.gd`: replace old backdrop and overlapping dressing; retain terrain/encounters/hazards and original platform collision calls.
- Add textured bridge courses and slab seams, correctly oriented rail/post groups, lanterns and clustered rubble. Float-platform dressing must remain attached to the moving body.
- Build grounded columns from base/shaft/capital with independent shaft length/diameter and rear arcades at distinct world depths, plus lightweight distant palace silhouettes.
- Keep near scenery behind or below the play band. Remove the duplicate wildlife flag and lower only chapter 1 caustics/emissive decoration.
- Match the matte to atmospheric background with feathered edges; do not follow the camera or use the complete reference painting.

### Task 3: Verify and visually iterate
- Run headless regression test and existing chapter 1 traversal probe.
- Capture first platform, first gap, upper route and Boss arena using the real Forward+ renderer; inspect for occlusion, texture edges and unintended duplicate routes.
- Run `001/tools/perf_probe.gd` before/after under the same viewport/GPU; record measured results without claiming untested hardware performance.
- Save a contact sheet and verification notes in `_review/ch1_hybrid/` and this plan. No changes to chapters 2–4 or user-owned character/camera edits.

## Completed / verification (2026-10-21)

- All three tasks completed for **chapter 1 only**. Added `ch1_water.gdshader` for non-emissive water and instanced bridge paving with MultiMesh to reduce the additional draw calls.
- Original source GLBs retained. Eleven derived models use ~500–4,200 triangles each and 512px embedded textures (total GLB size ~13.1 MiB). Coincident source vertices are welded before decimation to avoid disconnected triangular holes; the repaired shaft was visually inspected in Blender and Godot.
- `001/tools/test_ch1_hybrid.gd`: **failures=0**. Checks separate scene layers, real columns, horizontal rails, absence of the complete reference painting, scenery without collision bodies, twelve original platform/float surface heights, the open first gap, five checkpoints and Boss health.
- Snapshot comparison confirms `_build_terrain`, `_build_encounters`, `_pool_hazard`, `_on_pool_entered` and the user's `player_camera.gd` are unchanged.
- Existing traversal probe: **4/4 spans reached** (`0:14`, `20:29`, `67:77`, `101:121`). **Known pre-existing issue:** the pool handler accesses `body.dead`, but the player stores death as `act == "dead"`; falling into the pool logs a script error. Not silently fixed as part of scenery work; traversal success does not certify the pool's damage behavior.
- Real-renderer captures inspected at start, first gap, upper terrace and active Boss arena. Review board: `_review/ch1_hybrid/overview.jpg`. Individual PNGs and logs are in the same directory.
- Godot still reports resource/ObjectDB/PagedAllocator cleanup warnings on exit; these also occurred in the pre-change baseline. No new parse or construction errors were observed.

### Performance snapshot

Same existing probe, 1920×1080, Forward+, D3D12, RTX 5070 Laptop; one run per state, not a controlled benchmark of every area. Additional AO, SSR and real geometry cost frame time despite reduced triangles and texture memory.

| Measurement | Before | Final |
|---|---:|---:|
| Rendered triangle primitives | 632,896 | 393,834 |
| Draw calls | 93 | 110 |
| Reported render memory | 2,510 MiB | 2,116 MiB |
| Mean frame time | 3.03 ms | 3.99 ms |
| p95 frame time | 4.55 ms | 6.67 ms |
| Scene-ready time, including loading/prewarm | 9.13 s | 6.42 s |

### Re-run

```powershell
$g = 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $g --headless --path 'E:\godot_game_by_fable\001' --script res://tools/test_ch1_hybrid.gd
& $g --headless --path 'E:\godot_game_by_fable\001' res://tools/probe_walk.tscn -- res://scenes/level_1.tscn 0:14 20:29 67:77 101:121
& $g --path 'E:\godot_game_by_fable\001' --script res://tools/perf_probe.gd -- res://scenes/level_1.tscn
```
