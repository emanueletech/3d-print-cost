# Costo Stampa 3D · 3D Print Cost

[![Download](https://img.shields.io/github/downloads/emanueletech/3d-print-cost/total?label=download&color=43d17a)](https://github.com/emanueletech/3d-print-cost/releases)
[![Ultima versione](https://img.shields.io/github/v/release/emanueletech/3d-print-cost?label=versione&color=4aa3ff)](https://github.com/emanueletech/3d-print-cost/releases/latest)
[![Stelle](https://img.shields.io/github/stars/emanueletech/3d-print-cost?label=stelle&color=ffb347)](https://github.com/emanueletech/3d-print-cost/stargazers)

**IT** — Calcola tempi, materiale per colore e costo reale delle stampe 3D a partire dai file `.3mf` già slicati (Bambu Studio / OrcaSlicer).

- Trascina uno o più `.3mf` slicati
- Scegli la stampante: i campi (potenza media) si precompilano
- Imposta il costo dell'energia (€/kWh) e i prezzi delle bobine
- Ottieni: tempo totale, grammi per colore, bobine da comprare, costo corrente e costo reale

**EN** — Work out print time, filament per color and the real cost of 3D prints from already-sliced `.3mf` files (Bambu Studio / OrcaSlicer).

- Drop one or more sliced `.3mf` files
- Pick your printer: fields (average wattage) get pre-filled
- Set your energy cost (€/kWh) and spool prices
- Get: total time, grams per color, spools to buy, electricity cost and real cost

## Come si usa / How to use

| | IT | EN |
|---|---|---|
| **Windows** | Installa `3D-Print-Cost-Setup.exe` (vedi sotto) | Install `3D-Print-Cost-Setup.exe` (see below) |
| **macOS** | Scarica `3D-Print-Cost.dmg` dalla pagina **Releases** (vedi sotto) | Download `3D-Print-Cost.dmg` from the **Releases** page (see below) |
| **Browser** | Apri `index.html` (versione ridotta, senza slicing) | Open `index.html` (lite version, no slicing) |

---

## Windows

### Installazione / Install

**IT**

1. Scarica `3D-Print-Cost-Setup-<versione>.exe` dalla pagina **Releases** (oppure dagli artefatti dell'azione *Installer Windows*).
2. Avvialo. Windows mostra **"Windows ha protetto il PC"** perché l'app non ha una firma digitale a pagamento: clicca **Ulteriori informazioni → Esegui comunque**. È la stessa cosa del `xattr -dr com.apple.quarantine` su Mac.
3. Scegli se installare solo per te (predefinito, nessuna richiesta di amministratore) o per tutti gli utenti.
4. Esiste anche `3D-Print-Cost-Portable-<versione>.exe`: file unico, nessuna installazione, si può tenere su una chiavetta.

Requisiti: Windows 10 o 11 (64 bit). Su Windows ARM gira in emulazione x64.
**Bambu Studio è opzionale**: i `.3mf` già slicati funzionano da soli; serve solo per slicare dall'app o per importare gli STEP. Se è installato in un percorso insolito, indicalo da *Costi & Setup → Slicer*.

**EN**

1. Download `3D-Print-Cost-Setup-<version>.exe` from **Releases** (or from the *Installer Windows* action artifacts).
2. Run it. Windows shows **"Windows protected your PC"** because the app has no paid code-signing certificate: click **More info → Run anyway**. Same idea as `xattr -dr com.apple.quarantine` on Mac.
3. Choose a per-user install (default, no admin prompt) or all-users.
4. A `3D-Print-Cost-Portable-<version>.exe` is also built: single file, no install, USB-stick friendly.

Requirements: Windows 10 or 11 (64-bit); runs under x64 emulation on Windows ARM.
**Bambu Studio is optional**: already-sliced `.3mf` work on their own; it is only needed to slice from the app or to import STEP files. If it lives in an unusual folder, point to it in *Costs & Setup → Slicer*.

### Costruire l'installer / Build the installer

Da GitHub, senza un PC Windows: **Actions → Installer Windows → Run workflow**; l'`.exe` finisce fra gli artefatti. Con un tag `v*` viene anche allegato alla release.

On a Windows machine:

```bash
cd app
npm install
npm start        # avvia l'app in sviluppo / run in development
npm test         # test di zip, parsing 3mf, remap, sblocco, mesh
npm run dist:win # crea dist/3D-Print-Cost-Setup-<versione>.exe + versione portatile
```

---

## macOS

### Installazione / Install

**IT**

1. Scarica `3D-Print-Cost.dmg` dalla pagina **Releases**.
2. Aprilo e trascina l'app nella cartella **Applicazioni**.
3. Al primo avvio macOS dice che l'app "non può essere aperta" perché non è firmata con un certificato a pagamento. Rimedio: tasto destro sull'app → **Apri** → **Apri**. In alternativa, da Terminale:

```bash
xattr -dr com.apple.quarantine "/Applications/3D Print Cost.app"
```

Requisiti: **macOS 26 o successivo** su **Apple Silicon** (l'app è compilata per `arm64`; i Mac Intel non sono supportati). Su Mac più vecchi si può usare la versione web (`index.html`).

**EN**

1. Download `3D-Print-Cost.dmg` from the **Releases** page.
2. Open it and drag the app into **Applications**.
3. On first launch macOS says the app "cannot be opened" because it is not signed with a paid certificate. Fix: right-click the app → **Open** → **Open**, or from Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/3D Print Cost.app"
```

Requirements: **macOS 26 or later** on **Apple Silicon** (the app is built for `arm64`; Intel Macs are not supported). On older Macs use the web version (`index.html`).

### Costruire l'app / Build the app

```bash
bash native/build.sh     # compila 3D Print Cost.app
bash native/make-dmg.sh  # crea il .dmg distribuibile
```

## Struttura / Layout

- `index.html` — versione web (lettura dei `.3mf` slicati)
- `app/` — app desktop Electron (Windows, e utilizzabile anche su macOS/Linux)
  - `lib/` — lettura zip/3mf, rimappaggio griglia, slicing, database, sblocco
  - `renderer/` — interfaccia, vista 3D WebGL, traduzioni (IT/EN/ES/FR)
  - `test/` — test eseguibili con `npm test`
- `native/` — app nativa macOS (SwiftUI) e script `.dmg`
- `.github/workflows/` — costruzione automatica dell'installer Windows

L'app desktop non richiede né `unzip` né Python: legge e riscrive i `.3mf` in JavaScript, quindi funziona su Windows senza installare nulla.

## Licenza / License

**IT** — L'app è gratuita per tutti, anche per uso professionale. Il codice è pubblico per trasparenza e contributi, ma i diritti restano dell'autore: non è consentito ridistribuire l'app o versioni modificate, né rimuovere o alterare il meccanismo di sblocco e i crediti. Dettagli in [LICENSE.md](LICENSE.md).

**EN** — The app is free for everyone, including professional use. The code is public for transparency and contributions, but all rights remain with the author: redistributing the app or modified versions, or removing/altering the unlock mechanism and credits, is not permitted. Details in [LICENSE.md](LICENSE.md).

## Note

- I tempi e i grammi vengono letti dal 3mf slicato (`Metadata/slice_info.config`): l'app non slica da sola, chiede a Bambu Studio.
- La potenza media per stampante è indicativa: misurala con una presa smart per la massima precisione.
- Il costo reale somma materiale consumato (€/kg del materiale abbinato al colore), energia, usura macchina, avvii e quota fallimenti.
- Print times and grams are read from the sliced 3mf (`Metadata/slice_info.config`): the app does not slice by itself, it asks Bambu Studio.
- Per-printer average wattage is indicative: measure with a smart plug for best accuracy.
- The real cost adds up used material (€/kg of the material matched to each color), energy, machine wear, startups and a failure allowance.
