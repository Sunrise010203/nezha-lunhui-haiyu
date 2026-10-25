"""Build fitted ARP rigs for the supplied enemies, preserving their textures."""
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path("E:/godot_game_by_fable")
sys.path.insert(0, str(ROOT / "tools/blender"))
from enemy_arp_anatomy import segment_distances, slice_centers

OUT = ROOT / "_review/enemies_arp"
SOURCE = ROOT / "art_source/enemies"
NAMES = {"001": "crawler", "002": "shooter", "003": "divider", "004": "guard",
         "005": "turret", "006": "wraith", "007": "bomber", "008": "spawnling"}


def components(body):
    adjacency = [[] for _ in body.data.vertices]
    for edge in body.data.edges:
        a, b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)
    remaining = set(range(len(adjacency)))
    result = []
    while remaining:
        stack, group = [remaining.pop()], []
        while stack:
            current = stack.pop()
            group.append(current)
            neighbors = set(adjacency[current]) & remaining
            remaining -= neighbors
            stack.extend(neighbors)
        result.append(np.asarray(group, dtype=int))
    return result


def custom_layout(code, points, groups):
    bones, chains = {}, []
    def bone(name, head, tail, parent="cc_body"):
        bones[name] = {"head": list(head), "tail": list(tail), "parent": parent}
        return name
    center = (0, -0.28, 0.5) if code == "006" else (0, 0.10, 0.52) if code == "008" else (0, 0, 0.6)
    bone("cc_body", center, np.array(center) + (0, 0, 0.12), "c_traj")
    if code == "001":
        for i, tip in enumerate(slice_centers(points, 0.08, 0.06)):
            root = np.array((tip[0] * 0.52, tip[1] * 0.70, 0.48))
            knee = np.array((tip[0] * 0.83, tip[1] * 0.94, 0.39))
            end = np.array((tip[0], tip[1], 0.035))
            names = [bone(f"cc_leg_{i:02d}_01", root, knee),
                     bone(f"cc_leg_{i:02d}_02", knee, end, f"cc_leg_{i:02d}_01")]
            chains.append(names)
    elif code in ("002", "007"):
        if code == "002":
            stems = [points[g] for g in groups if len(g) > 1800 and points[g, 2].max() < 0.60]
            stems.sort(key=lambda s: math.atan2(s[:, 1].mean(), s[:, 0].mean()))
        else:
            centers = slice_centers(points, 0.35)
            lower = points[points[:, 2] < 0.77]
            nearest = np.argmin(np.linalg.norm(lower[:, None, :2] - np.array(centers)[None, :, :2], axis=2), axis=1)
            stems = [lower[nearest == i] for i in range(len(centers))]
        for i, stem in enumerate(stems):
            top = 0.54 if code == "002" else 0.77
            bottom = float(stem[:, 2].min()) + 0.015
            joints = []
            for z in np.linspace(top, bottom, 4):
                section = stem[np.abs(stem[:, 2] - z) < 0.035]
                if not len(section):
                    section = stem[np.argsort(np.abs(stem[:, 2] - z))[:20]]
                joints.append((float(np.median(section[:, 0])), float(np.median(section[:, 1])), z))
            chain = []
            for j in range(3):
                chain.append(bone(f"cc_tentacle_{i:02d}_{j + 1:02d}", joints[j], joints[j + 1], chain[-1] if chain else "cc_body"))
            chains.append(chain)
    elif code == "003":
        for sign, side in ((1, "l"), (-1, "r")):
            bone("cc_lobe." + side, (sign * 0.18, 0, 0.38), (sign * 0.29, 0, 0.85))
        for i, tip in enumerate(slice_centers(points, 0.10, 0.04)):
            root = np.array((tip[0] * 0.95, tip[1] * 0.8, 0.31))
            mid = np.array((tip[0], tip[1], 0.16))
            end = np.array((tip[0] * 1.04, tip[1] * 1.05, 0.015))
            parent = "cc_lobe.l" if tip[0] > 0 else "cc_lobe.r"
            chains.append([bone(f"cc_leg_{i:02d}_01", root, mid, parent),
                           bone(f"cc_leg_{i:02d}_02", mid, end, f"cc_leg_{i:02d}_01")])
    elif code == "006":
        for i, (x, z) in enumerate(((0.37, 0.68), (-0.37, 0.68), (0.37, 0.34), (-0.37, 0.34))):
            ribbon = points[(points[:, 0] * x > 0) & ((points[:, 2] > .52) if z > .52 else (points[:, 2] < .52)) & (points[:, 1] > .10)]
            joints = []
            for y in (.12, .35, .58, .80):
                section = ribbon[np.abs(ribbon[:, 1] - y) < .04]
                joints.append((float(np.median(section[:, 0])), y, float(np.median(section[:, 2]))))
            chain = []
            for j in range(3):
                head, tail = joints[j], joints[j + 1]
                chain.append(bone(f"cc_ribbon_{i:02d}_{j + 1:02d}", head, tail, chain[-1] if chain else "cc_body"))
            chains.append(chain)
    elif code == "005":
        bone("cc_ring", (0, 0, 0.5), (0.12, 0, 0.5))
        bone("cc_core", (0.025, 0, 0.52), (0.025, 0, 0.65))
        for i, (x, y) in enumerate(((0.17, 0.20), (-0.18, 0.13), (0, -0.23))):
            bone(f"cc_crystal_{i:02d}", (x, y, 0.33), (x, y, 0.78))
    elif code == "008":
        bone("cc_spine", center, (0, -0.38, 0.57))
        bone("cc_head", (0, -0.38, 0.57), (0, -0.88, 0.51), "cc_spine")
        bone("cc_jaw", (0, -0.52, 0.40), (0, -1.00, 0.36), "cc_head")
        joints = [(0, 0.40, 0.51), (0, 0.64, 0.49), (0, 0.87, 0.48), (0, 1.09, 0.48)]
        parent = "cc_body"
        for j in range(3):
            parent = bone(f"cc_tail_{j + 1:02d}", joints[j], joints[j + 1], parent)
        for limb in ("front", "hind"):
            for sign, side in ((1, "l"), (-1, "r")):
                if limb == "front":
                    joints = [(sign * .245, -.32, .49), (sign * .33, -.28, .275),
                              (sign * .33, -.365, .115), (sign * .38, -.46, .04)]
                else:
                    joints = [(sign * .23, .17, .49), (sign * .295, .225, .30),
                              (sign * .25, .31, .12), (sign * .40, .235, .04)]
                chain = []
                for j in range(3):
                    chain.append(bone(f"cc_{limb}_{j + 1:02d}.{side}", joints[j], joints[j + 1],
                                      chain[-1] if chain else "cc_spine" if limb == "front" else "cc_body"))
                chains.append(chain)
    return bones, chains


