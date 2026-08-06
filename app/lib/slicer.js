'use strict';
/*
 * Slicing via CLI di Bambu Studio, su Windows / macOS / Linux.
 * Su Windows l'eseguibile si chiama bambu-studio.exe e non sta in /Applications:
 * lo si cerca nei percorsi tipici e, se serve, nel registro (protocollo bambustudio://).
 */
const { execFile, execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const threemf = require('./threemf');
const zip = require('./zip');
const { remap } = require('./remap');

const SLICE_TIMEOUT_MS = 30 * 60 * 1000;

/* ---------- individuazione dell'eseguibile ---------- */

function windowsCandidates() {
  const dirs = [];
  const envDirs = [
    process.env['ProgramFiles'],
    process.env['ProgramFiles(x86)'],
    process.env['ProgramW6432'],
    process.env['LOCALAPPDATA'] && path.join(process.env['LOCALAPPDATA'], 'Programs'),
    process.env['LOCALAPPDATA'],
    process.env['APPDATA'],
  ].filter(Boolean);
  for (const base of envDirs) {
    dirs.push(path.join(base, 'Bambu Studio'), path.join(base, 'BambuStudio'));
  }
  const exes = ['bambu-studio.exe', 'BambuStudio.exe', 'bambu-studio-console.exe'];
  const out = [];
  for (const d of dirs) for (const e of exes) out.push(path.join(d, e));
  return out;
}

// Bambu Studio registra il protocollo bambustudio:// → da lì si ricava il path reale
// anche quando è installato su un disco non standard.
function fromWindowsRegistry() {
  const keys = [
    'HKCR\\bambustudio\\shell\\open\\command',
    'HKCU\\Software\\Classes\\bambustudio\\shell\\open\\command',
    'HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\bambu-studio.exe',
  ];
  for (const key of keys) {
    try {
      const out = execFileSync('reg', ['query', key, '/ve'], {
        encoding: 'utf8',
        windowsHide: true,
        timeout: 5000,
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      const m = /REG_[A-Z_]+\s+(.+)/.exec(out);
      if (!m) continue;
      const quoted = /"([^"]+\.exe)"/i.exec(m[1]);
      const exe = quoted ? quoted[1] : m[1].trim().split(/\s+"/)[0].replace(/"/g, '').trim();
      if (exe && fs.existsSync(exe)) return exe;
    } catch {
      /* chiave assente: si prova la successiva */
    }
  }
  return null;
}

function defaultCandidates() {
  if (process.platform === 'win32') return windowsCandidates();
  if (process.platform === 'darwin') {
    return [
      '/Applications/BambuStudio.app/Contents/MacOS/BambuStudio',
      path.join(os.homedir(), 'Applications/BambuStudio.app/Contents/MacOS/BambuStudio'),
    ];
  }
  return ['/usr/bin/bambu-studio', '/usr/local/bin/bambu-studio', '/opt/bambu-studio/bambu-studio'];
}

let cached = { key: null, value: null };

/** Percorso dell'eseguibile Bambu Studio, o null se non installato. */
function findBambu(customPath) {
  const key = customPath || '';
  if (cached.key === key && cached.value && fs.existsSync(cached.value)) return cached.value;

  let found = null;
  if (customPath && fs.existsSync(customPath)) found = customPath;
  if (!found) found = defaultCandidates().find((p) => fs.existsSync(p)) || null;
  if (!found && process.platform === 'win32') found = fromWindowsRegistry();

  cached = { key, value: found };
  return found;
}

/* ---------- esecuzione ---------- */

function run(exe, args, timeout = SLICE_TIMEOUT_MS) {
  return new Promise((resolve) => {
    execFile(exe, args, { timeout, windowsHide: true, maxBuffer: 64 * 1024 * 1024 }, (err) =>
      resolve(!err)
    );
  });
}

function tempDir(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

function cleanup(dir) {
  try {
    fs.rmSync(dir, { recursive: true, force: true });
  } catch {
    /* la cartella temporanea verrà rimossa dal sistema */
  }
}

function filamentProfiles(types, profilesDir) {
  return (types && types.length ? types : ['PLA Basic'])
    .map((t) =>
      path.join(profilesDir, /matte/i.test(t) ? 'fil_PLA_Matte_H2C.json' : 'fil_PLA_Basic_H2C.json')
    )
    .join(';');
}

function settingsArg(profilesDir) {
  return `${path.join(profilesDir, 'machine_H2C_04.json')};${path.join(profilesDir, 'process_020_H2C.json')}`;
}

/* ---------- profili per stampante (v1.2 M2): letti da Bambu Studio ---------- */

/** Radice dell'albero profili BBL dentro l'installazione di Bambu Studio. */
function bambuVendorDir(bambu) {
  const cands =
    process.platform === 'darwin'
      ? [path.join(path.dirname(bambu), '..', 'Resources', 'profiles', 'BBL')]
      : [
          path.join(path.dirname(bambu), 'resources', 'profiles', 'BBL'),
          path.join(path.dirname(bambu), '..', 'resources', 'profiles', 'BBL'),
        ];
  for (const c of cands) if (fs.existsSync(path.join(c, 'machine'))) return c;
  return null;
}

/** Appiattisce un preset seguendo `inherits` nella stessa cartella; scrive in tmp. */
function flattenPreset(dir, name, tmp, depth = 0) {
  if (depth >= 12) return null;
  let obj;
  try {
    obj = JSON.parse(fs.readFileSync(path.join(dir, `${name}.json`), 'utf8'));
  } catch {
    return null;
  }
  if (obj.inherits) {
    const parentPath = flattenPreset(dir, obj.inherits, tmp, depth + 1);
    if (!parentPath) return null;
    const merged = JSON.parse(fs.readFileSync(parentPath, 'utf8'));
    Object.assign(merged, obj); // il figlio vince sul padre
    obj = merged;
  }
  delete obj.inherits;
  const out = path.join(tmp, `flat-${name.replace(/[\\/]/g, '_')}.json`);
  try {
    fs.writeFileSync(out, JSON.stringify(obj));
  } catch {
    return null;
  }
  return out;
}

/** Trova e appiattisce macchina/processo/filamenti per la stampante scelta.
 *  null = si resta sui profili H2C in bundle. */
function resolveBambu(bambu, spec, nozzle, layer, tmp) {
  const root = bambuVendorDir(bambu);
  if (!root) return null;
  const nz = nozzle.toFixed(1);
  const ly = layer.toFixed(2);
  const code = spec.code || 'H2C';
  const sfx = nozzle === 0.4 ? '' : ` ${nz} nozzle`; // i profili 0.4 non hanno suffisso
  const firstExisting = (sub, names) =>
    names.find((n) => fs.existsSync(path.join(root, sub, `${n}.json`))) || null;

  const mach = firstExisting('machine', [`${spec.machine} ${nz} nozzle`]);
  const proc = firstExisting('process', [
    `${ly}mm Standard @BBL ${code}${sfx}`,
    `${ly}mm Standard @BBL ${code}`,
    `0.20mm Standard @BBL ${code}`,
  ]);
  const filB = firstExisting('filament', [
    `Bambu PLA Basic @BBL ${code}${sfx}`,
    `Bambu PLA Basic @BBL ${code}`,
    'Bambu PLA Basic @base',
  ]);
  const filM = firstExisting('filament', [
    `Bambu PLA Matte @BBL ${code}${sfx}`,
    `Bambu PLA Matte @BBL ${code}`,
    'Bambu PLA Matte @base',
  ]);
  if (!mach || !proc || !filB || !filM) return null;

  const machine = flattenPreset(path.join(root, 'machine'), mach, tmp);
  const procFlat = flattenPreset(path.join(root, 'process'), proc, tmp);
  const filBasic = flattenPreset(path.join(root, 'filament'), filB, tmp);
  const filMatte = flattenPreset(path.join(root, 'filament'), filM, tmp);
  if (!machine || !procFlat || !filBasic || !filMatte) return null;

  // stessa cura del profilo in bundle: la ooze prevention del progetto
  // non deve far bocciare la validazione con la prime tower attiva
  try {
    const p = JSON.parse(fs.readFileSync(procFlat, 'utf8'));
    p.ooze_prevention = '0';
    fs.writeFileSync(procFlat, JSON.stringify(p));
  } catch {
    /* il profilo resta com'è */
  }
  return { machine, process: procFlat, filBasic, filMatte, names: `${mach} · ${proc}` };
}

/** Numero di piatti dichiarati dal progetto (Metadata/model_settings.config). */
function plateCount(file) {
  try {
    const ms = zip.read(file, 'Metadata/model_settings.config');
    return ms ? ms.toString('utf8').split('<plate>').length - 1 : 0;
  } catch {
    return 0;
  }
}

/** Slicing di un progetto .3mf non slicato, con fallback di rimappaggio sulla
 *  griglia H2C e salvataggio piatto-per-piatto: un piatto guasto non fa più
 *  fallire l'intero file, finisce nell'elenco `failed` del risultato.
 *  `plates`: piatti richiesti (numerazione del progetto); vuoto = tutti.
 *  `spec`/`nozzle`/`layerHeight` (v1.2): stampante selezionata e setup di slicing.
 *  `onProgress(k, totale)`: chiamata prima di ogni piatto nei giri piatto-per-piatto. */
async function slice(file, { profilesDir, bambuPath, plates = [], spec = null, nozzle = 0.4, layerHeight = 0.2, onProgress } = {}) {
  const bambu = findBambu(bambuPath);
  if (!bambu) return { error: 'noBambu' };

  const tmp = tempDir('printcost-slice-');
  try {
    const proj = threemf.parseProject(file);
    const outFile = path.join(tmp, 'sliced.3mf');

    // profili della stampante selezionata (v1.2 M2); ripiego sull'H2C in bundle
    let settings = settingsArg(profilesDir);
    let filBasic = path.join(profilesDir, 'fil_PLA_Basic_H2C.json');
    let filMatte = path.join(profilesDir, 'fil_PLA_Matte_H2C.json');
    let machineForRemap = null;
    if (spec && spec.engine === 'bambu') {
      const r = resolveBambu(bambu, spec, nozzle, layerHeight, tmp);
      if (r) {
        settings = `${r.machine};${r.process}`;
        filBasic = r.filBasic;
        filMatte = r.filMatte;
        machineForRemap = r.machine;
      }
    }
    const fil = (proj.slotTypes && proj.slotTypes.length ? proj.slotTypes : ['PLA Basic'])
      .map((t) => (/matte/i.test(t) ? filMatte : filBasic))
      .join(';');

    const attempt = async (src, { plate = 0, arrange = false } = {}) => {
      fs.rmSync(outFile, { force: true }); // mai fidarsi dell'export del tentativo precedente
      const ok = await run(bambu, [
        '--load-settings', settings,
        '--load-filaments', fil,
        ...(arrange ? ['--arrange', '1'] : []),
        '--slice', String(plate), '--debug', '1',
        '--export-3mf', 'sliced.3mf', '--outputdir', tmp, src,
      ]);
      return ok && fs.existsSync(outFile);
    };

    // rimappato una sola volta, alla prima necessità (null = tentato e fallito)
    const remappedFile = path.join(tmp, 'remapped.3mf');
    let remapState;
    const remapped = () => {
      if (remapState === undefined)
        remapState = remap(file, remappedFile, profilesDir, machineForRemap) ? remappedFile : null;
      return remapState;
    };

    // estrae l'unico piatto dall'export e gli restituisce il numero del progetto
    const single = (n) => {
      const a = threemf.analyze(outFile);
      if (a.error || !a.plates || !a.plates.length) return null;
      const p = a.plates[0];
      p.index = n;
      return p;
    };
    const pack = (good, failed) => {
      const perColor = {};
      let seconds = 0;
      let grams = 0;
      for (const p of good) {
        seconds += p.seconds;
        grams += p.grams;
        for (const [k, g] of Object.entries(p.colorGrams)) perColor[k] = (perColor[k] || 0) + g;
      }
      good.sort((a, b) => a.index - b.index);
      return { plates: good, seconds, grams, perColor, failed };
    };
    // un piatto alla volta: prova l'originale, poi il rimappato
    const salvage = async (targets) => {
      const good = [];
      const failed = [];
      for (const [k, n] of targets.entries()) {
        if (onProgress && targets.length > 1) onProgress(k + 1, targets.length);
        let done = await attempt(file, { plate: n });
        if (!done && remapped()) done = await attempt(remapped(), { plate: n });
        const p = done ? single(n) : null;
        if (p) good.push(p);
        else failed.push(n);
      }
      if (!good.length) return { error: 'sliceFail' };
      return pack(good, failed);
    };

    const total = Math.max(plateCount(file), 1);
    const targets = plates.length ? plates.filter((n) => n >= 1).sort((a, b) => a - b) : Array.from({ length: total }, (_, i) => i + 1);

    // sottoinsieme (o piatto singolo): direttamente piatto per piatto
    if (targets.length < total || targets.length === 1) return await salvage(targets);

    // tutto il file: originale → rimappato → riadattato (--arrange, come la GUI
    // al cambio stampante); se l'insieme fallisce, si salva piatto per piatto
    let ok = await attempt(file);
    if (!ok && remapped()) ok = await attempt(remapped());
    if (!ok) ok = await attempt(file, { arrange: true });
    if (ok) return threemf.analyze(outFile);
    return await salvage(targets);
  } finally {
    cleanup(tmp);
  }
}

/** Slicing di una mesh singola (STL/OBJ) col profilo H2C, mono-materiale PLA Basic. */
async function sliceRaw(file, { profilesDir, bambuPath } = {}) {
  const bambu = findBambu(bambuPath);
  if (!bambu) return { error: 'noBambu' };

  const tmp = tempDir('printcost-raw-');
  try {
    const outFile = path.join(tmp, 'sliced.3mf');
    const ok = await run(bambu, [
      '--load-settings', settingsArg(profilesDir),
      '--load-filaments', path.join(profilesDir, 'fil_PLA_Basic_H2C.json'),
      '--arrange', '1', '--slice', '0', '--debug', '1',
      '--export-3mf', 'sliced.3mf', '--outputdir', tmp, file,
    ]);
    if (!ok || !fs.existsSync(outFile)) return { error: 'sliceFail' };
    return threemf.analyze(outFile);
  } finally {
    cleanup(tmp);
  }
}

/** Converte STEP → STL appoggiandosi a Bambu Studio; restituisce il path dell'STL. */
async function stepToSTL(file, { bambuPath } = {}) {
  const bambu = findBambu(bambuPath);
  if (!bambu) return null;
  const outdir = tempDir('printcost-step-');
  const ok = await run(bambu, ['--export-stls', outdir, file], 10 * 60 * 1000);
  if (!ok) {
    cleanup(outdir);
    return null;
  }
  const stl = fs.readdirSync(outdir).find((f) => f.toLowerCase().endsWith('.stl'));
  if (!stl) {
    cleanup(outdir);
    return null;
  }
  return path.join(outdir, stl); // ripulito dal chiamante
}

module.exports = { findBambu, slice, sliceRaw, stepToSTL, cleanup, flattenPreset, bambuVendorDir };
