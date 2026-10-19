"""Blender remote-control client (BlenderMCP addon TCP server).

Usage (from PowerShell, code always via FILE to avoid quoting issues):
    python blender_ctl.py --file build_asset.py
    python blender_ctl.py --type get_scene_info
    python blender_ctl.py --screenshot C:\\tmp\\view.png

Protocol: one JSON object in -> one JSON object out, no framing.
"""
import json
import socket
import sys

DEFAULT_PORT = 9876


class BlenderClient:
    def __init__(self, host="127.0.0.1", port=DEFAULT_PORT, timeout=600.0):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.sock = None

    def connect(self):
        self.sock = socket.create_connection((self.host, self.port), timeout=10)
        self.sock.settimeout(self.timeout)
        return self

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None

    def send(self, cmd_type, params=None):
        if self.sock is None:
            self.connect()
        self.sock.sendall(
            json.dumps({"type": cmd_type, "params": params or {}}).encode("utf-8")
        )
        data = b""
        while True:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise RuntimeError(
                    "Blender closed the connection: " + data.decode("utf-8", "replace")
                )
            data += chunk
            try:
                return json.loads(data.decode("utf-8"))
            except json.JSONDecodeError:
                continue

    def code(self, src):
        return self.send("execute_code", {"code": src})

    def run_file(self, path):
        with open(path, encoding="utf-8") as f:
            return self.code(f.read())

    def screenshot(self, filepath, max_size=900):
        return self.send(
            "get_viewport_screenshot",
            {"filepath": filepath, "max_size": max_size, "format": "png"},
        )


def main():
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--type", default=None)
    ap.add_argument("--params", default=None, help="JSON object")
    ap.add_argument("--code", default=None)
    ap.add_argument("--file", default=None)
    ap.add_argument("--screenshot", default=None)
    args = ap.parse_args()

    c = BlenderClient(port=args.port).connect()
    try:
        if args.file:
            out = c.run_file(args.file)
        elif args.code:
            out = c.code(args.code)
        elif args.screenshot:
            out = c.screenshot(args.screenshot)
        else:
            out = c.send(
                args.type or "get_scene_info",
                json.loads(args.params) if args.params else {},
            )
        print(json.dumps(out, ensure_ascii=False, indent=1))
    finally:
        c.close()


if __name__ == "__main__":
    main()
