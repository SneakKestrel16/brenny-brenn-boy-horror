"""List a public Google Drive folder (embeddedfolderview): 'id<TAB>kind<TAB>name'.

Usage: uv run --no-project python -I tools/blender/drive_list.py <folder_id> [download <file_id> <out_path>]
Download helper only (P4-40, D-151); it prints names and saves bytes, it never executes anything fetched.
"""
import re
import sys
import urllib.request

if len(sys.argv) > 2 and sys.argv[2] == "download":
    url = "https://drive.usercontent.google.com/download?export=download&confirm=t&id=" + sys.argv[3]
    open(sys.argv[4], "wb").write(urllib.request.urlopen(url, timeout=120).read())
    sys.exit()
html = urllib.request.urlopen("https://drive.google.com/embeddedfolderview?id=" + sys.argv[1], timeout=30).read().decode()
for m in re.finditer(r'<a href="https://drive.google.com/(file/d|drive/folders)/([^/"?]+)[^>]*>.*?flip-entry-title">([^<]*)', html, re.S):
    print(m.group(2), "folder" if "folders" in m.group(1) else "file", m.group(3), sep="\t")
