'use strict';
/*
 * Ponte fra renderer e processo principale: solo i canali elencati qui,
 * niente Node dentro la pagina.
 */
const { contextBridge, ipcRenderer, webUtils } = require('electron');

contextBridge.exposeInMainWorld('api', {
  /* stato & sistema */
  info: () => ipcRenderer.invoke('app:info'),
  ready: () => ipcRenderer.invoke('app:ready'),
  loadStore: () => ipcRenderer.invoke('store:load'),
  saveStore: (patch) => ipcRenderer.invoke('store:save', patch),
  defaults: () => ipcRenderer.invoke('store:defaults'),
  setMenuLang: (lang) => ipcRenderer.invoke('menu:lang', lang),

  /* file */
  pickFiles: () => ipcRenderer.invoke('files:pick3mf'),
  pickModel: () => ipcRenderer.invoke('files:pickModel'),
  locateBambu: () => ipcRenderer.invoke('files:locateBambu'),
  pathFor: (file) => webUtils.getPathForFile(file),

  /* 3mf & slicing */
  analyze: (p) => ipcRenderer.invoke('threemf:analyze', p),
  thumbnails: (p) => ipcRenderer.invoke('threemf:thumbnails', p),
  slice: (p, plates) => ipcRenderer.invoke('slicer:slice', p, plates || []),
  slicerStatus: () => ipcRenderer.invoke('slicer:status'),

  /* mesh 3D */
  readMesh: (p) => ipcRenderer.invoke('mesh:read', p),
  sliceSTL: (name, buffer) => ipcRenderer.invoke('slicer:sliceSTL', { name, buffer }),

  /* sblocco */
  unlockCode: (code) => ipcRenderer.invoke('unlock:code', code),
  unlockHonor: () => ipcRenderer.invoke('unlock:honor'),
  openBot: () => ipcRenderer.invoke('unlock:openBot'),

  open: (url) => ipcRenderer.invoke('shell:open', url),

  /* eventi dal processo principale */
  onUnlocked: (cb) => ipcRenderer.on('unlocked', () => cb()),
  onOpenFiles: (cb) => ipcRenderer.on('open-files', (_e, files) => cb(files)),
  onUpdate: (cb) => ipcRenderer.on('update-available', (_e, tag) => cb(tag)),
  onSliceProgress: (cb) => ipcRenderer.on('slice-progress', (_e, p) => cb(p)),
  onMenu: (cb) => ipcRenderer.on('menu', (_e, action) => cb(action)),
});