def fit_human(rig):
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    rig.data.use_mirror_x = False
    original = {b.name: (b.head.copy(), b.tail.copy()) for b in bones if "ref" in b.name}
    targets = {
        "root_ref.x": ((-0.045, 0.035, 0.46), (-0.045, 0.03, 0.55)),
        "spine_01_ref.x": ((-0.045, 0.03, 0.55), (-0.045, 0.03, 0.65)),
        "spine_02_ref.x": ((-0.045, 0.03, 0.65), (-0.045, 0.03, 0.78)),
        "neck_ref.x": ((-0.045, 0.03, 0.78), (-0.045, 0.01, 0.84)),
        "head_ref.x": ((-0.045, 0.01, 0.84), (-0.045, 0.01, 0.98)),
    }
    for side, sign in (("l", 1), ("r", -1)):
        def p(x, y, z):
            return (-0.045 + sign * x, y, z)
        shoulder, elbow = p(0.16, 0.045, 0.76), p(0.235, 0.04, 0.565)
        wrist, hand = p(0.238, 0.0, 0.385), p(0.235, -0.01, 0.315)
        hip, knee, ankle = p(0.125, 0.04, 0.465), p(0.125, 0.03, 0.265), p(0.125, 0.04, 0.075)
        ball = p(0.125, -0.055, 0.03)
        targets.update({"shoulder_ref." + side: (p(0.04, 0.035, 0.775), shoulder),
                        "arm_ref." + side: (shoulder, elbow), "forearm_ref." + side: (elbow, wrist),
                        "hand_ref." + side: (wrist, hand), "thigh_ref." + side: (hip, knee),
                        "leg_ref." + side: (knee, ankle), "foot_ref." + side: (ankle, ball),
                        "toes_ref." + side: (ball, p(0.125, -0.09, 0.025)),
                        "foot_heel_ref." + side: (p(0.125, 0.11, 0.01), p(0.125, 0.08, 0.01)),
                        "foot_bank_01_ref." + side: (p(0.17, 0.11, 0.01), p(0.17, 0.08, 0.01)),
                        "foot_bank_02_ref." + side: (p(0.08, 0.11, 0.01), p(0.08, 0.08, 0.01))})
        old_head, old_tail = original["hand_ref." + side]
        rotation = (old_tail - old_head).rotation_difference(Vector(hand) - Vector(wrist))
        for name, (head, tail) in original.items():
            if name.endswith("." + side) and any(name.startswith(s) for s in ("thumb", "index", "middle", "ring", "pinky")):
                targets[name] = (Vector(wrist) + rotation @ ((head - old_head) * 0.28),
                                 Vector(wrist) + rotation @ ((tail - old_head) * 0.28))
    for name, (head, tail) in targets.items():
        bones[name].head, bones[name].tail = head, tail
    bpy.ops.object.mode_set(mode="OBJECT")
    assert bpy.ops.arp.match_to_rig() == {"FINISHED"}
    bpy.ops.object.mode_set(mode="OBJECT")
    return {name: {"head": list(head), "tail": list(tail)} for name, (head, tail) in targets.items()}


