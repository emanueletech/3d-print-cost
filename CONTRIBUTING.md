# Contribuire / Contributing

## 🇮🇹 Italiano

Grazie di voler dare una mano. Costo Stampa 3D è pubblico: puoi leggerlo, compilarlo da te e migliorarlo. Il progetto è mantenuto da una persona sola, quindi le richieste si lavorano **una alla volta**, in ordine di arrivo.

### Una modifica alla volta

- **Una issue = una richiesta.** Un bug, una proposta, una domanda. Tre idee? Tre issue.
- **Una pull request = una modifica.** Una PR piccola e chiara si integra prima di una grande che tocca dieci cose insieme; quelle verranno rimandate indietro da dividere.
- **Per le modifiche grosse, prima l'issue.** Apri una discussione e aspettane l'esito prima di investire ore nel codice.

### Come aiutare

- Correggere un bug. Le parti che contano di più sono lo slicing (`app/lib/slicer.js` e `native/Sources/Model.swift`) e la lettura dei 3mf (`app/lib/threemf.js`).
- Migliorare la documentazione: se un passaggio ti ha fatto perdere tempo, scriverlo nel README vale quanto una correzione al codice.
- Rifinire le traduzioni: i testi vivono in `app/renderer/i18n.js` e in `Loc` dentro `native/Sources/App.swift`, in 4 lingue (it/en/es/fr).
- Aggiungere test: la suite gira con `npm test`, solo Node, senza Electron.

### Ambiente di sviluppo

```bash
# app Windows/Linux (Electron)
cd app
npm install
npm start

# app macOS (SwiftUI nativa) — richiede macOS 26 su Apple Silicon
native/build.sh
```

### Prima di aprire una pull request

Parti da `main`, tieni la modifica concentrata su una cosa sola e assicurati che:

- `npm test` passi (dalla cartella `app/`);
- una funzione visibile all'utente sia implementata in **entrambe** le app (renderer Electron *e* viste SwiftUI);
- ogni testo nuovo esista nelle **4 lingue**, in entrambi i file;
- non ci siano **dipendenze nuove**: il progetto non usa librerie esterne e vuole restare così.

Se un controllo non può girare nel tuo ambiente, spiega perché nel corpo della PR.

### Una nota sul codice

Le convenzioni del repository sono scritte in `AGENTS.md`. Commenti e messaggi di commit sono in italiano, nello stile di quelli esistenti; i numeri mostrati all'utente devono essere veri (se l'app non può calcolare una cosa, lo dice — non la inventa).

### Segnalare un bug

Apri una issue con cosa hai fatto, cosa ti aspettavi e cosa è successo. Indica sistema e versione dell'app (es. macOS 26 / v1.3.0), la stampante selezionata e, se c'entra lo slicing, la versione di Bambu Studio. Su macOS le ultime righe di `~/Library/Logs/3DPrintCost-slicer.log` dicono quasi sempre tutto.

---

## 🇺🇸 English

Thanks for wanting to help. 3D Print Cost is public: you can read it, build it yourself and improve it. The project is maintained by one person, so requests are worked on **one at a time**, in order of arrival.

### One change at a time

- **One issue = one request.** One bug, one proposal, one question. Three ideas? Three issues.
- **One pull request = one change.** A small, clear PR gets merged sooner than a large one touching ten things at once; those will be sent back to be split.
- **For big changes, issue first.** Open a discussion and wait for its outcome before investing hours in code.

### Ways to help

- Fix a bug. The parts that matter most are slicing (`app/lib/slicer.js` and `native/Sources/Model.swift`) and 3mf reading (`app/lib/threemf.js`).
- Improve the docs: if a step cost you time, writing it into the README is as valuable as a code fix.
- Polish the translations: strings live in `app/renderer/i18n.js` and in `Loc` inside `native/Sources/App.swift`, in 4 languages (it/en/es/fr).
- Add tests: the suite runs with `npm test`, Node only, no Electron.

### Development setup

```bash
# Windows/Linux app (Electron)
cd app
npm install
npm start

# macOS app (native SwiftUI) — requires macOS 26 on Apple Silicon
native/build.sh
```

### Before you open a pull request

Branch from `main`, keep the change focused on one thing, and make sure that:

- `npm test` passes (from the `app/` folder);
- any user-visible feature lands in **both** apps (Electron renderer *and* SwiftUI views);
- every new string exists in all **4 languages**, in both files;
- there are **no new dependencies**: the project uses no external libraries and intends to stay that way.

If a check cannot run in your environment, say why in the pull request body.

### A note on the codebase

Repository conventions are written in `AGENTS.md`. Code comments and commit messages are in Italian, matching the existing style; numbers shown to the user must be real (when the app cannot compute something, it says so — it doesn't make it up).

### Reporting bugs

Open an issue with what you did, what you expected, and what happened. Include OS and app version (e.g. Windows 11 / v1.3.0), the selected printer and, if slicing is involved, your Bambu Studio version. On macOS the last lines of `~/Library/Logs/3DPrintCost-slicer.log` almost always tell the whole story.

---

## Crediti / Credits

App creata da **Emanuele** — se ti è utile, un follow è il modo migliore per dire grazie 🙌

| | |
|---|---|
| 🐙 GitHub | [@emanueletech](https://github.com/emanueletech) |
| 𝕏 X | [@emanuele_tech](https://x.com/emanuele_tech) |
| 📷 Instagram | [@emanuele_tech](https://www.instagram.com/emanuele_tech) |
| 🧊 MakerWorld | [@Emanuele_tech](https://makerworld.com/en/@Emanuele_tech) |
