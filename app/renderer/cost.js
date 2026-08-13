/*
 * Costo di stampa di un singolo insieme di piatti per una data stampante.
 * Modulo puro: lo usa il confronto stampanti nel renderer (window.CostLib)
 * e gira anche sotto Node per i test (module.exports).
 */
'use strict';

(() => {
  /**
   * Scompone il costo dei piatti passati con i parametri di UNA stampante.
   * plates: [{seconds, grams, colorGrams:{"#HEX|Tipo": g}}]
   * opts:   {watts, wearPerHour, setupCost, kwh, failurePct, perKg(hex, type)}
   * → {seconds, grams, perColor, kWh, material, energy, wear, setup, base, failure, total, plates}
   */
  function breakdown(plates, opts) {
    const perColor = {};
    let seconds = 0;
    let grams = 0;
    for (const p of plates) {
      seconds += p.seconds || 0;
      grams += p.grams || 0;
      for (const [k, g] of Object.entries(p.colorGrams || {})) perColor[k] = (perColor[k] || 0) + g;
    }
    let material = 0;
    for (const [k, g] of Object.entries(perColor)) {
      const [hex, type = 'PLA Basic'] = k.split('|');
      material += (g / 1000) * opts.perKg(hex, type);
    }
    const hours = seconds / 3600;
    const kWh = (hours * (opts.watts || 0)) / 1000;
    const energy = kWh * (opts.kwh || 0);
    const wear = hours * (opts.wearPerHour || 0);
    const setup = plates.length * (opts.setupCost || 0);
    const base = material + energy + wear + setup;
    const failure = (base * (opts.failurePct || 0)) / 100;
    return {
      seconds, grams, perColor, kWh,
      material, energy, wear, setup, base, failure,
      total: base + failure,
      plates: plates.length,
    };
  }

  const api = { breakdown };
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.CostLib = api;
})();
