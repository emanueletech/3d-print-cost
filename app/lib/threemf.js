'use strict';
/*
 * Lettura dei progetti .3mf slicati (Bambu Studio / OrcaSlicer).
 * Stessa logica dell'app macOS (Slicer.analyze), ma senza /usr/bin/unzip.
 */
const zip = require('./zip');

const ENTRY_SLICE = 'Metadata/slice_info.config';
const ENTRY_PROJECT = 'Metadata/project_settings.config';
const ENTRY_MODEL = 'Metadata/model_settings.config';

function matchAll(re, text) {
  return text ? [...text.matchAll(re)] : [];
}

/** Colori/tipi per slot e slot reale di ogni oggetto (serve a correggere il colore). */
function parseProject(file) {
  const raw = zip.readMany(file, [ENTRY_PROJECT, ENTRY_MODEL]);
  let slotColors = [];
  let slotTypes = [];
  let slotKinds = [];
  let printer = '';
  const psRaw = raw[ENTRY_PROJECT];
  if (psRaw) {
    try {
      const cfg = JSON.parse(psRaw.toString('utf8'));
      slotColors = (cfg.filament_colour || []).map((c) => String(c).toUpperCase());
      slotTypes = (cfg.filament_settings_id || []).map((s) =>
        /matte/i.test(String(s)) ? 'PLA Matte' : 'PLA Basic'
      );
      // tipo materiale per slot (PLA/PETG/TPU…): guida la scelta dei profili (v1.2 M5)
      slotKinds = (cfg.filament_type || []).map((s) => String(s).toUpperCase());
      printer = cfg.printer_model || '';
    } catch {
      /* project_settings illeggibile: si prosegue con i dati del solo slice_info */
    }
  }

  const objSlot = {};
  const msRaw = raw[ENTRY_MODEL];
  if (msRaw) {
    const ms = msRaw.toString('utf8');
    for (const om of matchAll(/<object id="(\d+)">([\s\S]*?)<\/object>/g, ms)) {
      const name = /name" value="([^"]+)"/.exec(om[2]);
      const ext = /extruder" value="(\d+)"/.exec(om[2]);
      if (name) objSlot[name[1]] = ext ? +ext[1] : 1;
    }
  }
  return { slotColors, slotTypes, slotKinds, objSlot, printer };
}

/**
 * Analizza un .3mf già slicato.
 * → { plates:[{index,seconds,grams,colorGrams}], seconds, grams, perColor, printer }
 * → { error: 'not3mf' | 'notSliced' }
 */
function analyze(file) {
  const xmlBuf = zip.read(file, ENTRY_SLICE);
  if (!xmlBuf) {
    // se il file non è nemmeno uno zip leggibile è un 3mf non valido
    return { error: zip.list(file).length ? 'notSliced' : 'not3mf' };
  }
  const xml = xmlBuf.toString('utf8');
  const proj = parseProject(file);

  const plates = [];
  const perColor = {};
  let seconds = 0;
  let grams = 0;

  for (const pm of matchAll(/<plate>([\s\S]*?)<\/plate>/g, xml)) {
    const body = pm[1];
    const pred = /key="prediction" value="(\d+)"/.exec(body);
    if (!pred) continue;
    const secs = +pred[1];

    // il filamento id=1 dentro il piatto è relativo all'oggetto: va riportato
    // allo slot reale dell'estrusore, altrimenti i colori si mescolano
    const objs = matchAll(/object identify_id="\d+" name="([^"]+)"/g, body).map((x) => x[1]);
    const trueSlot = objs.length && proj.objSlot[objs[0]] != null ? proj.objSlot[objs[0]] : 1;

    const colorGrams = {};
    let plateGrams = 0;
    for (const f of matchAll(/filament id="(\d+)"[^/]*?color="([^"]+)"[^/]*?used_g="([^"]+)"/g, body)) {
      const rawSlot = +f[1] || 1;
      const slot = rawSlot === 1 ? trueSlot : rawSlot;
      const hex = proj.slotColors[slot - 1] || String(f[2]).toUpperCase();
      const type = proj.slotTypes[slot - 1] || 'PLA Basic';
      const g = parseFloat(f[3]) || 0;
      const key = `${hex}|${type}`;
      colorGrams[key] = (colorGrams[key] || 0) + g;
      perColor[key] = (perColor[key] || 0) + g;
      plateGrams += g;
      grams += g;
    }

    seconds += secs;
    // l'indice reale del piatto sta nel file: un export con il solo piatto 5
    // deve restare "piatto 5", non diventare il piatto 1
    const idx = /key="index" value="(\d+)"/.exec(body);
    plates.push({
      index: idx ? +idx[1] : plates.length + 1,
      seconds: secs,
      grams: plateGrams,
      colorGrams,
      objects: objs,
    });
  }

  if (!plates.length) return { error: 'notSliced', printer: proj.printer };
  return { plates, seconds, grams, perColor, printer: proj.printer };
}

/** Anteprime dei piatti (Metadata/plate_N.png) come data URL, in ordine di piatto. */
function thumbnails(file) {
  const num = (n) => parseInt(n.replace(/^Metadata\/plate_/, '').replace(/\.png$/, ''), 10) || 0;
  const names = zip
    .list(file)
    .map((e) => e.name)
    .filter((n) => /^Metadata\/plate_\d+\.png$/.test(n))
    .sort((a, b) => num(a) - num(b));
  const data = zip.readMany(file, names);
  return names
    .filter((n) => data[n] && data[n].length)
    .map((n) => `data:image/png;base64,${data[n].toString('base64')}`);
}

module.exports = { analyze, parseProject, thumbnails, ENTRY_PROJECT, ENTRY_MODEL, ENTRY_SLICE };
