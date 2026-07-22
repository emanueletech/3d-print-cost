# Costo Stampa 3D · 3D Print Cost

**IT** — Web app per calcolare tempi, materiale per colore e costo della corrente delle stampe 3D a partire dai file `.3mf` già slicati (Bambu Studio / OrcaSlicer).

- Trascina uno o più `.3mf` slicati nella pagina
- Scegli la stampante: i campi (potenza media) si precompilano
- Imposta il costo dell'energia (€/kWh) e i prezzi delle bobine
- Ottieni: tempo totale, grammi per colore, bobine da comprare, costo corrente e totale

**EN** — Web app to work out print time, filament per color and electricity cost of 3D prints from already-sliced `.3mf` files (Bambu Studio / OrcaSlicer).

- Drop one or more sliced `.3mf` files onto the page
- Pick your printer: fields (average wattage) get pre-filled
- Set your energy cost (€/kWh) and spool prices
- Get: total time, grams per color, spools to buy, electricity cost and grand total

## Uso / Usage

Apri `index.html` nel browser (doppio click) oppure attiva GitHub Pages sul repo.

Open `index.html` in your browser (double click) or enable GitHub Pages on the repo.

## Note

- I tempi e i grammi vengono letti dal 3mf slicato (`Metadata/slice_info.config`): l'app non slica da sola.
- La potenza media per stampante è indicativa: misurala con una presa smart per la massima precisione.
- Print times and grams are read from the sliced 3mf (`Metadata/slice_info.config`): the app does not slice by itself.
- Per-printer average wattage is indicative: measure with a smart plug for best accuracy.
