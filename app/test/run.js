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
check('lo slot non-PLA porta il suo materiale vero nei costi', () => {
  // progetto con slot 2 in ABS: l'etichetta tipo deve dire ABS, non PLA Basic
  const abs3mf = path.join(tmp, 'con-abs.3mf');
  zip.write(abs3mf, [
    { name: '3D/3dmodel.model', data: Buffer.from(MODEL_3D) },
    { name: 'Metadata/project_settings.config', data: Buffer.from(JSON.stringify({
      filament_colour: ['#FFFFFF', '#000000'],
      filament_settings_id: ['Bambu PLA Matte @BBL H2C', 'Bambu ABS @BBL H2C'],
      filament_type: ['PLA', 'ABS'],
    })) },
  ]);
  const p = threemf.parseProject(abs3mf);
  assert.deepStrictEqual(p.slotKinds, ['PLA', 'ABS']);
  assert.deepStrictEqual(p.slotTypes, ['PLA Matte', 'ABS']);
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

/* ---------- sblocco (firma Ed25519: il bot firma, l'app verifica) ---------- */

console.log('sblocco');
const crypto = require('crypto');
// coppia usa-e-getta: il test fa la parte del bot con la privata,
// l'app verifica con la sola pubblica (iniettata al posto di quella vera)
const botKeys = crypto.generateKeyPairSync('ed25519');
const realPublicKey = store.Author.unlockPublicKey;
store.Author.unlockPublicKey = botKeys.publicKey
  .export({ format: 'der', type: 'spki' }).subarray(-32).toString('hex');
const signToken = (exp) =>
  `${exp}.${crypto.sign(null, Buffer.from(`printcost:unlock:${exp}`), botKeys.privateKey).toString('hex')}`;

check('accetta un token firmato valido, anche incollato come codice', () => {
  const t = signToken(Math.floor(Date.now() / 1000) + 600);
  assert.ok(unlock.validToken(t));
  assert.ok(unlock.validCode(`  ${t}  `), 'con spazi attorno (incollato)');
  assert.ok(unlock.tokenFromURL(`printcost://unlock?t=${t}`));
  assert.strictEqual(unlock.tokenFromURL(`https://esempio.it/unlock?t=${t}`), null, 'schema sbagliato');
});
check('rifiuta token scaduti o manomessi', () => {
  assert.ok(!unlock.validToken(signToken(Math.floor(Date.now() / 1000) - 10)), 'scaduto');
  const t = signToken(Math.floor(Date.now() / 1000) + 600);
  const [exp, sig] = t.split('.');
  assert.ok(!unlock.validToken(`${+exp + 1}.${sig}`), 'scadenza alterata');
  assert.ok(!unlock.validToken(`${exp}.${sig.replace(/^../, sig[0] === 'a' ? 'bb' : 'aa')}`), 'firma alterata');
  assert.ok(!unlock.validCode('ABC123'));
  assert.ok(!unlock.validCode(''));
  assert.ok(!unlock.validCode(null));
});
check('una chiave privata diversa non sblocca', () => {
  const intruder = crypto.generateKeyPairSync('ed25519');
  const exp = Math.floor(Date.now() / 1000) + 600;
  const sig = crypto.sign(null, Buffer.from(`printcost:unlock:${exp}`), intruder.privateKey).toString('hex');
  assert.ok(!unlock.validToken(`${exp}.${sig}`));
});
check('la chiave pubblica di produzione è un hex Ed25519 plausibile', () => {
  assert.match(realPublicKey, /^[0-9a-f]{64}$/);
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
check('registro costi: nasce vuoto e sopravvive a uno store vecchio', () => {
  assert.deepStrictEqual(store.emptyState().history, []);
  // store salvato prima della v1.3, senza campo history → reintegrato vuoto
  const s = store.load();
  delete s.history;
  store.save(s);
  assert.deepStrictEqual(store.load().history, []);
  // una voce salvata resta
  const s2 = store.load();
  s2.history.unshift({ date: '2026-08-14T10:00:00Z', name: 'test', printer: 'X', plates: 1, grams: 10, seconds: 60, material: 0.2, energy: 0.01, wear: 0, setup: 0.15, failure: 0, total: 0.36 });
  store.save(s2);
  assert.strictEqual(store.load().history.length, 1);
});
check('preventivo: default sensati e campi nuovi reintegrati', () => {
  const q = store.emptyState().quote;
  assert.strictEqual(q.mode, 'pct');
  assert.strictEqual(q.pct, 30);
  // store vecchio con un quote parziale → i campi mancanti tornano dai default
  const s = store.load();
  s.quote = { biz: 'Officina 3D' };
  store.save(s);
  const back = store.load().quote;
  assert.strictEqual(back.biz, 'Officina 3D');
  assert.strictEqual(back.validity, 30);
  assert.strictEqual(back.detail, true);
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

/* ---------- profili per stampante (v1.2): appiattimento inherits ---------- */

console.log('profili');
const slicer = require('../lib/slicer');
check('appiattisce la catena inherits e il figlio vince', () => {
  const dir = path.join(tmp, 'presets');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'base comune.json'), JSON.stringify({
    name: 'base comune', layer_height: '0.2', wall_loops: '2', ooze_prevention: '1',
  }));
  fs.writeFileSync(path.join(dir, 'medio.json'), JSON.stringify({
    name: 'medio', inherits: 'base comune', wall_loops: '3',
  }));
  fs.writeFileSync(path.join(dir, 'foglia @BBL X1C.json'), JSON.stringify({
    name: 'foglia @BBL X1C', inherits: 'medio', printable_area: ['0x0', '256x0', '256x256', '0x256'],
  }));
  const flat = slicer.flattenPreset(dir, 'foglia @BBL X1C', tmp);
  assert.ok(flat, 'appiattimento riuscito');
  const obj = JSON.parse(fs.readFileSync(flat, 'utf8'));
  assert.strictEqual(obj.inherits, undefined, 'inherits rimosso');
  assert.strictEqual(obj.wall_loops, '3', 'il figlio intermedio vince sulla base');
  assert.strictEqual(obj.layer_height, '0.2', 'i valori della base sopravvivono');
  assert.strictEqual(obj.name, 'foglia @BBL X1C', 'il nome resta quello della foglia');
  assert.ok(Array.isArray(obj.printable_area), 'i campi della foglia ci sono');
});
check('catena inherits interrotta → null, senza eccezioni', () => {
  const dir = path.join(tmp, 'presets');
  fs.writeFileSync(path.join(dir, 'orfano.json'), JSON.stringify({ name: 'orfano', inherits: 'inesistente' }));
  assert.strictEqual(slicer.flattenPreset(dir, 'orfano', tmp), null);
  assert.strictEqual(slicer.flattenPreset(dir, 'mai-esistito', tmp), null);
});
check('profili filamento per tipo: ABS/ASA/PC risolti, il dedicato vince sul generico', () => {
  // albero profili finto: per ABS c'è il profilo della stampante, per ASA solo il generico
  const root = path.join(tmp, 'bbl-fake');
  const fdir = path.join(root, 'filament');
  fs.mkdirSync(fdir, { recursive: true });
  fs.writeFileSync(path.join(fdir, 'Bambu ABS @BBL H2C.json'), JSON.stringify({ name: 'Bambu ABS @BBL H2C' }));
  fs.writeFileSync(path.join(fdir, 'Generic ABS @base.json'), JSON.stringify({ name: 'Generic ABS @base' }));
  fs.writeFileSync(path.join(fdir, 'Generic ASA @base.json'), JSON.stringify({ name: 'Generic ASA @base' }));
  const r = { code: 'H2C', sfx: '', root };
  const abs = slicer.bambuFilamentFor('ABS', r, tmp);
  assert.ok(abs, 'ABS risolto');
  assert.strictEqual(JSON.parse(fs.readFileSync(abs, 'utf8')).name, 'Bambu ABS @BBL H2C', 'il profilo della stampante vince');
  const asa = slicer.bambuFilamentFor('ASA', r, tmp);
  assert.ok(asa, 'ASA risolto dal generico');
  assert.strictEqual(JSON.parse(fs.readFileSync(asa, 'utf8')).name, 'Generic ASA @base');
  assert.strictEqual(slicer.bambuFilamentFor('PC', r, tmp), null, 'PC senza profili → null, senza eccezioni');
  assert.strictEqual(slicer.bambuFilamentFor('LEGNO', r, tmp), null, 'tipo sconosciuto → null');
});
check('il rimappato segue il letto della macchina di destinazione', () => {
  // macchina finta 256×256 senza doppio ugello: offset zero, niente bande
  const machinePath = path.join(tmp, 'macchina-256.json');
  fs.writeFileSync(machinePath, JSON.stringify({
    name: 'Macchina 256', printable_area: ['0x0', '256x0', '256x256', '0x256'], printable_height: '250',
  }));
  const src = path.join(tmp, 'per-remap.3mf');
  const dst = path.join(tmp, 'rimappato-256.3mf');
  fs.copyFileSync(path.join(tmp, 'progetto.3mf'), src);
  assert.ok(remap(src, dst, profiles, machinePath), 'remap riuscito');
  const cfg = JSON.parse(zip.read(dst, 'Metadata/project_settings.config').toString('utf8'));
  assert.deepStrictEqual(cfg.printable_area, ['0x0', '256x0', '256x256', '0x256'], 'letto della macchina passata');
  assert.strictEqual(cfg.printable_height, '250', 'altezza della macchina passata');
});

/* ---------- costo per file (v1.3, confronto stampanti) ---------- */

console.log('costo');
const cost = require('../renderer/cost');
check('scompone il costo di un insieme di piatti', () => {
  const plates = [
    { index: 1, seconds: 3600, grams: 100, colorGrams: { '#FFFFFF|PLA Basic': 100 } },
    { index: 2, seconds: 1800, grams: 50, colorGrams: { '#000000|PLA Matte': 50 } },
  ];
  const b = cost.breakdown(plates, {
    watts: 100, kwh: 0.2, wearPerHour: 0.1, setupCost: 0.5, failurePct: 10, perKg: () => 20,
  });
  assert.strictEqual(b.seconds, 5400);
  assert.strictEqual(b.grams, 150);
  assert.ok(Math.abs(b.material - 3) < 1e-9, '150 g × 20 €/kg');
  assert.ok(Math.abs(b.kWh - 0.15) < 1e-9, '1,5 h × 100 W');
  assert.ok(Math.abs(b.energy - 0.03) < 1e-9);
  assert.ok(Math.abs(b.wear - 0.15) < 1e-9);
  assert.ok(Math.abs(b.setup - 1) < 1e-9, '2 piatti × 0,50 €');
  assert.ok(Math.abs(b.total - 4.18 * 1.1) < 1e-9, 'base + 10% fallimenti');
});
check('il prezzo al kg arriva da colore e tipo del piatto', () => {
  const plates = [{ index: 1, seconds: 0, grams: 1000, colorGrams: { '#C12E1F|PLA Basic': 1000 } }];
  const b = cost.breakdown(plates, {
    watts: 0, kwh: 0, wearPerHour: 0, setupCost: 0, failurePct: 0,
    perKg: (hex, type) => (hex === '#C12E1F' && type === 'PLA Basic' ? 25 : 0),
  });
  assert.strictEqual(b.material, 25);
  assert.strictEqual(b.total, 25);
});
check('due stampanti sugli stessi piatti: cambia solo la parte macchina', () => {
  const plates = [{ index: 1, seconds: 7200, grams: 200, colorGrams: { '#FFFFFF|PLA Basic': 200 } }];
  const shared = { kwh: 0.25, failurePct: 0, perKg: () => 20 };
  const a = cost.breakdown(plates, { ...shared, watts: 180, wearPerHour: 0.12, setupCost: 0.15 });
  const b = cost.breakdown(plates, { ...shared, watts: 80, wearPerHour: 0.04, setupCost: 0.15 });
  assert.strictEqual(a.material, b.material, 'stesso materiale');
  assert.strictEqual(a.setup, b.setup, 'stesso setup');
  assert.ok(a.energy > b.energy, 'più watt → più energia');
  assert.ok(a.total > b.total, 'la macchina più energivora costa di più');
});

fs.rmSync(tmp, { recursive: true, force: true });
console.log(`\n${passed} test superati.`);
