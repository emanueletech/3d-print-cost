'use strict';
/*
 * Test di sanità delle parti che su Windows sostituiscono unzip/python:
 * lettura-scrittura zip, parsing 3mf, rimappaggio, sblocco HMAC, mesh.
 * Si eseguono con `npm test` (solo Node, niente Electron).
 */
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const zip = require('../lib/zip');
const threemf = require('../lib/threemf');
const { remap } = require('../lib/remap');
const unlock = require('../lib/unlock');
const store = require('../lib/store');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'printcost-test-'));
const profiles = path.join(__dirname, '..', 'resources', 'profiles');
let passed = 0;

function check(name, fn) {
  fn();
  passed++;
  console.log(`  ✓ ${name}`);
}

/* ---------- materiale di prova ---------- */

const SLICE_INFO = `<?xml version="1.0" encoding="UTF-8"?>
<config>
  <header><header_item key="X-BBL-Client-Type" value="slicer"/></header>
  <plate>
    <metadata key="index" value="1"/>
    <metadata key="prediction" value="3600"/>
    <metadata key="weight" value="16.00"/>
    <object identify_id="101" name="pezzo.stl" skipped="false"/>
    <filament id="1" tray_info_idx="GFA00" type="PLA" color="#FFFFFF" used_m="3.52" used_g="10.5"/>
    <filament id="2" tray_info_idx="GFA01" type="PLA" color="#00AE42" used_m="1.84" used_g="5.5"/>
  </plate>
  <plate>
    <metadata key="index" value="2"/>
    <metadata key="prediction" value="7200"/>
    <metadata key="weight" value="20.00"/>
    <object identify_id="102" name="altro.stl" skipped="false"/>
    <filament id="1" tray_info_idx="GFA00" type="PLA" color="#C12E1F" used_m="6.70" used_g="20"/>
  </plate>
</config>`;

const PROJECT_SETTINGS = JSON.stringify({
  filament_colour: ['#FFFFFF', '#000000'],
  filament_settings_id: ['Bambu PLA Basic @BBL H2C', 'Bambu PLA Matte @BBL H2C'],
  printer_model: 'Bambu Lab H2C',
});

const MODEL_SETTINGS = `<?xml version="1.0" encoding="UTF-8"?>
<config>
  <object id="1">
    <metadata key="name" value="pezzo.stl"/>
    <metadata key="extruder" value="2"/>
  </object>
  <object id="2">
    <metadata key="name" value="altro.stl"/>
    <metadata key="extruder" value="1"/>
  </object>
</config>`;

const MODEL_3D = `<?xml version="1.0" encoding="UTF-8"?>
<model unit="millimeter"><resources><object id="1" type="model"/></resources>
<build><item objectid="1" transform="1 0 0 0 1 0 0 0 1 128 128 0" printable="1"/></build></model>`;

// PNG 1×1 valido, per l'estrazione delle anteprime dei piatti
const PNG_1PX = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

const sample = path.join(tmp, 'progetto.3mf');
zip.write(sample, [
  { name: '3D/3dmodel.model', data: Buffer.from(MODEL_3D) },
  { name: 'Metadata/slice_info.config', data: Buffer.from(SLICE_INFO) },
  { name: 'Metadata/project_settings.config', data: Buffer.from(PROJECT_SETTINGS) },
  { name: 'Metadata/model_settings.config', data: Buffer.from(MODEL_SETTINGS) },
  { name: 'Metadata/plate_1.png', data: PNG_1PX },
  { name: 'Metadata/plate_2.png', data: PNG_1PX },
]);

/* ---------- zip ---------- */

