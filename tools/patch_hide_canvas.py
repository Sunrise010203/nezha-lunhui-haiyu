# -*- coding: utf-8 -*-
"""showcase 截图前隐藏项目里所有 CanvasLayer（001 的 Game autoload 带全屏黑幕）。"""
import sys

path = sys.argv[1]
b = open(path, "rb").read()
anchor = b'\tawait get_tree().process_frame\n\tawait get_tree().process_frame\n\tawait RenderingServer.frame_post_draw'
inject = (b'\tfor cl in get_tree().root.find_children("*", "CanvasLayer", true, false):\n'
          b'\t\tcl.visible = false\n'
          b'\tawait get_tree().process_frame\n'
          b'\tawait get_tree().process_frame\n'
          b'\tawait RenderingServer.frame_post_draw')
if anchor not in b:
    print("anchor missing")
    sys.exit(1)
b = b.replace(anchor, inject, 1)
open(path, "wb").write(b)
print("injected canvas hide")
