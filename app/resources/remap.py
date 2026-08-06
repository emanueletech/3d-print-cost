#!/usr/bin/env python3
"""Remap 3mf build-item XY from the P1S plate grid to the target machine grid.

Grid stride = bed_size * 1.2 (LOGICAL_PART_PLATE_GAP = 1/5).
Objects keep their position relative to their plate, plus a centering
offset so the old 256x256 layout sits centered in the target plate
(clear of the extruders' restricted side bands on dual-nozzle machines).
The target machine profile can be passed as third argument (v1.2);
default is the bundled H2C profile.
"""
import re, sys, os, json, zipfile, shutil

OLD_SX = OLD_SY = 256 * 1.2
MARGIN = 40  # objects may hang slightly off their plate

MACHINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles", "machine_H2C_04.json")
# geometria di destinazione: calcolata da printable_area del profilo macchina
BED_W, BED_H, BAND = 330.0, 320.0, 25.0
NEW_SX, NEW_SY = BED_W * 1.2, BED_H * 1.2
OFF_X, OFF_Y = (BED_W - 256) / 2.0, (BED_H - 256) / 2.0

def load_machine(path):
    """Imposta la geometria di destinazione dal profilo macchina (già appiattito)."""
    global MACHINE, BED_W, BED_H, BAND, NEW_SX, NEW_SY, OFF_X, OFF_Y
    MACHINE = path
    mach = json.load(open(path))
    area = mach.get("printable_area") or []
    try:
        xs = [float(p.split("x")[0]) for p in area]
        ys = [float(p.split("x")[1]) for p in area]
        if xs and ys:
            BED_W, BED_H = max(xs), max(ys)
    except (ValueError, IndexError):
        pass
    # fasce laterali riservate: esistono solo sulle macchine a doppio ugello
    BAND = 25.0 if mach.get("extruder_printable_area") else 0.0
    NEW_SX, NEW_SY = BED_W * 1.2, BED_H * 1.2
    OFF_X, OFF_Y = max((BED_W - 256) / 2.0, 0.0), max((BED_H - 256) / 2.0, 0.0)

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

def patch_settings(raw):
    cfg = json.loads(raw)
    mach = json.load(open(MACHINE))
    for k in ("printer_model", "printer_settings_id", "printable_area",
              "printable_height", "extruder_printable_area",
              "extruder_printable_height", "printer_variant",
              "master_extruder_id", "physical_extruder_map",
              "extruder_offset"):
        if k in mach:
            cfg[k] = mach[k]
    # La prime tower viene stampata da tutti gli ugelli: traslata come gli
    # oggetti e tenuta nell'area raggiungibile, altrimenti il controllo del
    # G-code boccia il piatto ("found gcode unprintable").
    tower_w = 60.0
    x_lo, x_hi = BAND + 1, max(BAND + 2, BED_W - BAND - tower_w - 2)
    y_lo, y_hi = 5.0, max(10.0, BED_H - 65.0)
    def shift(key, off, lo, hi):
        v = cfg.get(key)
        clamp = lambda x: f"{min(max(float(x) + off, lo), hi):g}"
        if isinstance(v, list):
            cfg[key] = [clamp(x) for x in v]
        elif v is not None:
            cfg[key] = clamp(v)
    shift("wipe_tower_x", OFF_X, x_lo, x_hi)
    shift("wipe_tower_y", OFF_Y, y_lo, y_hi)
    return json.dumps(cfg, indent=4)

def main(src, dst, machine=None):
    if machine:
        load_machine(machine)
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
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
