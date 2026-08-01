'use strict';
/*
 * Processo principale — Windows / macOS / Linux.
 * Tutto ciò che tocca il disco, i processi esterni o lo sblocco vive qui:
 * il renderer parla solo tramite i canali IPC dichiarati in preload.js.
 */
const { app, BrowserWindow, ipcMain, dialog, shell, Menu, nativeTheme } = require('electron');
const fs = require('fs');
const os = require('os');
const path = require('path');

const store = require('./lib/store');
const threemf = require('./lib/threemf');
const slicer = require('./lib/slicer');
const unlock = require('./lib/unlock');
const { Author } = store;

const isMac = process.platform === 'darwin';
const isWin = process.platform === 'win32';

let win = null;
let state = null;
/** deep-link di sblocco arrivato prima che la finestra fosse pronta */
let pendingUnlock = false;
/** file .3mf da riga di comando / "Apri con" prima che il renderer fosse pronto */
let pendingFiles = [];

/* ---------- percorsi ---------- */

function resourcesDir() {
  return app.isPackaged ? path.join(process.resourcesPath, 'resources') : path.join(__dirname, 'resources');
}
function profilesDir() {
  return path.join(resourcesDir(), 'profiles');
}
function slicerOpts() {
  return { profilesDir: profilesDir(), bambuPath: state && state.bambuPath ? state.bambuPath : '' };
}

/* ---------- stato ---------- */

function loadState() {
  store.init(app.getPath('userData'));
  state = store.load();
  return state;
}
function patchState(patch) {
  state = { ...state, ...patch };
  store.save(state);
  return state;
}

/* ---------- deep link + file da riga di comando ---------- */

function collect3mf(argv) {
  return argv.filter((a) => typeof a === 'string' && /\.3mf$/i.test(a) && fs.existsSync(a));
}

function handleUnlockURL(url) {
  if (!unlock.tokenFromURL(url)) return false;
  patchState({ unlocked: true });
  if (win) win.webContents.send('unlocked');
  else pendingUnlock = true;
  return true;
}

function handleArgv(argv) {
  for (const a of argv) {
    if (typeof a === 'string' && a.toLowerCase().startsWith(`${Author.urlScheme}://`)) handleUnlockURL(a);
  }
  const files = collect3mf(argv);
  if (!files.length) return;
  if (win) win.webContents.send('open-files', files);
  else pendingFiles.push(...files);
}

/* ---------- finestra ---------- */

function createWindow() {
  win = new BrowserWindow({
    width: 1320,
    height: 880,
    minWidth: 1020,
    minHeight: 680,
    show: false,
    backgroundColor: '#0f1420',
    icon: isWin ? path.join(__dirname, 'build', 'icon.ico') : path.join(__dirname, 'build', 'icon.png'),
    // su Windows la barra è nascosta ma i pulsanti restano nativi (overlay);
    // su macOS resta lo stile "hiddenInset" con la vibrancy di sistema
    titleBarStyle: isMac ? 'hiddenInset' : isWin ? 'hidden' : 'default',
    ...(isWin ? { titleBarOverlay: { color: '#12182a', symbolColor: '#dfe6f5', height: 42 } } : {}),
    ...(isMac
      ? { trafficLightPosition: { x: 18, y: 20 }, vibrancy: 'under-window', visualEffectState: 'active' }
      : {}),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      spellcheck: false,
    },
  });

  win.once('ready-to-show', () => win.show());
  win.on('closed', () => {
    win = null;
  });

  // link esterni sempre nel browser di sistema, mai dentro una finestra Electron
  win.webContents.setWindowOpenHandler(({ url }) => {
    openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (!url.startsWith('file://')) {
      e.preventDefault();
      openExternal(url);
    }
  });

  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

