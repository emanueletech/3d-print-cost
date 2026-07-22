#!/usr/bin/env python3
"""Remap 3mf build-item XY from the P1S plate grid to the H2C plate grid.

Grid stride = bed_size * 1.2 (LOGICAL_PART_PLATE_GAP = 1/5).
P1S: 256x256 -> stride 307.2 ; H2C: 330x320 -> stride 396 x, 384 y.
Objects keep their position relative to their plate, plus a centering
offset so the old 256x256 layout sits centered in the 330x320 plate
(clear of both extruders' restricted 25 mm side bands).
"""
import re, sys, zipfile, shutil

OLD_SX = OLD_SY = 256 * 1.2
NEW_SX, NEW_SY = 330 * 1.2, 320 * 1.2
OFF_X, OFF_Y = (330 - 256) / 2.0, (320 - 256) / 2.0
MARGIN = 40  # objects may hang slightly off their plate

def cell(v, stride, sign=1):
    """Grid index whose local coordinate falls inside [-MARGIN, 256+MARGIN].

    Columns grow along +x (sign=1), rows along -y (sign=-1)."""
    best, bloc = None, None
    for i in range(0, 8):
        loc = v - sign * i * stride
        if -MARGIN <= loc <= 256 + MARGIN:
            if best is None or abs(loc - 128) < abs(bloc - 128):
                best, bloc = i, loc
    if best is None:
        raise ValueError(f"no grid cell for {v}")
    return best, bloc

def remap_model(xml):
    def fix(m):
        vals = m.group(2).split()
        x, y = float(vals[9]), float(vals[10])
        cx, lx = cell(x, OLD_SX)
        cy, loc_y = cell(y, OLD_SY, sign=-1)
        nx = cx * NEW_SX + OFF_X + lx
        ny = -(cy * NEW_SY) + OFF_Y + loc_y
        vals[9], vals[10] = f"{nx:.6f}", f"{ny:.6f}"
        return f'{m.group(1)}transform="{" ".join(vals)}"'
    # only <item> transforms inside <build> — component transforms must stay
    start = xml.index("<build")
    end = xml.index("</build>")
    build = re.sub(r'(<item [^>]*?)transform="([^"]+)"', fix, xml[start:end])
    return xml[:start] + build + xml[end:]

import os
MACHINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles", "machine_H2C_04.json")

def patch_settings(raw):
    import json
    cfg = json.loads(raw)
    mach = json.load(open(MACHINE))
    for k in ("printer_model", "printer_settings_id", "printable_area",
              "printable_height", "extruder_printable_area",
              "extruder_printable_height", "printer_variant",
              "master_extruder_id", "physical_extruder_map",
              "extruder_offset"):
        if k in mach:
            cfg[k] = mach[k]
    return json.dumps(cfg, indent=4)

def main(src, dst):
    shutil.copy(src, dst)
    zin = zipfile.ZipFile(src)
    fixed = remap_model(zin.read("3D/3dmodel.model").decode())
    settings = patch_settings(zin.read("Metadata/project_settings.config").decode())
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename == "3D/3dmodel.model":
                data = fixed.encode()
            elif item.filename == "Metadata/project_settings.config":
                data = settings.encode()
            else:
                data = zin.read(item.filename)
            zout.writestr(item, data)
    print("remapped", src, "->", dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
