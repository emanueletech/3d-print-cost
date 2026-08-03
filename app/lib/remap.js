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
const NEW_SX = 330 * 1.2;
const NEW_SY = 320 * 1.2;
const OFF_X = (330 - 256) / 2;
const OFF_Y = (320 - 256) / 2;
const MARGIN = 40; // gli oggetti possono sporgere un po' dal loro piatto

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

function remapModel(xml) {
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
      vals[9] = (cx * NEW_SX + OFF_X + lx).toFixed(6);
      vals[10] = (-(cy * NEW_SY) + OFF_Y + ly).toFixed(6);
      return `${head}transform="${vals.join(' ')}"`;
    });
  return xml.slice(0, start) + build + xml.slice(end);
}

function patchSettings(raw, machineProfile) {
  const cfg = JSON.parse(raw);
  const mach = JSON.parse(fs.readFileSync(machineProfile, 'utf8'));
  for (const k of MACHINE_KEYS) if (k in mach) cfg[k] = mach[k];
  // La prime tower viene stampata da entrambi gli ugelli: traslata come gli
  // oggetti e tenuta fuori dalle bande laterali da 25 mm, altrimenti il
  // controllo del G-code boccia il piatto ("found gcode unprintable").
  const shift = (key, off, lo, hi) => {
    const clamp = (x) => String(Math.round(Math.min(Math.max(parseFloat(x) + off, lo), hi) * 1000) / 1000);
    if (Array.isArray(cfg[key])) cfg[key] = cfg[key].map(clamp);
    else if (cfg[key] != null) cfg[key] = clamp(cfg[key]);
  };
  shift('wipe_tower_x', OFF_X, 26, 244); // 330 - 25 di banda - 60 di torre
  shift('wipe_tower_y', OFF_Y, 5, 255);
  return JSON.stringify(cfg, null, 4);
}

/**
 * Scrive in `dst` la copia rimappata di `src`.
 * @returns true se il rimappaggio è riuscito.
 */
function remap(src, dst, profilesDir) {
  try {
    const entries = zip.list(src);
    if (!entries.length) return false;
    const raw = zip.readMany(
      src,
      entries.map((e) => e.name)
    );
    if (!raw[ENTRY_MODEL] || !raw[ENTRY_SETTINGS]) return false;

    const machine = path.join(profilesDir, 'machine_H2C_04.json');
    raw[ENTRY_MODEL] = Buffer.from(remapModel(raw[ENTRY_MODEL].toString('utf8')), 'utf8');
    raw[ENTRY_SETTINGS] = Buffer.from(
      patchSettings(raw[ENTRY_SETTINGS].toString('utf8'), machine),
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
