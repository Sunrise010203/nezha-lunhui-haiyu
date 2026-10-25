# -*- coding: utf-8 -*-
"""带重试的 APIMart 批量出图（避免一次 SSL 抖动就丢掉已付费的任务）。

用法: python gen_assets2.py --group a|b|c [--only slug1,slug2]
台账: art_assets/_ledger_<group>.json  (slug -> task_id / status / file)
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from gen_assets import A, B, C, COMMON, OUT

BASE = "https://api.apimart.ai"
KEY = os.environ.get("APIMART_API_KEY") or "sk-TYNLOTDkRu92TouPi1pyhvTZo2cG5vum9GlSEAAhToqrkhMx"
MODEL = "gpt-image-2"
GROUPS = {"a": A, "b": B, "c": C}
OUTDIR = Path(OUT)


def log(*a):
    print(*a, flush=True)


def _once(method: str, path: str, payload: dict | None = None, timeout: int = 90) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {KEY}")
    req.add_header("Accept", "application/json")
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read().decode("utf-8", "replace")
    obj = json.loads(raw)
    if isinstance(obj, dict) and obj.get("code") not in (None, 200, 201):
        raise RuntimeError(f"code={obj.get('code')} {raw[:300]}")
    return obj


def call(method: str, path: str, payload: dict | None = None, attempts: int = 12) -> dict:
    last = None
    for i in range(attempts):
        try:
            return _once(method, path, payload)
        except urllib.error.HTTPError as e:
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")[:200]
            except Exception:
                pass
            if e.code in (429, 500, 502, 503, 504):
                last = f"HTTP {e.code} {body}"
            else:
                raise RuntimeError(f"HTTP {e.code} {body}") from None
        except Exception as e:  # 网络/SSL/JSON
            last = f"{type(e).__name__}: {str(e)[:80]}"
        time.sleep(min(1.6 ** i, 20) + random.random())
    raise RuntimeError(f"gave up {method} {path}: {last}")


def submit(prompt: str, size: str) -> str:
    obj = call("POST", "/v1/images/generations",
               {"model": MODEL, "prompt": prompt, "n": 1, "size": size, "resolution": "1k"})
    data = obj.get("data")
    cands = data if isinstance(data, list) else [data] if isinstance(data, dict) else []
    for c in cands:
        if isinstance(c, dict) and c.get("task_id"):
            return str(c["task_id"])
    raise RuntimeError(f"no task_id: {json.dumps(obj)[:300]}")


def poll(task_id: str) -> dict:
    t0 = time.time()
    while time.time() - t0 < 900:
        obj = call("GET", f"/v1/tasks/{task_id}?language=zh", attempts=20)
        task = obj.get("data") if isinstance(obj.get("data"), dict) else obj
        st = (task or {}).get("status")
        if st == "completed":
            return task
        if st in ("failed", "cancelled"):
            raise RuntimeError(f"task {st}: {(task.get('error') or {})}")
        time.sleep(3)
    raise RuntimeError("poll timeout")


def urls_of(node) -> list[str]:
    out = []
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, list):
        for x in node:
            out += urls_of(x)
    elif isinstance(node, dict):
        for k in ("url", "urls", "image_url", "image_urls", "images"):
            if k in node:
                out += urls_of(node[k])
    return out


def download(url: str, slug: str) -> Path:
    for i in range(12):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                data = r.read()
            if data:
                p = OUTDIR / f"{slug}.png"
                p.write_bytes(data)
                return p
        except Exception:
            pass
        time.sleep(min(1.6 ** i, 15))
    raise RuntimeError("download failed")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", required=True, choices=list(GROUPS))
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    ledger_path = OUTDIR / f"_ledger_{a.group}.json"
    ledger = json.loads(ledger_path.read_text("utf-8")) if ledger_path.exists() else {}

    items = [it for it in GROUPS[a.group] if (not only or it[0] in only)]
    for slug, size, prompt in items:
        if (OUTDIR / f"{slug}.png").exists():
            log(f"[SKIP] {slug}")
            continue
        rec = ledger.get(slug, {})
        try:
            tid = rec.get("task_id")
            if not tid or rec.get("status") == "failed":
                tid = submit(COMMON + ", " + prompt, size)
                ledger[slug] = {"task_id": tid, "status": "submitted"}
                ledger_path.write_text(json.dumps(ledger, indent=1), "utf-8")
                log(f"[SUBMIT] {slug} {tid}")
            task = poll(tid)
            urls = urls_of(task.get("result"))
            if not urls:
                raise RuntimeError("no url in result")
            p = download(urls[0], slug)
            ledger[slug] = {"task_id": tid, "status": "ok", "file": str(p)}
            ledger_path.write_text(json.dumps(ledger, indent=1), "utf-8")
            log(f"[OK] {slug} -> {p.name}")
        except Exception as e:
            ledger[slug] = {**ledger.get(slug, {}), "status": "failed", "error": str(e)[:200]}
            ledger_path.write_text(json.dumps(ledger, indent=1), "utf-8")
            log(f"[FAIL] {slug}: {e}")
    log(f"GROUP {a.group} DONE")


if __name__ == "__main__":
    main()
