const { contextBridge, ipcRenderer, webUtils } = require('electron');

contextBridge.exposeInMainWorld('api', {
  analyze: (p) => ipcRenderer.invoke('analyze', p),
  slice: (p) => ipcRenderer.invoke('slice', p),
  pickFiles: () => ipcRenderer.invoke('pickFiles'),
  pathFor: (file) => webUtils.getPathForFile(file),
});
