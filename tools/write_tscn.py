# -*- coding: utf-8 -*-
"""用字节方式写一个最小 .tscn，避免 PowerShell 的 BOM/编码问题。"""
import sys

path, node, script = sys.argv[1], sys.argv[2], sys.argv[3]
text = (
    '[gd_scene load_steps=2 format=3]\n'
    '\n'
    '[ext_resource type="Script" path="%s" id="1_env"]\n'
    '\n'
    '[node name="%s" type="Node3D"]\n'
    'script = ExtResource("1_env")\n'
) % (script, node)

with open(path, "wb") as f:
    f.write(text.encode("utf-8"))
print("wrote", path)
print(text)
