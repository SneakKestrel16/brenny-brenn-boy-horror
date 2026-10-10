"""Poly Pizza lookup (P4-40, D-151). Prints candidates with their licence (use CC0 only); saves bytes only, never runs anything fetched.

  uv run --no-project python -I tools/blender/polypizza.py search <term> [max]   -> id, license, title, glb url
  uv run --no-project python -I tools/blender/polypizza.py get <glb_url> <out_path> [<glb_url> <out_path> ...]
"""
import re
import sys
import urllib.parse
import urllib.request

UA = {"User-Agent": "Mozilla/5.0"}


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40).read()


if sys.argv[1] == "get":
    for a, b in zip(sys.argv[2::2], sys.argv[3::2]):  # url out_path pairs
        open(b, "wb").write(fetch(a))
    sys.exit()
page = fetch("https://poly.pizza/search/" + urllib.parse.quote(sys.argv[2])).decode()
ids = list(dict.fromkeys(re.findall(r'href="/m/([^"]+)"', page)))[: int(sys.argv[3]) if len(sys.argv) > 3 else 12]
for i in ids:
    h = fetch("https://poly.pizza/m/" + i).decode()
    lic = (re.search(r"\"Licence\":\"([^\"]*)", h) or ["", "?"])[1]
    title = (re.search(r"og:title\" content=\"([^\"]*)", h) or ["", "?"])[1]
    glb = (re.search(r'(https://static\.poly\.pizza/[^"&]+\.glb)', h) or ["", ""])[1]
    print(i, lic, title.strip(), glb, sep="\t")
