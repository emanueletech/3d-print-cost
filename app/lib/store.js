'use strict';
/*
 * Database persistente (materiali, stampanti, parametri di costo) e costanti
 * dell'autore. Stessi dati e stessi default dell'app macOS: chi usa entrambe
 * ritrova la stessa app.
 */
const fs = require('fs');
const path = require('path');

/* ---------- autore & social ---------- */

const Author = {
  name: 'Emanuele',
  instagram: 'https://www.instagram.com/emanuele_tech',
  telegram: 'https://t.me/emanueletech',
  makerworld: 'https://makerworld.com/en/@Emanuele_tech',
  youtube: 'https://youtube.com/@emanuele_tech',
  tiktok: 'https://www.tiktok.com/@emanuele_tech',
  linktree: 'https://linktr.ee/emanuele_tech',
  // bot che verifica l'iscrizione al canale e rimanda il token di sblocco
  telegramBot: 'https://t.me/emanueletech_bot?start=unlock',
  // chiave PUBBLICA Ed25519 (hex) che verifica i token firmati dal bot.
  // La chiave privata sta solo sul server del bot: vedi native/BOT_UNLOCK.md.
  unlockPublicKey: 'a40ab23d9a295c5809dc7cfd926dce85abeee3aa435cec04bd75871769abcaff',
  allowHonorUnlock: true,
  urlScheme: 'printcost',
};

/** tag affiliato incorporato e bloccato (app dell'autore) */
const DEFAULT_AMAZON_TAG = 'emanueleesp-21';

function amazonSearch(query, tag = DEFAULT_AMAZON_TAG) {
  const u = new URL('https://www.amazon.it/s');
  u.searchParams.set('k', query);
  if (tag && tag.trim()) u.searchParams.set('tag', tag.trim());
  return u.toString();
}

/* ---------- default ---------- */

const mat = (name, type, colorHex, costPerKg, densityGcm3 = 1.24) => ({
  name,
  type,
  colorHex,
  costPerKg,
  densityGcm3,
  stockKg: null,
  salePrice: null,
});

function defaultMaterials() {
  return [
    mat('Latte Brown', 'PLA Matte', '#D3B7A7', 22.99),
    mat('Nardo Gray', 'PLA Matte', '#757575', 22.99),
    mat('Ivory White', 'PLA Matte', '#FFFFFF', 22.99),
    mat('Scarlet Red', 'PLA Matte', '#DE4343', 22.99),
    mat('Charcoal', 'PLA Matte', '#000000', 22.99),
    mat('Jade White', 'PLA Basic', '#FFFFFF', 22.99),
    mat('Black', 'PLA Basic', '#000000', 22.99),
    mat('Red', 'PLA Basic', '#C12E1F', 22.99),
    mat('Cobalt Blue', 'PLA Basic', '#0056B8', 22.99),
    mat('Gold', 'PLA Basic', '#E4BD68', 22.99),
    mat('Cocoa Brown', 'PLA Basic', '#6F5034', 22.99),
    mat('Sunflower Yellow', 'PLA Basic', '#FEC600', 22.99),
    mat('Purple', 'PLA Basic', '#5E43B7', 22.99),
    mat('Mistletoe Green', 'PLA Basic', '#3F8E43', 22.99),
    mat('Pink', 'PLA Basic', '#F55A74', 22.99),
  ];
}

// usura oraria stimata = prezzo macchina / vita utile in ore
function defaultPrinters() {
  const p = (name, watts, wearPerHour, setupCost = 0.15) => ({ name, watts, wearPerHour, setupCost });
  return [
    p('Bambu Lab H2C', 180, 0.12),
    p('Bambu Lab H2D', 180, 0.14),
    p('Bambu Lab H2D Pro', 200, 0.16),
    p('Bambu Lab H2S', 160, 0.11),
    p('Bambu Lab X1C', 110, 0.1),
    p('Bambu Lab P1S', 105, 0.06),
    p('Bambu Lab A1', 80, 0.04),
    p('Snapmaker U1', 150, 0.1), // tool-changer multicolore; media PLA ~150 W (picco 1150 W)
    p('Altra', 120, 0.08),
  ];
}

/* ---------- preset materiali per marca ---------- */

const BAMBU_BASIC = {
  '#FFFFFF': 'Jade White', '#000000': 'Black', '#C12E1F': 'Red', '#0A2989': 'Blue',
  '#8E9089': 'Gray', '#00AE42': 'Bambu Green', '#3F8E43': 'Mistletoe Green', '#0086D6': 'Cyan',
  '#FEC600': 'Sunflower Yellow', '#482960': 'Indigo Purple', '#6F5034': 'Cocoa Brown',
  '#F5547C': 'Hot Pink', '#FF9016': 'Pumpkin Orange', '#E4BD68': 'Gold', '#5E43B7': 'Purple',
  '#0056B8': 'Cobalt Blue', '#F55A74': 'Pink', '#D3B7A7': 'Beige',
};

