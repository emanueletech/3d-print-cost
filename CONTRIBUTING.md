# Contribuire / Contributing

## 🇮🇹 Come contribuire

Grazie dell'interesse! Questo progetto è mantenuto da una persona sola, quindi vale una regola semplice che tiene tutto gestibile:

### ☝️ Una modifica alla volta

- **Una issue = una richiesta.** Un bug, una proposta, una domanda. Se hai tre idee, apri tre issue: verranno lette e lavorate **una alla volta**, in ordine di arrivo.
- **Una pull request = una modifica.** Piccola, mirata, con un titolo che dice cosa cambia. Le PR che toccano dieci cose insieme verranno rimandate indietro con la richiesta di dividerle.
- **Prima l'issue, poi il codice** per le modifiche grosse: apri una issue e aspettane l'esito prima di investire ore in una PR che magari non rientra nei piani.

### Segnalare un bug

Apri una issue con:

- sistema operativo e versione dell'app (es. macOS 26 / v1.3.0);
- stampante selezionata e, se c'entra lo slicing, la versione di Bambu Studio;
- i passi per riprodurre il problema e cosa ti aspettavi;
- su macOS, se lo slicing fallisce, le ultime righe di `~/Library/Logs/3DPrintCost-slicer.log`.

### Proporre una funzione

Una proposta per issue, con il caso d'uso reale: a che problema risponde, come te la immagini. Le proposte oneste su cosa l'app può e non può fare hanno la precedenza (qui non si inventano numeri).

### Sviluppo

- **App Windows/Linux (Electron)**: `cd app && npm install && npm start`. Prima di ogni PR: `npm test` — i test devono restare tutti verdi.
- **App macOS (SwiftUI nativa)**: `native/build.sh` — richiede macOS 26 su Apple Silicon.
- **Le due app vanno a braccetto**: una funzione visibile all'utente va implementata in entrambe (renderer Electron *e* viste SwiftUI).
- **4 lingue**: ogni testo nuovo va aggiunto in it/en/es/fr, sia in `app/renderer/i18n.js` che in `Loc` dentro `native/Sources/App.swift`.
- **Zero dipendenze nuove**: il progetto non usa librerie esterne e vuole restare così.
- Commenti nel codice e messaggi di commit in italiano, nello stile di quelli esistenti.

---

## 🇺🇸 How to contribute

Thanks for your interest! This project is maintained by one person, so one simple rule keeps everything manageable:

### ☝️ One change at a time

- **One issue = one request.** One bug, one proposal, one question. If you have three ideas, open three issues: they will be read and worked on **one at a time**, in order of arrival.
- **One pull request = one change.** Small, focused, with a title that says what changes. PRs touching ten things at once will be sent back with a request to split them.
- **Issue first, code later** for big changes: open an issue and wait for its outcome before investing hours in a PR that may not fit the plans.

### Reporting a bug

Open an issue with:

- operating system and app version (e.g. Windows 11 / v1.3.0);
- the selected printer and, if slicing is involved, your Bambu Studio version;
- steps to reproduce and what you expected;
- on macOS, if slicing fails, the last lines of `~/Library/Logs/3DPrintCost-slicer.log`.

### Proposing a feature

One proposal per issue, with the real use case: what problem it solves, how you picture it. Proposals that are honest about what the app can and cannot do get priority (no made-up numbers here).

### Development

- **Windows/Linux app (Electron)**: `cd app && npm install && npm start`. Before any PR: `npm test` — all tests must stay green.
- **macOS app (native SwiftUI)**: `native/build.sh` — requires macOS 26 on Apple Silicon.
- **The two apps move together**: a user-visible feature must land in both (Electron renderer *and* SwiftUI views).
- **4 languages**: every new string goes in it/en/es/fr, both in `app/renderer/i18n.js` and in `Loc` inside `native/Sources/App.swift`.
- **Zero new dependencies**: the project uses no external libraries and intends to stay that way.
- Code comments and commit messages in Italian, matching the existing style.