def repair_weights(code, body, rig, points, groups, chains):
    names = [b.name for b in rig.data.bones if b.use_deform]
    index = {name: i for i, name in enumerate(names)}
    weights = np.zeros((len(points), len(names)))
    base = "root.x" if code == "004" else "cc_body"
    weights[:, index[base]] = 1
    if code == "004":
        primary = []
        for group in groups:
            if len(group) < 300:
                continue
            part = points[group]
            x, y, z = part.mean(axis=0)
            lo, hi = part.min(0), part.max(0)
            side = 'l' if x > -0.045 else 'r'
            weights[group] = 0
            if z > .84:
                weights[group, index['head.x']] = 1
            elif hi[2] < .12:
                weights[group, index['foot.' + side]] = 1
            elif lo[0] < -.10 and hi[0] > .05 and hi[2] < .56:
                root = np.clip((part[:, 2] - .39) / .10, 0, 1)
                thigh = np.clip((part[:, 2] - .22) / .09, 0, 1)
                left = np.clip((part[:, 0] + .045) / .08 + .5, 0, 1)
                weights[group, index['root.x']] = root
                for s, amount in (('l', left), ('r', 1 - left)):
                    weights[group, index['thigh_stretch.' + s]] = (1 - root) * thigh * amount
                    weights[group, index['leg_stretch.' + s]] = (1 - root) * (1 - thigh) * amount
            elif abs(x + .045) < .08:
                weights[group, index['spine_02.x' if z > .50 else 'root.x']] = 1
            elif hi[2] < .49:
                weights[group, index['hand.' + side]] = 1
            elif lo[2] > .68:
                weights[group, index['arm_stretch.' + side]] = 1
            else:
                arm = np.clip((part[:, 2] - .515) / .10, 0, 1)
                weights[group, index['arm_stretch.' + side]] = arm
                weights[group, index['forearm_stretch.' + side]] = 1 - arm
            primary.extend(group)
        # Rivets and detached armour fragments follow the nearest major shell.
        from mathutils.kdtree import KDTree
        tree = KDTree(len(primary))
        for vi in primary:
            tree.insert(points[vi], int(vi))
        tree.balance()
        for group in groups:
            if len(group) >= 300:
                continue
            center = points[group].mean(0)
            if center[0] > .02 and center[2] < .75 and center[1] - .7 * center[0] < -.14:
                weights[group] = 0
                weights[group, index['hand.l']] = 1
            else:
                for vi in group:
                    weights[vi] = weights[tree.find(points[vi])[1]]
    elif code == "008":
        def smooth(value):
            value = np.clip(value, 0, 1)
            return value * value * (3 - 2 * value)
        spine = smooth((.18 - points[:, 1]) / .42)
        head = smooth((-.32 - points[:, 1]) / .30)
        weights[:, index['cc_body']] = 1 - spine
        weights[:, index['cc_spine']] = spine * (1 - head)
        weights[:, index['cc_head']] = spine * head
        jaw = smooth((.405 - points[:, 2]) / .095) * smooth((-.49 - points[:, 1]) / .20)
        weights *= 1 - jaw[:, None]
        weights[:, index['cc_jaw']] += jaw
        tail = smooth((points[:, 1] - .37) / .17)
        weights *= 1 - tail[:, None]
        position = np.clip((points[:, 1] - .40) / .23 - .5, 0, 2)
        for j in range(3):
            weights[:, index[f'cc_tail_{j + 1:02d}']] += tail * np.maximum(0, 1 - np.abs(position - j))
        for chain in chains:
            front = 'front' in chain[0]
            sign = 1 if chain[0].endswith('.l') else -1
            strength = smooth((.53 - points[:, 2]) / .28)
            strength *= smooth((points[:, 0] * sign - .12) / .12)
            strength *= smooth(((-.03 - points[:, 1]) if front else (points[:, 1] + .03)) / .12)
            ds = np.array([segment_distances(points, rig.data.bones[n].head_local, rig.data.bones[n].tail_local)[0] for n in chain]).T
            near = ds.argmin(axis=1)
            positions = np.empty(len(points))
            for j, name in enumerate(chain):
                _, fraction = segment_distances(points, rig.data.bones[name].head_local, rig.data.bones[name].tail_local)
                mask = near == j
                positions[mask] = np.clip(j + fraction[mask] - .5, 0, 2)
            weights *= 1 - strength[:, None]
            for j, name in enumerate(chain):
                weights[:, index[name]] += strength * np.maximum(0, 1 - np.abs(positions - j))
    elif code == "005":
        for group in groups:
            part = points[group]
            center = part.mean(axis=0)
            extent = np.ptp(part, axis=0)
            radius = math.hypot(center[1], center[2] - 0.5)
            if extent[1] > 0.85 or (radius > 0.42 and abs(center[0]) < 0.18):
                name = "cc_ring"
            elif np.linalg.norm(center - (0.025, 0, 0.52)) < 0.19:
                name = "cc_core"
            else:
                name = min((f"cc_crystal_{i:02d}" for i in range(3)), key=lambda n: np.linalg.norm(center - np.array(rig.data.bones[n].head_local)))
            weights[group] = 0
            weights[group, index[name]] = 1
    else:
        if code == "003":
            for sign, side in ((1, "l"), (-1, "r")):
                strength = np.clip((points[:, 0] * sign - 0.03) / 0.22, 0, 1) * np.clip((points[:, 2] - 0.25) / 0.16, 0, 1)
                weights *= (1 - strength[:, None])
                weights[:, index["cc_lobe." + side]] += strength
        distances = np.array([[segment_distances(points, rig.data.bones[n].head_local, rig.data.bones[n].tail_local)[0] for n in chain] for chain in chains])
        closest = np.argmin(distances.min(axis=1), axis=0)
        for ci, chain in enumerate(chains):
            ds = distances[ci].T
            mask = closest == ci
            if code == "001":
                strength = np.clip((0.56 - points[:, 2]) / 0.10, 0, 1) * np.clip((0.16 - ds.min(axis=1)) / 0.055, 0, 1)
                strength *= np.clip((np.abs(points[:, 0]) - 0.12) / 0.08, 0, 1)
            elif code in ("002", "007"):
                top = 0.55 if code == "002" else 0.61
                strength = np.clip((top - points[:, 2]) / 0.13, 0, 1)
            elif code == "003":
                strength = np.clip((0.35 - points[:, 2]) / 0.07, 0, 1)
            else:
                strength = np.clip((points[:, 1] - 0.17) / 0.17, 0, 1)
            ids = np.flatnonzero(mask & (strength > 0))
            for vi in ids:
                nearest = int(np.argmin(ds[vi]))
                bone = rig.data.bones[chain[nearest]]
                _, fraction = segment_distances(points[vi:vi + 1], bone.head_local, bone.tail_local)
                position = float(np.clip(nearest + fraction[0] - .5, 0, len(chain) - 1))
                start = int(position)
                order = [start, min(start + 1, len(chain) - 1)]
                values = [1 - (position - start), position - start]
                weights[vi] *= 1 - strength[vi]
                for j, value in zip(order, values):
                    weights[vi, index[chain[j]]] += value * strength[vi]
    # Diffuse only along actual surface edges, never across nearby limbs.
    edges = np.array([list(e.vertices) for e in body.data.edges])
    dst = np.concatenate((edges[:, 0], edges[:, 1]))
    src = np.concatenate((edges[:, 1], edges[:, 0]))
    degree = np.bincount(dst, minlength=len(points))
    active = np.flatnonzero(weights.max(axis=0) > 0)
    for _ in range(160 if code == "008" else 48):
        for bi in active:
            average = np.bincount(dst, weights=weights[src, bi], minlength=len(points)) / np.maximum(degree, 1)
            weights[:, bi] = weights[:, bi] * 0.25 + average * 0.75
    body.vertex_groups.clear()
    for name in names:
        body.vertex_groups.new(name=name)
    for vi in range(len(points)):
        order = np.argsort(weights[vi])[-4:]
        order = order[weights[vi, order] > 0.00001]
        values = weights[vi, order]
        values /= values.sum()
        for i, value in zip(order, values):
            body.vertex_groups[names[i]].add([vi], float(value), "REPLACE")
    return {"unweighted": int(np.sum(weights.sum(axis=1) < 0.99)),
            "used_groups": [names[i] for i in range(len(names)) if weights[:, i].max() > 0.00001]}


