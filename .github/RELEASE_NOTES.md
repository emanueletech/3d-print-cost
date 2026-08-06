## 🇮🇹 Novità

**Un piatto guasto non ferma più tutto il file.** Nei progetti multi-piatto bastava un piatto problematico (fuori area, in conflitto con la prime tower…) per far fallire l'intero slicing. Ora l'app slica piatto per piatto quando serve: i piatti buoni si sommano nel risultato, quelli irrecuperabili vengono elencati in un avviso e restano con l'anteprima spenta.

**Slicing incrementale.** Sui file già slicati i piatti spenti restano cliccabili: li selezioni (bordo arancione) e con «Slica (N)» vengono aggiunti al risultato esistente — senza ricaricare il file. Funziona anche per ritentare i piatti falliti.

**Avanzamento visibile.** Durante lo slicing piatto per piatto la barra di lavoro mostra «piatto k/N · percentuale», aggiornata a ogni piatto.

**Selezione più rapida.** Pulsanti **Tutti / Nessuno** per accendere o spegnere tutte le spunte in un colpo; sulle anteprime dei piatti slicati compare la **quota di tempo** del piatto sul totale (es. 38%) al posto del segno di spunta.

**Il file ti porta dove serve.** Trascinando un 3mf in qualsiasi sezione l'app passa da sola a File & Slicing.

### Pacchetti

| Sistema | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.1.5.exe` (installer) — oppure `3D-Print-Cost-Portable-1.1.5.exe` (nessuna installazione) |
| **macOS** | `3D-Print-Cost.dmg` — richiede macOS 26 su Apple Silicon |
| **Browser** | `index.html` nel repository, versione ridotta senza slicing |

Né l'installer Windows né l'app macOS hanno una firma digitale a pagamento: al primo avvio i rispettivi sistemi mostrano un avviso. Le istruzioni per superarlo sono nel README.

### Aggiornamento dalle versioni precedenti

Dalla 1.1.4 l'app segnala da sola le nuove versioni all'avvio. Chi usa la **1.0 deve aggiornare**: verifica lo sblocco col vecchio schema e non è più compatibile con il bot.

---

## 🇺🇸 What's new

**One bad plate no longer sinks the whole file.** In multi-plate projects a single problematic plate (out of the printable area, colliding with the prime tower…) used to fail the entire slicing run. The app now slices plate by plate when needed: good plates add up in the result, unrecoverable ones are listed in a notice and stay dimmed.

**Incremental slicing.** On already-sliced files the dimmed plates stay clickable: select them (orange border) and "Slice (N)" adds them to the existing result — no need to reload the file. It also works to retry failed plates.

**Visible progress.** During plate-by-plate slicing the busy bar shows "plate k/N · percentage", updated at every plate.

**Faster selection.** **All / None** buttons flip every checkmark at once; sliced plate previews show the plate's **share of total print time** (e.g. 38%) instead of a checkmark.

**Files take you where the work is.** Dropping a 3mf on any section jumps straight to Files & Slicing.

### Packages

| System | File |
|---|---|
| **Windows** | `3D-Print-Cost-Setup-1.1.5.exe` (installer) — or `3D-Print-Cost-Portable-1.1.5.exe` (no installation) |
| **macOS** | `3D-Print-Cost.dmg` — requires macOS 26 on Apple Silicon |
| **Browser** | `index.html` in the repository, lite version without slicing |

Neither the Windows installer nor the macOS app carries a paid code-signing certificate: on first launch each system shows a warning. The README explains how to get past it.

### Upgrading from previous versions

Since 1.1.4 the app announces new versions by itself at startup. Anyone still on **1.0 must update**: it verifies the unlock with the old scheme and no longer works with the bot.
