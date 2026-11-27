"""Godot 내보내기 템플릿(.tpz, 약 1.3GB)에서 필요한 파일만 HTTP Range로 받아 온다.

사용: python3 fetch_web_template.py <tpz URL> <저장 폴더> <파일 이름>...
예:   python3 fetch_web_template.py https://.../Godot_v4.7.2-stable_export_templates.tpz \
          ~/.local/share/godot/export_templates/4.7.2.stable web_nothreads_release.zip
"""
import os, sys, struct, zlib, urllib.request
url = sys.argv[1]; out_dir = sys.argv[2]; want = set(sys.argv[3:])
os.makedirs(out_dir, exist_ok=True)
def get(a, b):
    r = urllib.request.Request(url, headers={"Range": f"bytes={a}-{b}"})
    return urllib.request.urlopen(r).read()
h = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"))
size = int(h.headers["Content-Length"])
tail = get(size - 65536, size - 1)
i = tail.rfind(b"PK\x05\x06")
cd_size, cd_off = struct.unpack("<II", tail[i+12:i+20])
if cd_off == 0xFFFFFFFF:
    j = tail.rfind(b"PK\x06\x06")
    cd_size, cd_off = struct.unpack("<QQ", tail[j+40:j+56])
cd = get(cd_off, cd_off + cd_size - 1)
p = 0
while p < len(cd) and cd[p:p+4] == b"PK\x01\x02":
    meth, = struct.unpack("<H", cd[p+10:p+12])
    csize, usize = struct.unpack("<II", cd[p+20:p+28])
    nl, el, cl = struct.unpack("<HHH", cd[p+28:p+34])
    off, = struct.unpack("<I", cd[p+42:p+46])
    name = cd[p+46:p+46+nl].decode()
    extra = cd[p+46+nl:p+46+nl+el]
    q = 0; vals = []
    while q < len(extra):
        hid, hl = struct.unpack("<HH", extra[q:q+4])
        if hid == 1:
            n = hl // 8; vals = list(struct.unpack("<%dQ" % n, extra[q+4:q+4+8*n]))
        q += 4 + hl
    if usize == 0xFFFFFFFF: usize = vals.pop(0)
    if csize == 0xFFFFFFFF: csize = vals.pop(0)
    if off == 0xFFFFFFFF: off = vals.pop(0)
    base = name.split("/")[-1]
    if base in want:
        lh = get(off, off + 29)
        lnl, lel = struct.unpack("<HH", lh[26:30])
        data = get(off + 30 + lnl + lel, off + 30 + lnl + lel + csize - 1)
        out = zlib.decompress(data, -15) if meth == 8 else data
        open(os.path.join(out_dir, base), "wb").write(out); print("got", name, len(out))
        want.discard(base)
    p += 46 + nl + el + cl
if want:
    sys.exit("not found in templates: " + ", ".join(sorted(want)))
