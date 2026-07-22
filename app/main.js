const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const { execFile, execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const BAMBU = '/Applications/BambuStudio.app/Contents/MacOS/BambuStudio';
const RES = path.join(__dirname, 'resources');
const PROF = path.join(RES, 'profiles');

let win;

function createWindow() {
  win = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 980,
    minHeight: 640,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 18, y: 20 },
    vibrancy: 'under-window',            // materiale Apple ufficiale (NSVisualEffectView)
    visualEffectState: 'active',
    backgroundColor: '#00000000',
    transparent: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());

/* ---------- utilità zip: usa /usr/bin/unzip di macOS ---------- */
function unzipEntry(file, entry) {
  try {
    return execFileSync('/usr/bin/unzip', ['-p', file, entry],
      { maxBuffer: 64 * 1024 * 1024 }).toString('utf8');
  } catch { return null; }
}

/* ---------- parsing 3mf ---------- */
function parseSliceInfo(xml) {
  const plates = [];
  const re = /<plate>([\s\S]*?)<\/plate>/g;
  let m;
  while ((m = re.exec(xml))) {
    const b = m[1];
    const pred = /key="prediction" value="(\d+)"/.exec(b);
    if (!pred) continue;
    const objs = [...b.matchAll(/object identify_id="\d+" name="([^"]+)"/g)].map(x => x[1]);
    const fils = [...b.matchAll(/filament id="(\d+)"[^/]*?color="([^"]+)"[^/]*?used_g="([^"]+)"/g)]
      .map(x => ({ slot: +x[1], color: x[2].toUpperCase(), g: +x[3] }));
    const sup = /support_used" value="true"/.test(b);
    plates.push({ seconds: +pred[1], objects: objs, filaments: fils, support: sup });
  }
  return plates;
}

function parseProject(file) {
  const psRaw = unzipEntry(file, 'Metadata/project_settings.config');
  const msRaw = unzipEntry(file, 'Metadata/model_settings.config');
  const cfg = psRaw ? JSON.parse(psRaw) : {};
  const slotColors = (cfg.filament_colour || []).map(c => c.toUpperCase());
  const slotTypes = (cfg.filament_settings_id || []).map(s => /matte/i.test(s) ? 'PLA Matte' : 'PLA Basic');
  const objSlot = {};
  if (msRaw) {
    for (const om of msRaw.matchAll(/<object id="(\d+)">([\s\S]*?)<\/object>/g)) {
      const name = /name" value="([^"]+)"/.exec(om[2]);
      const ext = /extruder" value="(\d+)"/.exec(om[2]);
      if (name) objSlot[name[1]] = ext ? +ext[1] : 1;
    }
  }
  return { slotColors, slotTypes, objSlot, printer: cfg.printer_model || '' };
}

function analyze(file) {
  const xml = unzipEntry(file, 'Metadata/slice_info.config');
  if (xml === null) return { error: 'not3mf' };
  const proj = parseProject(file);
  const plates = parseSliceInfo(xml);
  if (!plates.length) return { error: 'notSliced', printer: proj.printer };

  // correzione colore per-oggetto: il filamento id=1 appartiene allo slot vero dell'oggetto
  const perColor = {};
  let seconds = 0, grams = 0;
  const plateRows = [];
  plates.forEach((p, i) => {
    seconds += p.seconds;
    const trueSlot = p.objects.length ? (proj.objSlot[p.objects[0]] ?? 1) : 1;
    let pg = 0;
    const colorSet = new Set();
    for (const f of p.filaments) {
      const slot = f.slot === 1 ? trueSlot : f.slot;
      const color = proj.slotColors[slot - 1] || f.color;
      const type = proj.slotTypes[slot - 1] || 'PLA Basic';
      const key = color + '|' + type;
      perColor[key] = (perColor[key] || 0) + f.g;
      pg += f.g; grams += f.g;
      colorSet.add(key);
    }
    plateRows.push({ n: i + 1, seconds: p.seconds, grams: pg,
      objects: p.objects, colors: [...colorSet], support: p.support });
  });
  return { plates: plateRows, seconds, grams, perColor, printer: proj.printer };
}

ipcMain.handle('analyze', (_e, file) => analyze(file));

/* ---------- slicing con Bambu Studio CLI ---------- */
ipcMain.handle('slice', async (_e, file) => {
  if (!fs.existsSync(BAMBU)) return { error: 'noBambu' };
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'slice-'));
  const proj = parseProject(file);
  const fil = (proj.slotTypes.length ? proj.slotTypes : ['PLA Basic'])
    .map(t => path.join(PROF, t === 'PLA Matte' ? 'fil_PLA_Matte_H2C.json' : 'fil_PLA_Basic_H2C.json'))
    .join(';');
  const run = (src) => new Promise(res => {
    execFile(BAMBU, [
      '--load-settings', `${path.join(PROF, 'machine_H2C_04.json')};${path.join(PROF, 'process_020_H2C.json')}`,
      '--load-filaments', fil,
      '--slice', '0', '--debug', '1',
      '--export-3mf', 'sliced.3mf', '--outputdir', tmp, src,
    ], { timeout: 30 * 60 * 1000 }, (err) => res(!err && fs.existsSync(path.join(tmp, 'sliced.3mf'))));
  });

  let ok = await run(file);
  if (!ok) {
    // riposiziona sulla griglia H2C (progetti nati per P1S/X1C) e riprova
    const remapped = path.join(tmp, 'remapped.3mf');
    try {
      execFileSync('/usr/bin/python3', [path.join(RES, 'remap.py'), file, remapped]);
      ok = await run(remapped);
    } catch { /* resta ko */ }
  }
  if (!ok) { fs.rmSync(tmp, { recursive: true, force: true }); return { error: 'sliceFail' }; }
  const out = analyze(path.join(tmp, 'sliced.3mf'));
  fs.rmSync(tmp, { recursive: true, force: true });
  return out;
});

ipcMain.handle('pickFiles', async () => {
  const r = await dialog.showOpenDialog(win, {
    filters: [{ name: '3MF', extensions: ['3mf'] }], properties: ['openFile', 'multiSelections'],
  });
  return r.canceled ? [] : r.filePaths;
});
