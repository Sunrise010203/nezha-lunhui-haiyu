"""Launch Blender with the BlenderMCP control server, wait until it is listening.

Why Python instead of a .ps1: this machine's PowerShell execution policy blocks
unsigned .ps1 files, and `pwsh` is not on PATH. A Python launcher has neither problem.

Usage:
    python launch_blender.py
    python launch_blender.py --file out\\crystal_prop.blend
    python launch_blender.py --port 9876 --timeout 90
"""
import argparse
import os
import socket
import subprocess
import sys
import time

DEFAULT_EXE = r"E:\blender\app\blender.exe"


def port_open(port, host="127.0.0.1", timeout=0.35):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=None, help="optional .blend to open")
    ap.add_argument("--exe", default=DEFAULT_EXE)
    ap.add_argument("--port", type=int, default=9876)
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--detach", action="store_true", help="do not tie Blender to this shell")
    args = ap.parse_args()

    if not os.path.exists(args.exe):
        print(f"ERROR: Blender not found at {args.exe}", file=sys.stderr)
        return 2

    if port_open(args.port):
        print(f"Already listening on 127.0.0.1:{args.port} - reusing the running Blender.")
        return 0

    cmd = [args.exe]
    if args.file:
        path = os.path.abspath(args.file)
        if not os.path.exists(path):
            print(f"ERROR: blend file not found: {path}", file=sys.stderr)
            return 2
        cmd.append(path)

    flags = 0
    if args.detach and os.name == "nt":
        flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    proc = subprocess.Popen(cmd, creationflags=flags)
    print(f"Launched Blender (pid {proc.pid}), waiting for control server on port {args.port} ...")

    deadline = time.time() + args.timeout
    while time.time() < deadline:
        time.sleep(0.5)
        if port_open(args.port):
            print(f"Ready: 127.0.0.1:{args.port}")
            return 0
        if proc.poll() is not None:
            print(f"ERROR: Blender exited during startup (code {proc.returncode})", file=sys.stderr)
            return 1

    print(f"ERROR: timed out after {args.timeout}s. "
          f"Is the BlenderMCP addon enabled in Blender preferences?", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
