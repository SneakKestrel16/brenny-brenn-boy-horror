"""Count pure #FFFFFF pixels in a PNG (doc 07 s2: nothing is pure white). uv run --with pillow python tools/blender/count_white.py <png>"""
import sys

from PIL import Image

im = Image.open(sys.argv[1]).convert("RGB")
print(sum(1 for p in im.getdata() if p == (255, 255, 255)))
