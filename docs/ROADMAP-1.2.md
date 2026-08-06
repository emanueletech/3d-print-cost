# Roadmap v1.2 — La stampante comanda lo slicer · The printer drives the slicer

**IT** — Obiettivo: selezionata una stampante, lo slicing integrato usa il **suo** slicer e i **suoi** profili, con numeri fedeli alla macchina reale (letto, spurghi, limiti). Oggi tutto è cablato su Bambu Studio + profilo H2C.

**EN** — Goal: once a printer is selected, in-app slicing uses **its** slicer and **its** profiles, with numbers true to the real machine (bed, purges, limits). Today everything is hardwired to Bambu Studio + the H2C profile.

---

## 🇮🇹 Architettura

### Una famiglia, un motore
Bambu Studio, OrcaSlicer, ElegooSlicer e Snapmaker Orca discendono tutti dallo stesso codice: stessa CLI (`--load-settings`, `--load-filaments`, `--slice`, `--export-3mf`), stesso formato dei profili (JSON con catene `inherits`), stesso 3mf con `slice_info.config`. La v1.2 costruisce **un solo motore "famiglia Orca"** parametrizzato, non quattro integrazioni.

### Componenti

1. **Modello dati** — `PrinterProfile` guadagna `slicing`: marca/vendor, nome del profilo macchina (es. "Bambu Lab X1 Carbon 0.4 nozzle"), motore preferito. Stampanti predefinite già configurate; migrazione per nome sui database esistenti. Si aggiungono al listino le Elegoo (Centauri Carbon, Neptune 4…) con dati di costo.

2. **Scoperta degli slicer installati** — l'app cerca gli slicer della famiglia nei percorsi noti (macOS: `/Applications/*.app`; Windows: percorsi tipici + registro, come già fa per Bambu Studio). Per ciascuno indicizza l'albero dei profili vendor (`Resources/profiles/<Vendor>/…`).

3. **Risoluzione profili a runtime** — niente profili impacchettati per ogni macchina: si leggono dall'installazione dell'utente, si appiattisce la catena `inherits` (merge JSON ricorsivo) e si passano al CLI come file temporanei. Ripiego sull'H2C in bundle se non si trova nulla.

4. **Sonda CLI** — alcune build hanno la CLI rotta (Snapmaker Orca crasha, verificato). Al primo uso l'app fa una prova rapida (slicing di un cubo minimo, esito in cache): CLI sana → slicing automatico; CLI rotta o slicer assente → **ripiego onesto**: pulsante "Apri in <slicer>" + istruzione di esportare il «file del piatto slicato», che l'app legge già per tutta la famiglia.

5. **Remap parametrico** — conoscendo `printable_area` di origine (dal progetto) e destinazione (dal profilo macchina), il riposizionamento sulla griglia smette di assumere P1S→H2C e funziona tra macchine qualsiasi, prime tower inclusa.

6. **Filamenti PLA + PETG + TPU** — il tipo dichiarato dal progetto (`filament_type`) viene mappato sul profilo filamento del motore scelto (es. "Bambu PETG HF @BBL X1C", "Generic TPU @Elegoo…"). Tipi non mappati → si usa il generico del motore, con nota.

7. **Selettore ugello e layer** — nel pannello File & Slicing: ugello (0.2/0.4/0.6/0.8) e altezza layer proposta di conseguenza (es. 0.20 Standard per 0.4). La scelta filtra i profili macchina/processo usati.

8. **UI** — Stampanti: ogni riga mostra il suo slicer e lo stato ("Bambu Studio · X1C 0.4", "Snapmaker Orca · solo lettura export", "—"). File & Slicing: testo dinamico con motore e profilo effettivi.

### Tappe

| | Contenuto | Rischio |
|---|---|---|
| **M1** | Modello dati + migrazione, stampanti Elegoo nel listino, badge in Stampanti, testo dinamico, selettore ugello/layer (cablato sul flusso attuale) | basso |
| **M2** | Motore Bambu generico: profili dall'installazione di Bambu Studio, appiattimento `inherits`, slicing col profilo selezionato, remap parametrico | medio — il pezzo grosso |
| **M3** | Estensione famiglia Orca: scoperta slicer, sonda CLI con cache, ritocco versione 3mf automatico | medio |
| **M4** | Ripiego onesto per slicer assenti/rotti: "Apri in <slicer>" + lettura export | basso |
| **M5** | Mappatura filamenti PETG/TPU | basso |
| **M6** | Rifiniture, test reali (H2C e U1 di casa), release **v1.2.0** | — |

### Rischi dichiarati
- **Elegoo non testabile in prima persona**: niente hardware né slicer a disposizione; il motore generico + la sonda CLI riducono il rischio, il resto arriverà dai riscontri degli utenti.
- **CLI ballerine nei fork**: la sonda con cache e il ripiego onesto (M4) garantiscono che l'app non menta mai — al peggio guida l'utente all'export manuale.
- **Appiattimento `inherits`**: catene anomale o profili mancanti → ripiego sull'H2C in bundle, mai un errore muto.

---

## 🇺🇸 Architecture (summary)

One engine for the whole **Orca family** (Bambu Studio, OrcaSlicer, ElegooSlicer, Snapmaker Orca — same CLI, same profile format, same 3mf). Per-printer `slicing` descriptor with vendor and machine-profile name; installed slicers discovered at runtime; profiles read from the user's installation with `inherits` chains flattened on the fly; a cached **CLI probe** (tiny cube test) decides between automatic slicing and the **honest fallback** ("Open in <slicer>" + read the exported plate file, already supported). Grid remap becomes parametric using source/target `printable_area`. Filament mapping covers PLA, PETG and TPU; nozzle (0.2–0.8) and layer height selectable in the slicing panel. Milestones M1–M6 as per the table above; declared risks: Elegoo untested first-hand, flaky fork CLIs (mitigated by probe + fallback), inheritance edge cases (mitigated by bundled H2C fallback).