def build(code):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.name = "Enemy_" + code + "_ARP"
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / "source" / (code + ".glb")))
    body = next(o for o in scene.objects if o.type == "MESH")
    body.name = "Enemy_" + code + "_Body"
    body.data.transform(body.matrix_world)
    body.matrix_world = Matrix.Identity(4)
    body.data.transform(Matrix.Scale(1 / body.dimensions.z, 4) @ Matrix.Rotation(-math.pi / 2, 4, "Z"))
    bm = bmesh.new()
    bm.from_mesh(body.data)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000002)
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    points = np.array([list(v.co) for v in body.data.vertices])
    groups = components(body)
    bpy.ops.arp.append_arp(rig_preset="human" if code == "004" else "free")
    rig = bpy.context.active_object
    rig.name = "Enemy_" + code + "_ARP_Rig"
    rig.show_in_front = True
    layout, chains = {}, []
    if code == "004":
        layout = fit_human(rig)
    else:
        layout, chains = custom_layout(code, points, groups)
        bpy.ops.object.mode_set(mode="EDIT")
        for name, item in layout.items():
            bone = rig.data.edit_bones.new(name)
            bone.head, bone.tail = item["head"], item["tail"]
            bone.parent = rig.data.edit_bones[item["parent"]]
            bone.use_deform = True
        bpy.ops.armature.select_all(action="DESELECT")
        for name in layout:
            rig.data.edit_bones[name].select = True
        assert bpy.ops.arp.set_bone_tag(tag="cc") == {"FINISHED"}
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    scene.arp_bind_engine = "HEAT_MAP"
    scene.arp_bind_split = False
    scene.arp_bind_scale_fix = True
    scene.arp_optimize_highres = False
    result = bpy.ops.arp.bind_to_rig()
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.data.pose_position = "POSE"
    initial_unweighted = sum(not any(g.weight > 0.00001 for g in v.groups) for v in body.data.vertices)
    repaired = repair_weights(code, body, rig, points, groups, chains)
    assert repaired["unweighted"] == 0
    assert any(m.type == "ARMATURE" and m.object == rig for m in body.modifiers)
    for mod in body.modifiers:
        if mod.type == "ARMATURE":
            mod.use_deform_preserve_volume = False
    for image in bpy.data.images:
        if image.users and image.source == "FILE" and not image.packed_file:
            image.pack()
    data = {"code": code, "kind": NAMES[code], "arp_preset": "human" if code == "004" else "free + registered custom FK chains",
            "arp_bind_result": sorted(result), "vertices_before_weld": before, "vertices": len(points),
            "initial_unweighted": initial_unweighted, "weights": repaired, "joints": layout, "chains": chains,
            "deform_bones": [b.name for b in rig.data.bones if b.use_deform]}
    (OUT / (code + "_rig.json")).write_text(json.dumps(data, indent=2), encoding="utf-8")
    SOURCE.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (code + "_" + NAMES[code] + "_arp.blend")), compress=True)
    np.save(OUT / (code + "_rest.npy"), points)
    print("ENEMY_RIG_READY", code, len(data["deform_bones"]), initial_unweighted, repaired["unweighted"], flush=True)


if __name__ == '__main__':
    codes = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else list(NAMES)
    area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
    region = next(r for r in area.regions if r.type == "WINDOW")
    with bpy.context.temp_override(area=area, region=region):
        for code in codes:
            build(code)
    print("ALL_ENEMY_RIGS_READY")
