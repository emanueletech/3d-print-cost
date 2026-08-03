## 🇮🇹 Novità

**Avviso di aggiornamento.** All'avvio l'app confronta la propria versione con l'ultima release su GitHub: se ce n'è una più nuova compare una barra con il pulsante Scarica. Senza connessione non compare nulla e l'app resta completamente utilizzabile offline.

**Dettaglio esatto per colore.** In Panoramica, cliccando su **Materiale** si apre il riquadro con i grammi esatti di ogni colore; cliccando su **Materiale (reale)** la spesa esatta per colore. In **Colori & Bobine** c'è la nuova colonna **Consumato**: il costo del materiale davvero usato, colore per colore, accanto all'economia delle bobine da comprare.

**Colori usati in cima ai Materiali.** La sezione Materiali ora mostra per primi i colori dei file caricati, con grammi e prezzo €/kg del materiale abbinato — in arancione quando manca l'abbinamento e vale il prezzo predefinito.

**Piatti reali negli export parziali.** Esportando dal proprio slicer un solo piatto slicato, l'app ora mantiene il numero vero del piatto e mostra spente le anteprime dei piatti senza dati, invece di farli sembrare tutti selezionati.

**Niente più silenzi sui file sbagliati.** Trascinando un file non leggibile (per esempio il G-code puro) l'app spiega che serve il «file del piatto slicato» (`.gcode.3mf`). Su macOS gli STL/OBJ/STEP trascinati nella finestra aprono direttamente Orienta 3D.

### Pacchetti

| Sistema | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.1.4.exe` (installer) — oppure `3D-Print-Cost-Portable-1.1.4.exe` (nessuna installazione) |
| **macOS** | `3D-Print-Cost.dmg` — richiede macOS 26 su Apple Silicon |
| **Browser** | `index.html` nel repository, versione ridotta senza slicing |

Né l'installer Windows né l'app macOS hanno una firma digitale a pagamento: al primo avvio i rispettivi sistemi mostrano un avviso. Le istruzioni per superarlo sono nel README.

### Aggiornamento dalle versioni precedenti

Chi usa la **1.0 deve aggiornare**: verifica lo sblocco col vecchio schema e non è più compatibile con il bot. Dalla 1.1.x l'aggiornamento è consigliato — e da questa versione in poi sarà l'app stessa ad avvisarti delle prossime.

---

## 🇺🇸 What's new

**Update notice.** On startup the app compares its version with the latest GitHub release: if a newer one exists, a bar with a Download button appears. With no connection nothing shows up and the app keeps working fully offline.

**Exact per-color detail.** In the Overview, clicking **Material** opens a panel with the exact grams of every color; clicking **Material (real)** shows the exact spend per color. **Colors & Spools** gains a new **Used** column: the cost of the material actually consumed, color by color, next to the spools-to-buy economics.

**Used colors on top of Materials.** The Materials section now leads with the colors of the loaded files, showing grams and the matched material's price per kg — in orange when there is no match and the default price applies.

**Real plates in partial exports.** When you export a single sliced plate from your slicer, the app now keeps the plate's true number and dims the previews of plates without data, instead of showing them all as selected.

**No more silence on wrong files.** Dropping an unreadable file (for instance plain G-code) now explains that the "plate sliced file" (`.gcode.3mf`) is needed. On macOS, STL/OBJ/STEP files dropped on the window open 3D Orient directly.

### Packages

| System | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.1.4.exe` (installer) — or `3D-Print-Cost-Portable-1.1.4.exe` (no installation) |
| **macOS** | `3D-Print-Cost.dmg` — requires macOS 26 on Apple Silicon |
| **Browser** | `index.html` in the repository, lite version without slicing |

Neither the Windows installer nor the macOS app carries a paid code-signing certificate: on first launch each system shows a warning. The README explains how to get past it.

### Upgrading from previous versions

Anyone still on **1.0 must update**: it verifies the unlock with the old scheme and no longer works with the bot. Upgrading from 1.1.x is recommended — and from this version on, the app itself will tell you about the next ones.
