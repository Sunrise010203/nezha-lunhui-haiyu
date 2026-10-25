"""Anatomical layout helpers for this seven-model batch, in normalized Z-up space."""
import numpy as np


def slice_centers(points, height, radius=0.025, thickness=0.015):
    section = points[np.abs(points[:, 2] - height) < thickness]
    remaining = set(range(len(section)))
    result = []
    while remaining:
        stack, indices = [remaining.pop()], []
        while stack:
            index = stack.pop()
            indices.append(index)
            neighbors = set(np.flatnonzero(np.linalg.norm(section[:, :2] - section[index, :2], axis=1) < radius)) & remaining
            remaining -= neighbors
            stack.extend(neighbors)
        if len(indices) > 3:
            result.append(section[indices].mean(axis=0))
    return sorted(result, key=lambda p: np.arctan2(p[1], p[0]))


def segment_distances(points, head, tail):
    head, tail = np.asarray(head), np.asarray(tail)
    vector = tail - head
    t = np.clip((points - head) @ vector / (vector @ vector), 0, 1)
    return np.linalg.norm(points - head - t[:, None] * vector, axis=1), t


if __name__ == "__main__":
    from pathlib import Path
    out = Path("E:/godot_game_by_fable/_review/enemies_arp")
    for code, z, radius in (("001", 0.08, 0.06), ("003", 0.1, 0.04), ("007", 0.35, 0.025)):
        points = np.load(out / (code + "_canonical_vertices.npy"))
        centers = slice_centers(points, z, radius)
        print(code, len(centers), [p.round(3).tolist() for p in centers])