console.log('zip');
check('rilegge le voci scritte', () => {
  const names = zip.list(sample).map((e) => e.name);
  assert.ok(names.includes('Metadata/slice_info.config'));
  assert.strictEqual(names.length, 6);
});
check('round-trip del contenuto', () => {
  assert.strictEqual(zip.readText(sample, 'Metadata/slice_info.config'), SLICE_INFO);
  assert.deepStrictEqual(zip.read(sample, 'Metadata/plate_1.png'), PNG_1PX);
});
check('voce inesistente → null', () => {
  assert.strictEqual(zip.read(sample, 'Metadata/assente.txt'), null);
});
check('file non zip → nessuna voce', () => {
  const junk = path.join(tmp, 'junk.3mf');
  fs.writeFileSync(junk, 'questo non è uno zip');
  assert.deepStrictEqual(zip.list(junk), []);
});
check('sopravvive a un file grande e comprimibile', () => {
  const big = path.join(tmp, 'big.zip');
  const data = Buffer.alloc(3 * 1024 * 1024, 'A');
  zip.write(big, [{ name: 'big.bin', data }]);
  assert.strictEqual(zip.read(big, 'big.bin').length, data.length);
});

/* ---------- parsing 3mf ---------- */

console.log('3mf');
check('somma tempi, grammi e piatti', () => {
  const a = threemf.analyze(sample);
  assert.ok(!a.error, a.error);
  assert.strictEqual(a.plates.length, 2);
  assert.strictEqual(a.seconds, 10800);
  assert.strictEqual(a.grams, 36);
  assert.strictEqual(a.printer, 'Bambu Lab H2C');
});
check('il filamento id=1 eredita lo slot reale dell’oggetto', () => {
  const a = threemf.analyze(sample);
  // pezzo.stl usa l'estrusore 2 → tutto il piatto 1 finisce sul nero opaco
  assert.strictEqual(a.perColor['#000000|PLA Matte'], 16);
  // altro.stl usa l'estrusore 1 → bianco lucido
  assert.strictEqual(a.perColor['#FFFFFF|PLA Basic'], 20);
  assert.strictEqual(a.plates[0].colorGrams['#000000|PLA Matte'], 16);
});
check('file non 3mf → not3mf', () => {
  assert.strictEqual(threemf.analyze(path.join(tmp, 'junk.3mf')).error, 'not3mf');
});
check('3mf senza slice_info → notSliced', () => {
  const raw = path.join(tmp, 'nonslicato.3mf');
  zip.write(raw, [{ name: '3D/3dmodel.model', data: Buffer.from(MODEL_3D) }]);
  assert.strictEqual(threemf.analyze(raw).error, 'notSliced');
});
check('anteprime dei piatti in ordine', () => {
  const t = threemf.thumbnails(sample);
  assert.strictEqual(t.length, 2);
  assert.ok(t[0].startsWith('data:image/png;base64,'));
});

/* ---------- rimappaggio griglia (ex remap.py) ---------- */

console.log('remap');
check('sposta gli item sulla griglia H2C', () => {
  const out = path.join(tmp, 'remapped.3mf');
  assert.ok(remap(sample, out, profiles), 'remap fallito');
  const xml = zip.readText(out, '3D/3dmodel.model');
  const vals = /transform="([^"]+)"/.exec(xml)[1].split(' ');
  // 128 → 37 (centratura) + 128 = 165 in X; 32 + 128 = 160 in Y
  assert.strictEqual(vals[9], '165.000000');
  assert.strictEqual(vals[10], '160.000000');
});
check('allinea il profilo macchina al H2C', () => {
  const cfg = JSON.parse(zip.readText(path.join(tmp, 'remapped.3mf'), 'Metadata/project_settings.config'));
  const machine = JSON.parse(fs.readFileSync(path.join(profiles, 'machine_H2C_04.json'), 'utf8'));
  assert.strictEqual(cfg.printer_model, machine.printer_model);
  // i dati non di macchina restano intatti
  assert.deepStrictEqual(cfg.filament_colour, ['#FFFFFF', '#000000']);
});
check('il rimappato resta leggibile come 3mf', () => {
  assert.ok(zip.list(path.join(tmp, 'remapped.3mf')).length >= 6);
});