function openExternal(url) {
  if (typeof url === 'string' && /^https?:\/\//i.test(url)) shell.openExternal(url);
}

/* ---------- menu ---------- */

const MENU = {
  it: { file: 'File', open: 'Apri .3mf…', model: 'Apri modello 3D…', quit: 'Esci', edit: 'Modifica', undo: 'Annulla', redo: 'Ripeti', cut: 'Taglia', copy: 'Copia', paste: 'Incolla', selectAll: 'Seleziona tutto', view: 'Vista', reload: 'Ricarica', zoomIn: 'Ingrandisci', zoomOut: 'Riduci', zoomReset: 'Zoom normale', fullscreen: 'Schermo intero', devtools: 'Strumenti di sviluppo', help: 'Aiuto', bambu: 'Indica dove è installato Bambu Studio…', folder: 'Apri la cartella dei dati' },
  en: { file: 'File', open: 'Open .3mf…', model: 'Open 3D model…', quit: 'Quit', edit: 'Edit', undo: 'Undo', redo: 'Redo', cut: 'Cut', copy: 'Copy', paste: 'Paste', selectAll: 'Select all', view: 'View', reload: 'Reload', zoomIn: 'Zoom in', zoomOut: 'Zoom out', zoomReset: 'Actual size', fullscreen: 'Full screen', devtools: 'Developer tools', help: 'Help', bambu: 'Locate Bambu Studio…', folder: 'Open data folder' },
  es: { file: 'Archivo', open: 'Abrir .3mf…', model: 'Abrir modelo 3D…', quit: 'Salir', edit: 'Editar', undo: 'Deshacer', redo: 'Rehacer', cut: 'Cortar', copy: 'Copiar', paste: 'Pegar', selectAll: 'Seleccionar todo', view: 'Ver', reload: 'Recargar', zoomIn: 'Acercar', zoomOut: 'Alejar', zoomReset: 'Tamaño real', fullscreen: 'Pantalla completa', devtools: 'Herramientas de desarrollo', help: 'Ayuda', bambu: 'Localizar Bambu Studio…', folder: 'Abrir carpeta de datos' },
  fr: { file: 'Fichier', open: 'Ouvrir .3mf…', model: 'Ouvrir modèle 3D…', quit: 'Quitter', edit: 'Édition', undo: 'Annuler', redo: 'Rétablir', cut: 'Couper', copy: 'Copier', paste: 'Coller', selectAll: 'Tout sélectionner', view: 'Affichage', reload: 'Recharger', zoomIn: 'Zoom avant', zoomOut: 'Zoom arrière', zoomReset: 'Taille réelle', fullscreen: 'Plein écran', devtools: 'Outils de développement', help: 'Aide', bambu: 'Localiser Bambu Studio…', folder: 'Ouvrir le dossier de données' },
};

function buildMenu(lang) {
  const t = MENU[lang] || MENU.en; // ripiego inglese per le lingue non tradotte
  const send = (msg) => () => win && win.webContents.send('menu', msg);
  const template = [
    ...(isMac ? [{ role: 'appMenu' }] : []),
    {
      label: t.file,
      submenu: [
        { label: t.open, accelerator: 'CmdOrCtrl+O', click: send('open3mf') },
        { label: t.model, accelerator: 'CmdOrCtrl+Shift+O', click: send('openModel') },
        { type: 'separator' },
        { label: t.bambu, click: send('locateBambu') },
        { label: t.folder, click: () => shell.openPath(app.getPath('userData')) },
        { type: 'separator' },
        isMac ? { role: 'close' } : { label: t.quit, role: 'quit' },
      ],
    },
    {
      label: t.edit,
      submenu: [
        { label: t.undo, role: 'undo' }, { label: t.redo, role: 'redo' }, { type: 'separator' },
        { label: t.cut, role: 'cut' }, { label: t.copy, role: 'copy' }, { label: t.paste, role: 'paste' },
        { label: t.selectAll, role: 'selectAll' },
      ],
    },
    {
      label: t.view,
      submenu: [
        { label: t.reload, role: 'reload' }, { type: 'separator' },
        { label: t.zoomReset, role: 'resetZoom' }, { label: t.zoomIn, role: 'zoomIn' }, { label: t.zoomOut, role: 'zoomOut' },
        { type: 'separator' },
        { label: t.fullscreen, role: 'togglefullscreen' },
        { label: t.devtools, role: 'toggleDevTools' },
      ],
    },
    {
      label: t.help,
      submenu: [
        { label: 'Instagram', click: () => openExternal(Author.instagram) },
        { label: 'Telegram', click: () => openExternal(Author.telegram) },
        { label: 'MakerWorld', click: () => openExternal(Author.makerworld) },
        { label: 'YouTube', click: () => openExternal(Author.youtube) },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

/* ---------- IPC ---------- */

function registerIPC() {
  ipcMain.handle('app:info', () => ({
    platform: process.platform,
    version: app.getVersion(),
    locale: app.getLocale(),
    bambu: slicer.findBambu(state.bambuPath) || '',
    userData: app.getPath('userData'),
  }));

  // il renderer segnala di essere pronto: gli si passa quanto arrivato prima
  ipcMain.handle('app:ready', () => {
    const out = { unlocked: pendingUnlock, files: pendingFiles.slice() };
    pendingUnlock = false;
    pendingFiles = [];
    return out;
  });

  ipcMain.handle('store:load', () => state);
  ipcMain.handle('store:save', (_e, patch) => patchState(patch || {}));
  // liste di fabbrica: servono ai pulsanti "ripristina predefiniti" e ai preset materiali
  ipcMain.handle('store:defaults', () => ({
    materials: store.defaultMaterials(),
    printers: store.defaultPrinters(),
    presets: store.presets(),
  }));

  ipcMain.handle('menu:lang', (_e, lang) => {
    buildMenu(lang);
    return true;
  });

  ipcMain.handle('files:pick3mf', async () => {
    const r = await dialog.showOpenDialog(win, {
      filters: [{ name: '3MF', extensions: ['3mf'] }],
      properties: ['openFile', 'multiSelections'],
    });
    return r.canceled ? [] : r.filePaths;
  });

  ipcMain.handle('files:pickModel', async () => {
    const r = await dialog.showOpenDialog(win, {
      filters: [{ name: 'STL · OBJ · STEP', extensions: ['stl', 'obj', 'step', 'stp'] }],
      properties: ['openFile'],
    });
    return r.canceled ? null : r.filePaths[0];
  });

  ipcMain.handle('files:locateBambu', async () => {
    const r = await dialog.showOpenDialog(win, {
      title: 'Bambu Studio',
      filters: isWin ? [{ name: 'Bambu Studio', extensions: ['exe'] }] : [],
      properties: ['openFile'],
    });
    if (!r.canceled && r.filePaths[0]) patchState({ bambuPath: r.filePaths[0] });
    return { bambu: slicer.findBambu(state.bambuPath) || '' };
  });

  ipcMain.handle('threemf:analyze', (_e, file) => threemf.analyze(file));
  ipcMain.handle('threemf:thumbnails', (_e, file) => threemf.thumbnails(file));
  ipcMain.handle('slicer:slice', (_e, file) => slicer.slice(file, slicerOpts()));
  ipcMain.handle('slicer:status', () => ({ bambu: slicer.findBambu(state.bambuPath) || '' }));

  /** mesh dal disco: lo STEP passa da Bambu Studio, STL/OBJ si leggono diretti */
  ipcMain.handle('mesh:read', async (_e, file) => {
    const ext = path.extname(file).toLowerCase();
    let src = file;
    let tmpDir = null;
    if (ext === '.step' || ext === '.stp') {
      const stl = await slicer.stepToSTL(file, slicerOpts());
      if (!stl) return { error: slicer.findBambu(state.bambuPath) ? 'stepFail' : 'noBambu' };
      src = stl;
      tmpDir = path.dirname(stl);
    }
    try {
      const data = fs.readFileSync(src);
      return {
        name: path.basename(file),
        ext: path.extname(src).toLowerCase().replace('.', ''),
        buffer: data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength),
      };
    } catch {
      return { error: 'readFail' };
    } finally {
      if (tmpDir) slicer.cleanup(tmpDir);
    }
  });

  /** slicing della posa scelta: la mesh orientata arriva già in STL binario */
  ipcMain.handle('slicer:sliceSTL', async (_e, { name, buffer }) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'printcost-mesh-'));
    const file = path.join(dir, `${String(name || 'model').replace(/[^\w.-]+/g, '_')}.stl`);
    try {
      fs.writeFileSync(file, Buffer.from(buffer));
      return await slicer.sliceRaw(file, slicerOpts());
    } catch {
      return { error: 'sliceFail' };
    } finally {
      slicer.cleanup(dir);
    }
  });

  ipcMain.handle('unlock:code', (_e, code) => {
    const ok = unlock.validCode(code);
    if (ok) patchState({ unlocked: true });
    return ok;
  });
  ipcMain.handle('unlock:honor', () => {
    if (!Author.allowHonorUnlock) return false;
    patchState({ unlocked: true });
    return true;
  });
  ipcMain.handle('unlock:openBot', () => {
    openExternal(Author.telegramBot);
    return true;
  });

  ipcMain.handle('shell:open', (_e, url) => {
    openExternal(url);
    return true;
  });
}

/* ---------- avvio ---------- */

// una sola istanza: serve al deep-link di sblocco e ai file aperti con l'app
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', (_e, argv) => {
    handleArgv(argv);
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });

  // macOS consegna deep-link e file con eventi dedicati
  app.on('open-url', (e, url) => {
    e.preventDefault();
    handleUnlockURL(url);
    if (win) win.focus();
  });
  app.on('open-file', (e, file) => {
    e.preventDefault();
    if (win) win.webContents.send('open-files', [file]);
    else pendingFiles.push(file);
  });

  app.whenReady().then(() => {
    nativeTheme.themeSource = 'dark'; // l'interfaccia è disegnata solo in scuro
    loadState();

    // protocollo printcost:// (l'installer NSIS lo registra anche a livello di sistema)
    if (!app.isDefaultProtocolClient(Author.urlScheme)) {
      if (isWin && !app.isPackaged && process.argv[1]) {
        app.setAsDefaultProtocolClient(Author.urlScheme, process.execPath, [path.resolve(process.argv[1])]);
      } else {
        app.setAsDefaultProtocolClient(Author.urlScheme);
      }
    }

    registerIPC();
    buildMenu(state.lang || (app.getLocale() || 'en').slice(0, 2));
    createWindow();
    handleArgv(process.argv.slice(1));

    app.on('activate', () => {
      if (!BrowserWindow.getAllWindows().length) createWindow();
    });
  });

  app.on('window-all-closed', () => app.quit());
}
