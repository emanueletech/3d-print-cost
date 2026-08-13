# Roadmap v1.3 — Confronto, storico, preventivi / Comparison, history, quotes

## 🇮🇹 Obiettivo

La v1.2 ha insegnato all'app a slicare con i profili veri della stampante scelta.
La v1.3 usa quel motore per rispondere a tre domande che ogni maker si fa:

1. **«Con quale stampante mi conviene stamparlo?»** → Confronto stampanti
2. **«Quanto ho speso questo mese?»** → Storico e registro costi
3. **«Quanto lo faccio pagare?»** → Preventivo per clienti

### M1 — Confronto stampanti

Sulla scheda di un file slicato compare il pulsante **⇄**: si sceglie un'altra
stampante Bambu e l'app rislica **gli stessi piatti** coi profili di quella
macchina (stesso ugello e layer). Il risultato è una tabella a due colonne:

- tempo di stampa, grammi, kWh;
- ogni voce del costo reale (materiale, energia, usura, avvii, fallimenti);
- totale con l'evidenza su chi costa meno e la frase «Con X spendi Y in meno (−Z%)».

La colonna della stampante attuale usa i numeri già in scheda; l'altra colonna
esce da uno slicing vero, piatto per piatto, con il salvataggio per-piatto della
v1.1.5 (i piatti che non entrano nel letto della seconda macchina vengono
dichiarati, non nascosti). Il calcolo del costo per singolo file è estratto nel
modulo condiviso `renderer/cost.js`, coperto dai test.

### M2 — Storico e registro costi

Ogni analisi può essere **salvata nel registro**: data, file, stampante,
piatti, grammi, ore e costo scomposto. Il registro vive nello store locale
(niente cloud) e alimenta:

- totali per mese (spesa, ore, kg);
- elenco progetti con costo per progetto;
- **export CSV** per fogli di calcolo e contabilità.

### M3 — Preventivo per clienti

Dal costo reale di un progetto si genera un **preventivo presentabile**:
margine configurabile (percentuale o importo), voci mostrate/nascoste a scelta,
intestazione con nome/logo dell'attività, note e validità. Output: PDF (o
immagine) pronto da mandare al cliente, nelle 4 lingue dell'app.

### Ordine e criteri

M1 → M2 → M3: il confronto riusa il motore v1.2 così com'è, lo storico
introduce la persistenza che i preventivi poi riusano (dati progetto, intestazione).
Come sempre: stesse funzioni su Electron (Win/Linux) e app nativa macOS,
4 lingue, test Node per la logica pura, niente dipendenze nuove.

---

## 🇺🇸 Goal

v1.2 taught the app to slice with the real profiles of the chosen printer.
v1.3 uses that engine to answer three questions every maker asks:

1. **"Which of my printers should print this?"** → Printer comparison
2. **"How much did I spend this month?"** → Cost history & log
3. **"What should I charge for it?"** → Customer quotes

### M1 — Printer comparison

Sliced file cards gain a **⇄** button: pick another Bambu printer and the app
re-slices **the same plates** with that machine's profiles (same nozzle and
layer). The result is a two-column table:

- print time, grams, kWh;
- every real-cost item (material, energy, wear, setup, failures);
- totals with the cheaper printer highlighted and the sentence
  "With X you spend Y less (−Z%)".

The current printer's column uses the numbers already on the card; the other
column comes from a real slice, plate by plate, with v1.1.5's per-plate salvage
(plates that don't fit the second machine's bed are declared, not hidden).
Per-file cost math is extracted into the shared `renderer/cost.js` module,
covered by tests.

### M2 — Cost history & log

Any analysis can be **saved to the log**: date, file, printer, plates, grams,
hours and the cost breakdown. The log lives in the local store (no cloud) and
feeds:

- monthly totals (spend, hours, kg);
- a project list with per-project cost;
- **CSV export** for spreadsheets and bookkeeping.

### M3 — Customer quotes

From a project's real cost the app generates a **presentable quote**:
configurable margin (percent or amount), items shown/hidden at will, a header
with your business name/logo, notes and validity. Output: a PDF (or image)
ready to send to the customer, in all 4 app languages.

### Order and ground rules

M1 → M2 → M3: the comparison reuses the v1.2 engine as-is; the history
introduces the persistence that quotes later reuse (project data, header).
As always: same features on Electron (Win/Linux) and the native macOS app,
4 languages, Node tests for the pure logic, no new dependencies.
