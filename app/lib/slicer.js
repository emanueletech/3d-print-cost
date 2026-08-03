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

/** Slicing di un progetto .3mf non slicato (con fallback di rimappaggio sulla griglia H2C). */
async function slice(file, { profilesDir, bambuPath } = {}) {
  const bambu = findBambu(bambuPath);
  if (!bambu) return { error: 'noBambu' };

  const tmp = tempDir('printcost-slice-');
  try {
    const proj = threemf.parseProject(file);
    const fil = filamentProfiles(proj.slotTypes, profilesDir);
    const outFile = path.join(tmp, 'sliced.3mf');

    const attempt = async (src, arrange) => {
      const ok = await run(bambu, [
        '--load-settings', settingsArg(profilesDir),
        '--load-filaments', fil,
        ...(arrange ? ['--arrange', '1'] : []),
        '--slice', '0', '--debug', '1',
        '--export-3mf', 'sliced.3mf', '--outputdir', tmp, src,
      ]);
      return ok && fs.existsSync(outFile);
    };

    let ok = await attempt(file);
    if (!ok) {
      // progetto nato per un'altra stampante: riposiziona sulla griglia H2C e riprova
      const remapped = path.join(tmp, 'remapped.3mf');
      if (remap(file, remapped, profilesDir)) ok = await attempt(remapped);
    }
    // ultima spiaggia: lascia che sia Bambu Studio a riadattare la disposizione
    // sul piatto H2C (come fa la GUI quando si cambia stampante)
    if (!ok) ok = await attempt(file, true);
    if (!ok) return { error: 'sliceFail' };
    return threemf.analyze(outFile);
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

module.exports = { findBambu, slice, sliceRaw, stepToSTL, cleanup };
