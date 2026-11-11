#!/usr/bin/env python3
"""Mark every raw asset (svg/wav/ogg, and the photographs under art/ as jpg/png) with importer="keep" so Godot
exports the raw file (the game loads them at runtime with Image.load_svg_from_string / load_jpg_from_buffer /
AudioStreamWAV.load_from_file).
Run before any editor/export command:  python3 tools/prepare_export.py"""
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
n = 0
for d, _, files in os.walk(root):
    if "/.godot" in d or "/tools" in d or "/build" in d or "/docs" in d:
        continue
    for f in files:
        raster = f.lower().endswith((".jpg", ".png")) and (os.sep + "art" + os.sep) in (d + os.sep)
        if f.lower().endswith((".svg", ".wav", ".ogg")) or raster:
            imp = os.path.join(d, f + ".import")
            want = '[remap]\n\nimporter="keep"\n'
            cur = open(imp).read() if os.path.exists(imp) else ""
            if 'importer="keep"' not in cur:
                open(imp, "w").write(want)
                n += 1
print(f"marked {n} new files as keep")
