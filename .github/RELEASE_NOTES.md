## 🇮🇹 Novità

**La stampante comanda lo slicer.** Selezionata una stampante Bambu (H2C, H2D, H2D Pro, H2S, X1C, P1S, A1), lo slicing integrato usa i **suoi profili veri**, letti dall'installazione di Bambu Studio e risolti automaticamente: letto, limiti e riposizionamento seguono la macchina scelta, non più un profilo fisso. Se Bambu Studio manca, si torna al profilo incluso come prima.

**Ugello e layer a scelta.** Nel pannello File & Slicing scegli l'ugello (0.2–0.8 mm) e l'altezza layer: i profili di processo si adattano di conseguenza. Sui file già slicati il nuovo pulsante **⟳ Rislica** rifà i conti con il setup corrente.

**Snapmaker U1 ed Elegoo, senza finzioni.** Le stampanti con uno slicer proprio (Snapmaker Orca, ElegooSlicer) mostrano il pulsante **«Apri in …»**: il 3mf si apre direttamente lì, si slica, si esporta il «file del piatto slicato» e l'app lo legge al volo con i consumi veri. In listino arrivano Elegoo Centauri Carbon e Neptune 4 Pro.

**PETG e TPU.** Il tipo di materiale di ogni slot del progetto guida la scelta del profilo filamento: PETG e TPU usano i profili dedicati della stampante risolta, con ripiego sul PLA dove mancano.

**Debutto Linux.** Da questa versione l'app c'è anche per Linux: **AppImage** (qualsiasi distribuzione) e **.deb** (Debian/Ubuntu), con le stesse funzioni di Windows.

**Ritocchi.** Le anteprime dei piatti slicati mostrano il tempo di stampa del piatto; sezione Stampanti con la colonna dello slicer di ogni macchina; compilazione da cartelle sincronizzate iCloud sistemata per chi costruisce l'app da sé.

### Pacchetti

| Sistema | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.2.0.exe` (installer) — oppure `3D-Print-Cost-Portable-1.2.0.exe` |
| **macOS** | `3D-Print-Cost.dmg` — richiede macOS 26 su Apple Silicon |
| **Linux** | `3D-Print-Cost-1.2.0.AppImage` — oppure `3D-Print-Cost-1.2.0.deb` |
| **Browser** | `index.html` nel repository, versione ridotta senza slicing |

I pacchetti non hanno una firma digitale a pagamento: al primo avvio i sistemi mostrano un avviso; le istruzioni per superarlo sono nel README.

### Aggiornamento dalle versioni precedenti

Dalla 1.1.4 l'app segnala da sola le nuove versioni all'avvio. Chi usa la **1.0 deve aggiornare**: verifica lo sblocco col vecchio schema e non è più compatibile con il bot.

---

## 🇺🇸 What's new

**The printer drives the slicer.** With a Bambu printer selected (H2C, H2D, H2D Pro, H2S, X1C, P1S, A1), in-app slicing uses its **real profiles**, read from your Bambu Studio installation and resolved automatically: bed, limits and repositioning follow the chosen machine instead of a fixed profile. If Bambu Studio is missing, the bundled profile is used as before.

**Nozzle and layer of your choice.** In the Files & Slicing panel pick the nozzle (0.2–0.8 mm) and layer height: process profiles adapt accordingly. On already-sliced files the new **⟳ Re-slice** button redoes the numbers with the current setup.

**Snapmaker U1 and Elegoo, no pretending.** Printers with their own slicer (Snapmaker Orca, ElegooSlicer) get an **"Open in …"** button: the 3mf opens right there, you slice, export the "plate sliced file" and the app reads it instantly with true usage. Elegoo Centauri Carbon and Neptune 4 Pro join the printer list.

**PETG and TPU.** Each slot's material type drives the filament profile choice: PETG and TPU use the resolved printer's dedicated profiles, falling back to PLA where missing.

**Linux debut.** Starting with this version the app is also available for Linux: **AppImage** (any distro) and **.deb** (Debian/Ubuntu), with the same features as Windows.

**Polish.** Sliced plate previews show the plate's print time; the Printers section gains a column with each machine's slicer; building the app from iCloud-synced folders fixed for self-builders.

### Packages

| System | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.2.0.exe` (installer) — or `3D-Print-Cost-Portable-1.2.0.exe` |
| **macOS** | `3D-Print-Cost.dmg` — requires macOS 26 on Apple Silicon |
| **Linux** | `3D-Print-Cost-1.2.0.AppImage` — or `3D-Print-Cost-1.2.0.deb` |
| **Browser** | `index.html` in the repository, lite version without slicing |

The packages carry no paid code-signing certificate: systems show a warning on first launch; the README explains how to get past it.

### Upgrading from previous versions

Since 1.1.4 the app announces new versions by itself at startup. Anyone still on **1.0 must update**: it verifies the unlock with the old scheme and no longer works with the bot.
