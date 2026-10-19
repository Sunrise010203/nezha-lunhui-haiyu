"""Dump Poly Haven model metadata and filter by keywords (offline-capable)."""
import json
import os
import sys
import urllib.request

CACHE = r"E:\godot_game_by_fable\tools\blender\library\polyhaven_models.json"


def fetch():
    if os.path.exists(CACHE) and os.path.getsize(CACHE) > 1000:
        return json.load(open(CACHE, encoding="utf-8"))
    req = urllib.request.Request("https://api.polyhaven.com/assets?type=models",
                                 headers={"User-Agent": "local-tool"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read().decode("utf-8"))
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump(data, open(CACHE, "w", encoding="utf-8"))
    return data


def main():
    data = fetch()
    print("TOTAL MODELS:", len(data))
    if len(sys.argv) > 1:
        kws = [k.lower() for k in sys.argv[1:]]
        hits = []
        for aid, meta in data.items():
            blob = (aid + " " + meta.get("name", "") + " " +
                    " ".join(meta.get("categories", []))).lower()
            if all(k in blob for k in kws):
                hits.append((aid, meta.get("categories", [])[:3],
                             meta.get("download_count", 0)))
        hits.sort(key=lambda h: -h[2])
        print(f"MATCHES for {kws}: {len(hits)}")
        for aid, cats, dl in hits[:40]:
            print(f"  {aid:<34} dl={dl:<7} {cats}")


if __name__ == "__main__":
    main()
