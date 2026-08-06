'use strict';
/*
 * Riposiziona gli oggetti di un .3mf dalla griglia piatti P1S (256×256) a quella
 * H2C (330×320) e allinea il profilo macchina, così Bambu Studio riesce a slicare
 * progetti nati per un'altra stampante.
 *
 * Porting JavaScript di resources/remap.py: su Windows non si può dare per
 * scontato un interprete Python installato.
 */
const fs = require('fs');
const path = require('path');
const zip = require('./zip');

const OLD_SX = 256 * 1.2;
const OLD_SY = 256 * 1.2;
const MARGIN = 40; // gli oggetti possono sporgere un po' dal loro piatto

/** Geometria di destinazione dal profilo macchina (v1.2): letto, griglia, fasce. */
function targetGeometry(machineJson) {
  let W = 330;
  let H = 320;
  let band = 25;
  try {
    const area = machineJson.printable_area || [];
    const xs = area.map((p) => parseFloat(String(p).split('x')[0])).filter((n) => !Number.isNaN(n));
    const ys = area.map((p) => parseFloat(String(p).split('x')[1])).filter((n) => !Number.isNaN(n));
    if (xs.length && ys.length) {
      W = Math.max(...xs);
      H = Math.max(...ys);
    }
    // fasce laterali riservate: solo sulle macchine a doppio ugello
    band = machineJson.extruder_printable_area ? 25 : 0;
  } catch {
    /* geometria di ripiego H2C */
  }
  return {
    W, H, band,
    SX: W * 1.2, SY: H * 1.2,
    OFF_X: Math.max((W - 256) / 2, 0),
    OFF_Y: Math.max((H - 256) / 2, 0),
  };
}

const ENTRY_MODEL = '3D/3dmodel.model';
const ENTRY_SETTINGS = 'Metadata/project_settings.config';

const MACHINE_KEYS = [
  'printer_model',
  'printer_settings_id',
  'printable_area',
  'printable_height',
  'extruder_printable_area',
  'extruder_printable_height',
  'printer_variant',
  'master_extruder_id',
  'physical_extruder_map',
  'extruder_offset',
];

/** Cella della griglia la cui coordinata locale cade in [-MARGIN, 256+MARGIN]. */
function cell(v, stride, sign = 1) {
  let best = null;
  let bestLoc = null;
  for (let i = 0; i < 8; i++) {
    const loc = v - sign * i * stride;
    if (loc >= -MARGIN && loc <= 256 + MARGIN) {
      if (best === null || Math.abs(loc - 128) < Math.abs(bestLoc - 128)) {
        best = i;
        bestLoc = loc;
      }
    }
  }
  if (best === null) throw new Error(`nessuna cella della griglia per ${v}`);
  return [best, bestLoc];
}

function remapModel(xml, geo) {
  const start = xml.indexOf('<build');
  const end = xml.indexOf('</build>');
  if (start < 0 || end < 0 || end < start) throw new Error('sezione <build> assente');

  // solo le transform degli <item> dentro <build>: quelle dei componenti
  // descrivono la geometria e vanno lasciate stare
  const build = xml
    .slice(start, end)
    .replace(/(<item [^>]*?)transform="([^"]+)"/g, (_m, head, transform) => {
      const vals = transform.trim().split(/\s+/);
      const [cx, lx] = cell(parseFloat(vals[9]), OLD_SX);
      const [cy, ly] = cell(parseFloat(vals[10]), OLD_SY, -1);
      vals[9] = (cx * geo.SX + geo.OFF_X + lx).toFixed(6);
      vals[10] = (-(cy * geo.SY) + geo.OFF_Y + ly).toFixed(6);
      return `${head}transform="${vals.join(' ')}"`;
    });
  return xml.slice(0, start) + build + xml.slice(end);
}

function patchSettings(raw, machineProfile, geo) {
  const cfg = JSON.parse(raw);
  const mach = JSON.parse(fs.readFileSync(machineProfile, 'utf8'));
  for (const k of MACHINE_KEYS) if (k in mach) cfg[k] = mach[k];
  // La prime tower viene stampata da tutti gli ugelli: traslata come gli
  // oggetti e tenuta nell'area raggiungibile, altrimenti il controllo del
  // G-code boccia il piatto ("found gcode unprintable").
  const towerW = 60;
  const xLo = geo.band + 1;
  const xHi = Math.max(geo.band + 2, geo.W - geo.band - towerW - 2);
  const yLo = 5;
  const yHi = Math.max(10, geo.H - 65);
  const shift = (key, off, lo, hi) => {
    const clamp = (x) => String(Math.round(Math.min(Math.max(parseFloat(x) + off, lo), hi) * 1000) / 1000);
    if (Array.isArray(cfg[key])) cfg[key] = cfg[key].map(clamp);
    else if (cfg[key] != null) cfg[key] = clamp(cfg[key]);
  };
  shift('wipe_tower_x', geo.OFF_X, xLo, xHi);
  shift('wipe_tower_y', geo.OFF_Y, yLo, yHi);
  return JSON.stringify(cfg, null, 4);
}

/**
 * Scrive in `dst` la copia rimappata di `src`.
 * `machinePath` (v1.2): profilo macchina di destinazione già appiattito;
 * senza, si usa l'H2C in bundle come sempre.
 * @returns true se il rimappaggio è riuscito.
 */
function remap(src, dst, profilesDir, machinePath) {
  try {
    const entries = zip.list(src);
    if (!entries.length) return false;
    const raw = zip.readMany(
      src,
      entries.map((e) => e.name)
    );
    if (!raw[ENTRY_MODEL] || !raw[ENTRY_SETTINGS]) return false;

    const machine = machinePath || path.join(profilesDir, 'machine_H2C_04.json');
    const geo = targetGeometry(JSON.parse(fs.readFileSync(machine, 'utf8')));
    raw[ENTRY_MODEL] = Buffer.from(remapModel(raw[ENTRY_MODEL].toString('utf8'), geo), 'utf8');
    raw[ENTRY_SETTINGS] = Buffer.from(
      patchSettings(raw[ENTRY_SETTINGS].toString('utf8'), machine, geo),
      'utf8'
    );

    zip.write(
      dst,
      entries.filter((e) => raw[e.name]).map((e) => ({ name: e.name, data: raw[e.name] }))
    );
    return fs.existsSync(dst);
  } catch {
    return false; // rimappaggio non applicabile: il chiamante riporta lo slicing fallito
  }
}

module.exports = { remap };
