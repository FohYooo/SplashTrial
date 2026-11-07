#!/usr/bin/env python3
"""Mark every raw asset (svg/wav/ogg) with importer="keep" so Godot exports the raw file
(the game loads them at runtime with Image.load_svg_from_string / AudioStreamWAV.load_from_file).
Run before any editor/export command:  python3 tools/prepare_export.py"""
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
n = 0
for d, _, files in os.walk(root):
    if "/.godot" in d or "/tools" in d or "/build" in d or "/docs" in d:
        continue
    for f in files:
        if f.lower().endswith((".svg", ".wav", ".ogg")):
            imp = os.path.join(d, f + ".import")
            want = '[remap]\n\nimporter="keep"\n'
            cur = open(imp).read() if os.path.exists(imp) else ""
            if 'importer="keep"' not in cur:
                open(imp, "w").write(want)
                n += 1
print(f"marked {n} new files as keep")