/* ---------- sblocco ---------- */

console.log('sblocco');
check('accetta il codice della finestra corrente', () => {
  const w = Math.floor(Date.now() / 1000 / unlock.WINDOW);
  assert.ok(unlock.validCode(unlock.windowCode(w)));
  assert.ok(unlock.validCode(unlock.windowCode(w - 2).toLowerCase()), 'finestre precedenti');
});
check('rifiuta codici scaduti o inventati', () => {
  assert.ok(!unlock.validCode(unlock.windowCode(Math.floor(Date.now() / 1000 / unlock.WINDOW) - 5)));
  assert.ok(!unlock.validCode('ABC123'));
  assert.ok(!unlock.validCode(''));
  assert.ok(!unlock.validCode(null));
});
check('valida il token firmato del deep-link', () => {
  const crypto = require('crypto');
  const exp = String(Math.floor(Date.now() / 1000) + 600);
  const mac = crypto.createHmac('sha256', store.Author.unlockSecret).update(exp).digest('hex');
  assert.ok(unlock.validToken(`${exp}.${mac}`));
  assert.ok(unlock.tokenFromURL(`printcost://unlock?t=${exp}.${mac}`));
  assert.strictEqual(unlock.tokenFromURL(`printcost://unlock?t=${exp}.deadbeef`), null);
  assert.strictEqual(unlock.tokenFromURL(`https://esempio.it/unlock?t=${exp}.${mac}`), null);
});
check('rifiuta un token già scaduto', () => {
  const crypto = require('crypto');
  const exp = String(Math.floor(Date.now() / 1000) - 10);
  const mac = crypto.createHmac('sha256', store.Author.unlockSecret).update(exp).digest('hex');
  assert.ok(!unlock.validToken(`${exp}.${mac}`));
});

/* ---------- store ---------- */

console.log('store');
check('salva e ricarica il database', () => {
  store.init(tmp);
  const s = store.load();
  assert.ok(s.materials.length > 10 && s.printers.length > 5);
  s.kwh = 0.31;
  s.materials[0].salePrice = 15;
  store.save(s);
  const back = store.load();
  assert.strictEqual(back.kwh, 0.31);
  assert.strictEqual(back.materials[0].salePrice, 15);
});
check('migrazione: reinserisce le stampanti predefinite mancanti', () => {
  const s = store.load();
  s.printers = s.printers.filter((p) => p.name !== 'Snapmaker U1');
  store.save(s);
  const back = store.load();
  assert.ok(back.printers.some((p) => p.name === 'Snapmaker U1'));
  assert.strictEqual(back.printers[back.printers.length - 1].name, 'Altra', 'la generica resta in fondo');
});
check('store.json corrotto → si riparte dai default', () => {
  fs.writeFileSync(path.join(tmp, 'store.json'), '{rotto');
  assert.strictEqual(store.load().kwh, 0.209);
});
check('i preset materiali coprono tutte le marche', () => {
  const brands = new Set(store.presets().map((p) => p.brand));
  assert.deepStrictEqual([...brands].sort(), ['Bambu Lab', 'Generico', 'eSun']);
});

/* ---------- mesh & pose ---------- */

console.log('mesh');
global.window = {};
require('../renderer/mesh');
const MeshLib = global.window.MeshLib;

