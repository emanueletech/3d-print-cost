## 🇮🇹 Novità

**Slicing dei modelli complessi riparato (macOS).** Su alcuni progetti Bambu Studio scriveva così tanto log da riempire un canale mai letto: il processo restava bloccato per sempre e l'app sembrava non fare nulla. Ora il canale viene gestito correttamente e un timeout di sicurezza termina gli slicing che durano troppo.

**Errori di slicing visibili.** Quando lo slicing fallisce o Bambu Studio non viene trovato, la scheda del file mostra il motivo invece di restare muta. Il dettaglio tecnico finisce in `~/Library/Logs/3DPrintCost-slicer.log` (macOS).

**Progetti nati per altre stampanti.** Lo slicing ora riprova in tre passi: file originale, riposizionamento sul piatto H2C (ora anche della prime tower, fuori dalle bande riservate ai due ugelli) e infine riadattamento automatico della disposizione (`--arrange`), come fa Bambu Studio quando si cambia stampante. Risolti anche i progetti con «ooze prevention» attiva, che la validazione rifiutava.

**Slicing di un solo piatto.** Se tra le anteprime lasci selezionato un piatto solo, viene slicato solo quello: sui progetti multi-piatto complessi la prova dura minuti invece di decine.

**Testo più chiaro.** Il pannello File & Slicing ora spiega che lo slicing integrato usa sempre Bambu Studio con profilo H2C e che la stampante selezionata incide solo sui costi.

### Pacchetti

| Sistema | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.1.3.exe` (installer) — oppure `3D-Print-Cost-Portable-1.1.3.exe` (nessuna installazione) |
| **macOS** | `3D-Print-Cost.dmg` — richiede macOS 26 su Apple Silicon |
| **Browser** | `index.html` nel repository, versione ridotta senza slicing |

Né l'installer Windows né l'app macOS hanno una firma digitale a pagamento: al primo avvio i rispettivi sistemi mostrano un avviso. Le istruzioni per superarlo sono nel README.

### Aggiornamento dalle versioni precedenti

Chi usa la **1.0 deve aggiornare**: verifica lo sblocco col vecchio schema e non è più compatibile con il bot. Dalla 1.1.x l'aggiornamento è consigliato, soprattutto se usi lo slicing dall'app.

---

## 🇺🇸 What's new

**Complex-model slicing fixed (macOS).** On some projects Bambu Studio wrote so much log output that it filled a never-read channel: the process hung forever and the app looked like it was doing nothing. The channel is now handled properly and a safety timeout terminates runs that take too long.

**Visible slicing errors.** When slicing fails or Bambu Studio can't be found, the file card now shows the reason instead of staying silent. Technical details go to `~/Library/Logs/3DPrintCost-slicer.log` (macOS).

**Projects made for other printers.** Slicing now retries in three steps: the original file, repositioning onto the H2C plate (now including the prime tower, kept clear of both nozzles' reserved bands) and finally automatic re-arranging (`--arrange`), just like Bambu Studio does when you switch printers. Projects with "ooze prevention" enabled, which validation used to reject, are fixed too.

**Single-plate slicing.** If only one plate is left selected among the previews, only that plate gets sliced: on complex multi-plate projects a test takes minutes instead of dozens.

**Clearer wording.** The Files & Slicing panel now explains that in-app slicing always uses Bambu Studio with the H2C profile and that the selected printer only affects costs.

### Packages

| System | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.1.3.exe` (installer) — or `3D-Print-Cost-Portable-1.1.3.exe` (no installation) |
| **macOS** | `3D-Print-Cost.dmg` — requires macOS 26 on Apple Silicon |
| **Browser** | `index.html` in the repository, lite version without slicing |

Neither the Windows installer nor the macOS app carries a paid code-signing certificate: on first launch each system shows a warning. The README explains how to get past it.

### Upgrading from previous versions

Anyone still on **1.0 must update**: it verifies the unlock with the old scheme and no longer works with the bot. Upgrading from 1.1.x is recommended, especially if you slice from the app.
