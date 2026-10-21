"""Only post-processing of the Edge capture: resize to at most 3000 px wide, save PNG (for Word) and an
RGB TIFF with LZW compression at 300 dpi; then re-open the TIFF and verify mode, compression and dpi.
Usage: python figures/totif.py <in.png> <out-stem>"""
import sys
from PIL import Image

src, stem = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
if im.width > 3000:
    im = im.resize((3000, round(im.height * 3000 / im.width)), Image.LANCZOS)
im.save(stem + ".png", dpi=(300, 300))
im.save(stem + ".tif", compression="tiff_lzw", dpi=(300, 300))
t = Image.open(stem + ".tif")
dpi = tuple(round(float(v)) for v in t.info.get("dpi", (0, 0)))
ok = t.mode == "RGB" and t.info.get("compression") == "tiff_lzw" and dpi[0] >= 300 and dpi[1] >= 300
print(f"{stem}.tif: {t.width}x{t.height} mode={t.mode} compression={t.info.get('compression')} dpi={dpi} -> {'PASS' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