const BAMBU_MATTE = {
  '#FFFFFF': 'Ivory White', '#CBC6B8': 'Bone White', '#E8DBB7': 'Desert Tan',
  '#D3B7A7': 'Latte Brown', '#AE835B': 'Caramel', '#B15533': 'Terracotta',
  '#7D6556': 'Dark Brown', '#4D3324': 'Dark Chocolate', '#AE96D4': 'Lilac Purple',
  '#E8AFCF': 'Sakura Pink', '#F99963': 'Mandarin Orange', '#F7D959': 'Lemon Yellow',
  '#950051': 'Plum', '#DE4343': 'Scarlet Red', '#BB3D43': 'Dark Red', '#68724D': 'Dark Green',
  '#61C680': 'Grass Green', '#C2E189': 'Apple Green', '#A3D8E1': 'Ice Blue',
  '#56B7E6': 'Sky Blue', '#0078BF': 'Marine Blue', '#042F56': 'Dark Blue',
  '#9B9EA0': 'Ash Gray', '#757575': 'Nardo Gray', '#000000': 'Charcoal',
};

const presetBrandOrder = ['Bambu Lab', 'eSun', 'Generico'];

function presets() {
  const out = [];
  const push = (brand, type, colorName, hex, costPerKg, density) =>
    out.push({ brand, type, colorName, hex, costPerKg, density });

  const byName = (dict) => Object.entries(dict).sort((a, b) => a[1].localeCompare(b[1]));
  for (const [hex, name] of byName(BAMBU_BASIC)) push('Bambu Lab', 'PLA Basic', name, hex, 22.99, 1.24);
  for (const [hex, name] of byName(BAMBU_MATTE)) push('Bambu Lab', 'PLA Matte', name, hex, 22.99, 1.24);
  push('Bambu Lab', 'PETG HF', 'Nero', '#000000', 22.99, 1.27);
  push('Bambu Lab', 'ABS', 'Nero', '#000000', 22.99, 1.04);
  push('Bambu Lab', 'ASA', 'Nero', '#000000', 24.99, 1.07);
  push('Bambu Lab', 'PLA Silk', 'Oro', '#E4BD68', 29.99, 1.24);
  push('Bambu Lab', 'TPU 95A', 'Nero', '#000000', 34.99, 1.21);

  for (const [name, hex] of [
    ['Nero', '#1A1A1A'], ['Bianco', '#F5F5F5'], ['Grigio', '#808080'],
    ['Rosso', '#C0392B'], ['Blu', '#2049B0'], ['Giallo', '#F2C200'],
  ]) push('eSun', 'PLA+', name, hex, 19.99, 1.24);
  push('eSun', 'PETG', 'Nero', '#1A1A1A', 21.99, 1.27);
  push('eSun', 'ABS+', 'Nero', '#1A1A1A', 20.99, 1.06);

  for (const [type, density] of [
    ['PLA', 1.24], ['PLA Matte', 1.24], ['PETG', 1.27], ['ABS', 1.04],
    ['ASA', 1.07], ['TPU 95A', 1.21], ['Nylon PA', 1.14],
  ]) push('Generico', type, '—', '#8E9089', 20.0, density);

  return out;
}

/* ---------- persistenza ---------- */

const GENERIC_PRINTERS = new Set(['Altra', 'Other', 'Otra', 'Autre', '—']);

let storeFile = null;

function init(userDataDir) {
  storeFile = path.join(userDataDir, 'store.json');
  return storeFile;
}

function emptyState() {
  return {
    materials: defaultMaterials(),
    printers: defaultPrinters(),
    failurePct: 7,
    kwh: 0.209,
    currency: 'eur',
    eurRate: 1.0,
    lang: null,
    unlocked: false,
    bambuPath: '',
    source: 'bambuRefill',
    msrp: 22.99,
    spoolPrice: 25.99,
    otherBrand: 'Generico',
    otherPrice: 20.0,
    selPrinter: null,
  };
}

function load() {
  const base = emptyState();
  if (!storeFile || !fs.existsSync(storeFile)) return base;
  let saved;
  try {
    saved = JSON.parse(fs.readFileSync(storeFile, 'utf8'));
  } catch {
    return base; // file corrotto: si riparte dai default senza bloccare l'avvio
  }
  const s = { ...base, ...saved };
  if (!Array.isArray(s.materials) || !s.materials.length) s.materials = base.materials;
  if (!Array.isArray(s.printers) || !s.printers.length) s.printers = base.printers;

  // migrazione non distruttiva: aggiunge le stampanti predefinite nuove mancanti
  const have = new Set(s.printers.map((p) => p.name));
  for (const p of defaultPrinters()) if (!have.has(p.name)) s.printers.push(p);
  // la voce generica resta sempre in fondo alla lista
  s.printers = [
    ...s.printers.filter((p) => !GENERIC_PRINTERS.has(p.name)),
    ...s.printers.filter((p) => GENERIC_PRINTERS.has(p.name)),
  ];
  return s;
}

function save(state) {
  if (!storeFile) return false;
  try {
    fs.mkdirSync(path.dirname(storeFile), { recursive: true });
    fs.writeFileSync(storeFile, JSON.stringify(state, null, 2), 'utf8');
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  Author,
  DEFAULT_AMAZON_TAG,
  amazonSearch,
  defaultMaterials,
  defaultPrinters,
  presets,
  presetBrandOrder,
  init,
  load,
  save,
  emptyState,
};
