#!/usr/bin/env python3
"""从内嵌 PCK 的 Windows exe 中切出资源包（只读 exe，不修改 exe）。

Godot 4.6 embed_pck 的 exe 末尾结构（实测）：
    [exe/模板][PCK 数据][u64 pck_size][4 字节 "GDPC"]
PCK 起点 = 文件长度 - 12 - pck_size，起点必须是 "GDPC"。

用法: python extract_pck.py <exe> <out.pck>
"""
import struct
import sys
from pathlib import Path

MAGIC = b"GDPC"


def main() -> int:
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    data = src.read_bytes()
    total = len(data)
    if data[-4:] != MAGIC:
        print("NO_TRAILER_MAGIC", data[-4:])
        return 1
    size = struct.unpack_from("<Q", data, total - 12)[0]
    start = total - 12 - size
    if start < 0 or data[start:start + 4] != MAGIC:
        print(f"BAD_LAYOUT start={start} size={size} head={data[start:start+4]!r}")
        return 1
    pck = data[start:total - 12]
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(pck)
    print(f"pck_start={start} pck_size={len(pck)} exe_size={total}")
    print(f"wrote {dst} bytes={dst.stat().st_size} magic={pck[:4]!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
