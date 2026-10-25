# -*- coding: utf-8 -*-
"""在 001 的 showcase 脚本里把相机显式设为 current（游戏工程里有 autoload，默认相机可能不是我们新增的那台）。"""
import sys

path = sys.argv[1]
b = open(path, "rb").read()
old = b'cam.position = Vector3(0, VIEW_CY, 12.0)'
new = b'cam.current = true\n\tcam.position = Vector3(0, VIEW_CY, 12.0)'
if old not in b:
    print("anchor not found")
    sys.exit(1)
b = b.replace(old, new, 1)
open(path, "wb").write(b)
print("patched current camera")
