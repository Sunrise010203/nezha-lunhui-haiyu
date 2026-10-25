import os, time, urllib.request

URL = "https://api.apimart.ai/v1/models"


def probe(n=4):
    ok, errs = 0, []
    for _ in range(n):
        try:
            with urllib.request.urlopen(URL, timeout=25) as r:
                r.read(10)
            ok += 1
        except Exception as e:
            errs.append(type(e).__name__ + ":" + str(e)[:50])
        time.sleep(0.4)
    return ok, errs


print("direct", probe())
os.environ["HTTPS_PROXY"] = "http://127.0.0.1:65372"
os.environ["HTTP_PROXY"] = "http://127.0.0.1:65372"
print("proxy ", probe())