/** cubo 20×20×20 chiuso, con le normali rivolte all'esterno come in uno STL valido */
function cubeSTL() {
  const s = 20;
  const v = [
    [0, 0, 0, s, s, 0, s, 0, 0], [0, 0, 0, 0, s, 0, s, s, 0], // base, normale −Z
    [0, 0, s, s, 0, s, s, s, s], [0, 0, s, s, s, s, 0, s, s], // sommità, +Z
    [0, 0, 0, 0, s, s, 0, s, 0], [0, 0, 0, 0, 0, s, 0, s, s], // x=0, −X
    [s, 0, 0, s, s, 0, s, s, s], [s, 0, 0, s, s, s, s, 0, s], // x=s, +X
    [0, 0, 0, s, 0, 0, s, 0, s], [0, 0, 0, s, 0, s, 0, 0, s], // y=0, −Y
    [0, s, 0, s, s, s, s, s, 0], [0, s, 0, 0, s, s, s, s, s], // y=s, +Y
  ].flat();
  return MeshLib.exportSTL(new Float32Array(v));
}

check('legge lo STL binario che scrive', () => {
  const verts = MeshLib.parse(cubeSTL(), 'stl');
  assert.strictEqual(verts.length, 12 * 9);
  const b = MeshLib.bounds(verts, null);
  assert.deepStrictEqual(b.hi, [20, 20, 20]);
  // ogni faccia del cubo guarda verso l'esterno: la normale è opposta al centro
  for (let i = 0; i < verts.length; i += 9) {
    const g = MeshLib.faceGeometry(verts, i);
    const cx = (verts[i] + verts[i + 3] + verts[i + 6]) / 3 - 10;
    const cy = (verts[i + 1] + verts[i + 4] + verts[i + 7]) / 3 - 10;
    const cz = (verts[i + 2] + verts[i + 5] + verts[i + 8]) / 3 - 10;
    assert.ok(g.nx * cx + g.ny * cy + g.nz * cz > 0, `faccia ${i / 9} rivolta all'interno`);
  }
});
check('legge un OBJ con facce quadrate', () => {
  const obj = 'v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n';
  const verts = MeshLib.parse(new TextEncoder().encode(obj).buffer, 'obj');
  assert.strictEqual(verts.length, 18, 'il quadrato diventa due triangoli');
});
check('appoggia il modello al piatto', () => {
  const verts = MeshLib.parse(cubeSTL(), 'stl');
  const placed = MeshLib.place(verts, null);
  const b = MeshLib.bounds(placed, null);
  assert.strictEqual(b.lo[2], 0, 'z minima a zero');
  assert.ok(Math.abs(b.lo[0] + b.hi[0]) < 1e-4, 'centrato in X');
});
check('un cubo non ha superfici da supportare', () => {
  const poses = MeshLib.candidates(MeshLib.parse(cubeSTL(), 'stl'), 45);
  assert.strictEqual(poses.length, 7);
  assert.ok(poses.every((p) => p.supportArea < 1e-3));
  assert.ok(poses.every((p) => Math.abs(p.height - 20) < 1e-3));
});
check('una tettoia in sbalzo richiede supporti', () => {
  // pensilina 20×20 rivolta in giù a quota 10, tenuta su da un pilastrino
  const roof = [
    [0, 0, 10, 20, 20, 10, 20, 0, 10],
    [0, 0, 10, 0, 20, 10, 20, 20, 10],
  ].flat();
  const post = [0, 0, 0, 0, 0, 10, 1, 0, 10]; // verticale: né appoggio né sbalzo
  const verts = MeshLib.parse(MeshLib.exportSTL(new Float32Array([...roof, ...post])), 'stl');
  const stats = MeshLib.poseStats(verts, 'orig', MeshLib.IDENTITY.slice(), 45);
  assert.ok(Math.abs(stats.supportArea - 400) < 1e-3, `attesi 400 mm², trovati ${stats.supportArea}`);

  // la stessa superficie appoggiata al piatto non è uno sbalzo, è il contatto
  const onBed = MeshLib.poseStats(new Float32Array(roof), 'orig', MeshLib.IDENTITY.slice(), 45);
  assert.strictEqual(onBed.supportArea, 0);
  assert.ok(Math.abs(onBed.contactArea - 400) < 1e-3);
});

fs.rmSync(tmp, { recursive: true, force: true });
console.log(`\n${passed} test superati.`);
