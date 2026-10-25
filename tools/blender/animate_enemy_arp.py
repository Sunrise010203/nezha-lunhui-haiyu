"""Author enemy-specific FK motion, inspect skin deformation, and export game clips."""
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/enemies_arp"
SOURCE = ROOT / "art_source/enemies"
KINDS = {"001": "crawler", "002": "shooter", "003": "divider", "004": "guard",
         "005": "turret", "006": "wraith", "007": "bomber", "008": "spawnling"}
GAME_CLIPS = {"Idle": 37, "Move": 25, "Windup": 19, "Attack": 13, "Recover": 16, "Hit": 8}


def run(code):
    kind = KINDS[code]
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE / (code + "_" + kind + "_arp.blend")))
    scene = bpy.context.scene
    rig = bpy.data.objects["Enemy_" + code + "_ARP_Rig"]
    body = bpy.data.objects["Enemy_" + code + "_Body"]
    data = json.loads((OUT / (code + "_rig.json")).read_text())
    controls = list(data["joints"]) if code != "004" else ["c_root_master.x", "c_spine_01.x", "c_spine_02.x", "c_neck.x", "c_head.x"]
    if code == "004":
        for side in ("l", "r"):
            controls.extend("c_" + limb + "." + side for limb in ("shoulder", "arm_fk", "forearm_fk", "hand_fk", "thigh_fk", "leg_fk", "foot_fk", "toes_fk"))
    root_name = "c_root_master.x" if code == "004" else "cc_body"
    rig.animation_data_create()
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    for action in list(bpy.data.actions):
        if action.name.startswith('Enemy_' + code + '_'):
            bpy.data.actions.remove(action)

    def reset():
        for bone in rig.pose.bones:
            bone.matrix_basis = Matrix.Identity(4)
        if code == "004":
            for side in ("l", "r"):
                for limb in ("hand", "foot"):
                    rig.pose.bones["c_" + limb + "_ik." + side]["ik_fk_switch"] = 1.0
        rig.update_tag()
        bpy.context.view_layer.update()

    def rotate(name, angle, axis=(1, 0, 0)):
        bone = rig.pose.bones[name]
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = Quaternion(bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis), angle)

    def vertices():
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        p = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
        mesh.vertices.foreach_get("co", p)
        evaluated.to_mesh_clear()
        return p.reshape(-1, 3)

    rest = np.array([list(v.co) for v in body.data.vertices])
    edges = np.array([list(e.vertices) for e in body.data.edges])
    lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    valid = lengths > 0.001
    scene.render.fps = 30
    scene.render.fps_base = 1.0
    clips = dict(GAME_CLIPS)
    clips.update({"QA_Raise": 2, "QA_Bend": 2, "QA_Turn": 2})
    report = {"code": code, "kind": kind, "clips": {}, "reference_bones": {}, "joints": data["joints"]}
    for label, count in clips.items():
        rig.animation_data.action = None
        reset()
        action = bpy.data.actions.new("Enemy_" + code + "_" + label)
        action.use_fake_user = True
        rig.animation_data.action = action
        for frame in range(1, count + 1):
            scene.frame_set(frame)
            reset()
            t = (frame - 1) / max(1, count - 1)
            wave = math.sin(t * math.tau)
            strike = math.sin(min(t * 2.5, 1) * math.pi / 2) if label == "Attack" else 0.0
            if label == 'Recover':
                strike = 1 - t
            windup = t if label == 'Windup' else 1 - strike if label == 'Attack' else 0.0
            hit = math.sin(t * math.pi) if label == "Hit" else 0.0
            if code == "008":
                rotate('cc_body', windup * .025 - strike * .04 + hit * .07)
                rotate('cc_spine', wave * .008 + windup * .04 - strike * .07 + hit * .06)
                rotate('cc_head', -wave * .008 - windup * .08 + strike * .04 - hit * .05)
                rotate('cc_jaw', windup * .045 + strike * .085)
                for j in range(3):
                    rotate(f'cc_tail_{j + 1:02d}', math.sin(t * math.tau - j * .45) * (.09 if label == 'Move' else .025)
                           + windup * .035 - strike * .045, (0, 0, 1))
                for ci, chain in enumerate(data['chains']):
                    gait = wave * (1 if ci in (0, 3) else -1) if label == 'Move' else 0
                    front = ci < 2
                    upper = -gait * .28 + windup * .15 - strike * (.35 if front else -.18)
                    lower = max(gait, 0) * .42 - windup * .28 + strike * (.48 if front else -.22)
                    rotate(chain[0], upper)
                    rotate(chain[1], lower)
                    rotate(chain[2], -upper - lower)
                if label.startswith('QA_'):
                    reset()
                    if label == 'QA_Raise':
                        rotate('cc_front_01.l', -.9)
                        rotate('cc_front_02.l', .35)
                        rotate('cc_front_03.l', .55)
                    elif label == 'QA_Bend':
                        rotate('cc_hind_01.l', -.6)
                        rotate('cc_hind_02.l', 1.0)
                        rotate('cc_hind_03.l', -.4)
                    else:
                        rotate(root_name, math.pi / 2, (0, 0, 1))
            elif code == "004":
                rotate("c_spine_02.x", -0.035 + math.sin(t * math.tau) * 0.012 + windup * 0.08 - strike * 0.16 + hit * 0.12)
                for side, sign in (("l", 1), ("r", -1)):
                    gait = wave * sign if label == "Move" else 0.0
                    rotate("c_thigh_fk." + side, -gait * 0.30 - 0.08 * strike)
                    rotate("c_leg_fk." + side, max(gait, 0) * 0.48 + strike * 0.10)
                    arm = -0.30 - windup * 0.30 - strike * 0.55 if side == "l" else gait * 0.16
                    rotate("c_arm_fk." + side, arm)
                    rotate("c_forearm_fk." + side, -0.25 if side == "l" else -0.10)
                    if side == 'l':
                        rotate('c_hand_fk.l', -arm + .15)
                if label == "QA_Raise":
                    for side in ("l", "r"):
                        rotate("c_arm_fk." + side, -0.85 if side == 'l' else -1.4)
                        rotate("c_forearm_fk." + side, -0.35)
                    rotate('c_hand_fk.l', 1.05)
                elif label == "QA_Bend":
                    rotate("c_thigh_fk.l", -0.8)
                    rotate("c_leg_fk.l", 1.4)
                elif label == "QA_Turn":
                    reset()
                    rotate(root_name, math.pi / 2, (0, 0, 1))
            else:
                rotate("cc_body", windup * 0.10 - strike * 0.14 + hit * 0.12)
                if code in ("002", "007"):
                    pulse = 1 + 0.018 * wave + windup * (0.12 if code == "007" else 0.035)
                    rig.pose.bones["cc_body"].scale = (pulse, pulse, pulse)
                if code == "003":
                    for side, sign in (("l", 1), ("r", -1)):
                        rotate("cc_lobe." + side, sign * (0.018 * wave + windup * 0.11 + strike * 0.14), (0, 1, 0))
                if code == "005":
                    rotate("cc_ring", t * math.tau if label in ("Idle", "Move") else windup * 0.5 + strike * 0.5, (1, 0, 0))
                    scale = 1 + 0.03 * wave + windup * 0.16 + strike * 0.08
                    rig.pose.bones["cc_core"].scale = (scale, scale, scale)
                    for i in range(3):
                        rotate(f"cc_crystal_{i:02d}", (i - 1) * (windup * 0.08 + strike * 0.05), (0, 1, 0))
                for ci, chain in enumerate(data["chains"]):
                    phase = t * math.tau + ci * (math.pi if code in ("001", "003") else 0.8)
                    for j, name in enumerate(chain):
                        amplitude = (0.12 if code in ('002', '007') else 0.22) if label == "Move" else 0.04
                        angle = math.sin(phase - j * 0.6) * amplitude
                        if code in ("001", "003"):
                            angle += windup * -0.15 + strike * (0.35 if ci < 4 else -0.14)
                        elif code == "006":
                            angle += windup * 0.15 + strike * 0.25
                        else:
                            angle += windup * 0.28 + strike * -0.20
                        if label.startswith('QA_'):
                            angle = 0.0
                            if ci == 0 and label == 'QA_Raise' and j == 0:
                                angle = 0.5
                            elif ci == 0 and label == 'QA_Bend' and j == 1:
                                angle = 0.8
                        axis = (1, 0, 0)
                        if code in ('002', '007'):
                            head = data['joints'][chain[0]]['head']
                            azimuth = math.atan2(head[1], head[0])
                            axis = (math.sin(azimuth), -math.cos(azimuth), 0)
                        rotate(name, angle, axis)
                if label == "QA_Raise" and code == "005":
                    rotate("cc_crystal_00", 0.22, (0, 1, 0))
                elif label == "QA_Bend" and code == "005":
                    rotate("cc_ring", 0.5, (1, 0, 0))
                elif label == "QA_Turn":
                    rotate("cc_body", math.pi / 2, (0, 0, 1))
            bpy.context.view_layer.update()
            if code in ("001", "003", "004", "008") and not label.startswith("QA_"):
                correction = max(0, 0.002 - float(vertices()[:, 2].min()))
                root = rig.pose.bones[root_name]
                m = root.matrix.copy()
                m.translation.z += correction
                root.matrix = m
                bpy.context.view_layer.update()
            for name in controls:
                bone = rig.pose.bones[name]
                for channel in ("location", "rotation_quaternion", "scale"):
                    bone.keyframe_insert(data_path=channel, frame=frame, group=name)
            if code == "004":
                for side in ("l", "r"):
                    for limb in ("hand", "foot"):
                        rig.pose.bones["c_" + limb + "_ik." + side].keyframe_insert(data_path='["ik_fk_switch"]', frame=frame)
        rig.animation_data.action_slot = action.slots[0]
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR"
        metrics = []
        for frame in sorted({1, 1 + (count - 1) // 4, 1 + (count - 1) // 2, 1 + 3 * (count - 1) // 4, count}):
            scene.frame_set(frame)
            p = vertices()
            assert np.isfinite(p).all()
            ratios = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)[valid] / lengths[valid]
            metrics.append({"frame": frame, "p99_edge_ratio": float(np.percentile(ratios, 99)), "max_edge_ratio": float(ratios.max()), "min_z": float(p[:, 2].min())})
            np.save(OUT / (code + "_" + label + "_" + str(frame) + ".npy"), p)
        report["clips"][label] = {"frames": count, "seconds": (count - 1) / 30, "metrics": metrics}
        print("ENEMY_CLIP_READY", code, label, "max_edge_ratio", max(m["max_edge_ratio"] for m in metrics), flush=True)
    # Render one representative pose per clip and an aligned reference view.
    camera_data = bpy.data.cameras.new("EnemyReviewCamera")
    camera = bpy.data.objects.new("EnemyReviewCamera", camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.1 if code == "001" else 2.6 if code in ('006', '008') else 1.75
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = False
    scene.render.resolution_x, scene.render.resolution_y = 640, 720
    scene.render.resolution_percentage = 100
    for label, count in {"Rest": 1, **clips}.items():
        rig.animation_data.action = None
        reset()
        if label != "Rest":
            action = bpy.data.actions["Enemy_" + code + "_" + label]
            rig.animation_data.action = action
            rig.animation_data.action_slot = action.slots[0]
            scene.frame_set(1 + (count - 1) // 4 if label == 'Move' else max(1, count // 2))
            rig.update_tag()
            bpy.context.view_layer.update()
        for view, direction in (("front", (0.35, -1, 0.16)), ("side", (1, 0, 0.12))):
            target = Vector((0, 0, 0.5))
            camera.location = target + Vector(direction).normalized() * 5
            camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(OUT / (code + "_" + label + "_" + view + ".png"))
            bpy.ops.render.render(write_still=True)
            if label == "Rest":
                projected = []
                for name, joint in data["joints"].items():
                    if any(s in name for s in ("thumb", "index", "middle", "ring_ref", "pinky", "bank", "heel")):
                        continue
                    coords = [world_to_camera_view(scene, camera, Vector(joint[k])) for k in ("head", "tail")]
                    projected.append({"name": name, "points": [[p.x * 640, (1 - p.y) * 720] for p in coords]})
                report["reference_bones"][view] = projected
    rig.animation_data.action = None
    reset()
    for label in GAME_CLIPS:
        track = rig.animation_data.nla_tracks.new()
        track.name = label
        action = bpy.data.actions["Enemy_" + code + "_" + label]
        strip = track.strips.new(label, 1, action)
        strip.action_slot = action.slots[0]
        strip.extrapolation = "NOTHING"
        track.mute = True
    scene.frame_start, scene.frame_end = 1, 37
    scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    model_dir = ROOT / "001/art/models/enemies_arp"
    model_dir.mkdir(exist_ok=True)
    originals, game_images = [], {}
    for material in body.data.materials:
        for node in material.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image and max(node.image.size) > 2048:
                original = node.image
                if original.name not in game_images:
                    small = original.copy()
                    small.name = code + '_Game_' + original.name.split('.')[0]
                    factor = 2048 / max(original.size)
                    small.scale(round(original.size[0] * factor), round(original.size[1] * factor))
                    game_images[original.name] = small
                originals.append((node, original))
                node.image = game_images[original.name]
    assert bpy.ops.export_scene.gltf(filepath=str(model_dir / (code + "_" + kind + ".glb")),
        export_format="GLB", use_selection=True, export_skins=True, export_def_bones=True,
        export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
        export_merge_animation="NLA_TRACK", export_force_sampling=True, export_frame_range=False,
        export_all_influences=False, export_materials="EXPORT", export_image_format="AUTO",
        export_extras=False, export_cameras=False, export_lights=False) == {"FINISHED"}
    for node, original in originals:
        node.image = original
    for image in game_images.values():
        bpy.data.images.remove(image)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (code + "_" + kind + "_arp.blend")), compress=True)
    (OUT / (code + "_motion.json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("ENEMY_ANIMATED_AND_EXPORTED", code, flush=True)


codes = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(KINDS)
for code in codes:
    run(code)
print("ENEMY_ANIMATION_BATCH_COMPLETE")
