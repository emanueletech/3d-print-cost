/*
 * Costo Stampa 3D — renderer.
 * Stesso modello di costo e stesse sezioni dell'app macOS (App.swift/Views.swift),
 * riscritte per Electron così girano identiche su Windows.
 */
'use strict';

// racchiuso in una funzione: nel renderer gli script condividono lo scope globale
// (window.api e window.MeshLib sono già lì e i nomi si scontrerebbero)
(() => {

  const { tr, fmt, LANGS } = window.I18N;
  const api = window.api;
  const $ = (sel, root = document) => root.querySelector(sel);

  /* ---------- costanti ---------- */

  const CURRENCIES = {
    eur: { symbol: '€', code: 'EUR', locale: 'it-IT', rate: 1.0 },
    gbp: { symbol: '£', code: 'GBP', locale: 'en-GB', rate: 0.8532 },
    usd: { symbol: '$', code: 'USD', locale: 'en-US', rate: 1.1392 },
    chf: { symbol: 'CHF', code: 'CHF', locale: 'de-CH', rate: 0.9295 },
  };

  // palette ufficiale Bambu: dà il nome commerciale a partire dall'esadecimale
  const FILAMENT_NAMES = {
    'PLA Basic': {
      '#FFFFFF': 'Jade White', '#000000': 'Black', '#C12E1F': 'Red', '#0A2989': 'Blue',
      '#8E9089': 'Gray', '#00AE42': 'Bambu Green', '#3F8E43': 'Mistletoe Green', '#0086D6': 'Cyan',
      '#FEC600': 'Sunflower Yellow', '#482960': 'Indigo Purple', '#6F5034': 'Cocoa Brown',
      '#F5547C': 'Hot Pink', '#FF9016': 'Pumpkin Orange', '#E4BD68': 'Gold', '#5E43B7': 'Purple',
      '#0056B8': 'Cobalt Blue', '#F55A74': 'Pink', '#D3B7A7': 'Beige',
    },
    'PLA Matte': {
      '#FFFFFF': 'Ivory White', '#CBC6B8': 'Bone White', '#E8DBB7': 'Desert Tan',
      '#D3B7A7': 'Latte Brown', '#AE835B': 'Caramel', '#B15533': 'Terracotta',
      '#7D6556': 'Dark Brown', '#4D3324': 'Dark Chocolate', '#AE96D4': 'Lilac Purple',
      '#E8AFCF': 'Sakura Pink', '#F99963': 'Mandarin Orange', '#F7D959': 'Lemon Yellow',
      '#950051': 'Plum', '#DE4343': 'Scarlet Red', '#BB3D43': 'Dark Red', '#68724D': 'Dark Green',
      '#61C680': 'Grass Green', '#C2E189': 'Apple Green', '#A3D8E1': 'Ice Blue',
      '#56B7E6': 'Sky Blue', '#0078BF': 'Marine Blue', '#042F56': 'Dark Blue',
      '#9B9EA0': 'Ash Gray', '#757575': 'Nardo Gray', '#000000': 'Charcoal',
    },
  };

  const SECTIONS = [
    { id: 'overview', key: 'nOverview', icon: '▦', group: 'project' },
    { id: 'files', key: 'nFiles', icon: '🗂', group: 'project' },
    { id: 'orient', key: 'nOrient', icon: '🧭', group: 'project' },
    { id: 'colors', key: 'nColors', icon: '🎨', group: 'project' },
    { id: 'plates', key: 'nPlates', icon: '🧩', group: 'project' },
    { id: 'materials', key: 'nMaterials', icon: '🧵', group: 'settings' },
    { id: 'printers', key: 'nPrinters', icon: '🖨', group: 'settings' },
    { id: 'setup', key: 'nSetup', icon: '⚙️', group: 'settings' },
  ];

  const POSE_LABELS = {
    orig: { it: 'Originale', en: 'Original', es: 'Original', fr: 'Originale' },
    xDown: { it: '+X giù', en: '+X down', es: '+X abajo', fr: '+X en bas' },
    xUp: { it: '−X giù', en: '−X down', es: '−X abajo', fr: '−X en bas' },
    yDown: { it: '+Y giù', en: '+Y down', es: '+Y abajo', fr: '+Y en bas' },
    yUp: { it: '−Y giù', en: '−Y down', es: '−Y abajo', fr: '−Y en bas' },
    headDown: { it: 'Testa giù', en: 'Head down', es: 'Cabeza abajo', fr: 'Tête en bas' },
    baseDown: { it: 'Base giù', en: 'Base down', es: 'Base abajo', fr: 'Base en bas' },
  };

  const AUTHOR = {
    instagram: 'https://www.instagram.com/emanuele_tech',
    telegram: 'https://t.me/emanueletech',
    makerworld: 'https://makerworld.com/en/@Emanuele_tech',
    youtube: 'https://youtube.com/@emanuele_tech',
  };
  const AMAZON_TAG = 'emanueleesp-21';
  const SETUP_MIN = 8; // minuti di riscaldamento/calibrazione risparmiati per avvio evitato

  /* ---------- stato ---------- */

  const M = {
    section: 'overview',
    lang: 'it',
    store: null,
    files: [],
    busy: null,
    bambu: '',
    // orientamento 3D
    meshName: null,
    baseMesh: null,
    mesh: null,
    poses: [],
    chosenPose: null,
    supportThreshold: 45,
  };

  let viewer = null;
  let seq = 0;

  /* ---------- utilità ---------- */

  const t = (k) => tr(k, M.lang);
  const esc = (s) =>
    String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

  function hms(sec) {
    const h = Math.floor(sec / 3600);
    const m = Math.round((sec % 3600) / 60);
    return h > 0 ? `${h}h ${String(m).padStart(2, '0')}m` : `${m}m`;
  }

  /** formatta un importo in EUR nella valuta scelta (i prezzi interni restano in euro) */
  function eur(v) {
    const c = CURRENCIES[M.store.currency] || CURRENCIES.eur;
    const rate = Number(M.store.eurRate) || 1;
    try {
      return new Intl.NumberFormat(c.locale, { style: 'currency', currency: c.code }).format(v * rate);
    } catch {
      return `${c.symbol}${(v * rate).toFixed(2)}`;
    }
  }

  function num(v, fallback = 0) {
    const n = parseFloat(String(v).replace(',', '.'));
    return Number.isFinite(n) ? n : fallback;
  }

  function filamentName(hex, type) {
    const table = FILAMENT_NAMES[/matte/i.test(type) ? 'PLA Matte' : 'PLA Basic'];
    return table[String(hex).toUpperCase()] || hex;
  }

  function amazonURL(query) {
    const u = new URL('https://www.amazon.it/s');
    u.searchParams.set('k', query);
    u.searchParams.set('tag', AMAZON_TAG);
    return u.toString();
  }

  let persistTimer = null;
  function persist() {
    clearTimeout(persistTimer);
    persistTimer = setTimeout(() => api.saveStore(M.store), 250);
  }

  function toast(msg, spin = false) {
    const el = $('#toast');
    el.innerHTML = (spin ? '<span class="spin"></span>' : '') + esc(msg);
    el.hidden = false;
    clearTimeout(toast.timer);
    if (!spin) toast.timer = setTimeout(() => (el.hidden = true), 4000);
  }

  function setBusy(text) {
    M.busy = text;
    const el = $('#busy');
    el.hidden = !text;
    if (text) el.innerHTML = `<span class="spin"></span>${esc(text)}`;
  }

  /* ---------- modello di costo ---------- */

  const loadedFiles = () => M.files.filter((f) => f.analysis);
  const includedPlates = () =>
    loadedFiles().flatMap((f) => f.analysis.plates.filter((p) => !f.excluded.has(p.index)));

  const totalSeconds = () => includedPlates().reduce((s, p) => s + p.seconds, 0);
  const totalGrams = () => includedPlates().reduce((s, p) => s + p.grams, 0);
  const totalPlates = () => includedPlates().length;
  const totalHours = () => totalSeconds() / 3600;

  function colorRows() {
    const per = {};
    for (const p of includedPlates())
      for (const [k, g] of Object.entries(p.colorGrams)) per[k] = (per[k] || 0) + g;
    return Object.entries(per)
      .map(([k, grams]) => {
        const [hex, type = 'PLA Basic'] = k.split('|');
        return { hex, type, grams, spools: Math.max(1, Math.ceil(grams / 1000)), name: filamentName(hex, type) };
      })
      .sort((a, b) => b.grams - a.grams);
  }

  const totalSpools = () => colorRows().reduce((s, r) => s + r.spools, 0);

  /** prezzo per bobina: gli sconti quantità Bambu scattano sul totale bobine */
  function unitPrice() {
    const s = M.store;
    const tier = () => {
      const n = totalSpools();
      if (n >= 10) return [0.5, t('t10')];
      if (n >= 6) return [0.55, t('t6')];
      if (n >= 4) return [0.65, t('t4')];
      return [1.0, t('full')];
    };
    if (s.source === 'other') return { price: num(s.otherPrice), label: s.otherBrand || t('srcOther') };
    const [mult, label] = tier();
    const base = s.source === 'bambuSpool' ? num(s.spoolPrice) : num(s.msrp);
    return { price: base * mult, label: `${s.source === 'bambuSpool' ? t('srcSpool') : t('srcRefill')} · ${label}` };
  }

  const filamentCost = () => totalSpools() * unitPrice().price;
  const kWhUsed = () => (totalSeconds() / 3600) * selectedPrinter().watts / 1000;
  const energyCost = () => kWhUsed() * num(M.store.kwh);

  function selectedPrinter() {
    const list = M.store.printers;
    return list.find((p) => p.name === M.store.selPrinter) || list[0] || { name: '—', watts: 120, wearPerHour: 0, setupCost: 0 };
  }

  function hexToRGB(hex) {
    let s = String(hex).replace('#', '').trim();
    if (s.length === 3) s = s.split('').map((c) => c + c).join('');
    if (s.length !== 6) return null;
    const v = parseInt(s, 16);
    return Number.isFinite(v) ? [(v >> 16) & 255, (v >> 8) & 255, v & 255] : null;
  }

  /**
   * Materiale abbinato a un colore del progetto: match esatto sull'esadecimale,
   * altrimenti il colore più vicino (preferendo lo stesso tipo) entro una soglia.
   */
  function materialFor(hex, type) {
    const up = String(hex).toUpperCase();
    const mats = M.store.materials;
    const exact = mats.find((m) => m.colorHex.toUpperCase() === up && m.type === type);
    if (exact) return exact;
    const sameHex = mats.find((m) => m.colorHex.toUpperCase() === up);
    if (sameHex) return sameHex;

    const c = hexToRGB(up);
    if (!c) return null;
    let best = null;
    for (const m of mats) {
      const mc = hexToRGB(m.colorHex);
      if (!mc) continue;
      let d = (c[0] - mc[0]) ** 2 + (c[1] - mc[1]) ** 2 + (c[2] - mc[2]) ** 2;
      if (m.type !== type) d += 1200; // penalità per tipo diverso
      if (!best || d < best.d) best = { m, d };
    }
    return best && best.d < 4800 ? best.m : null;
  }

  function effectiveCostPerKg(m) {
    const sale = num(m.salePrice, 0);
    const list = num(m.costPerKg, 0);
    return sale > 0 && sale < list ? sale : list;
  }
  const onSale = (m) => num(m.salePrice, 0) > 0 && num(m.salePrice, 0) < num(m.costPerKg, 0);

  function fallbackCostPerKg() {
    const s = M.store;
    if (s.source === 'bambuSpool') return num(s.spoolPrice);
    if (s.source === 'other') return num(s.otherPrice);
    return num(s.msrp);
  }

  /** Costo reale della stampa: materiale consumato + energia + usura + setup + fallimenti. */
  function costBreakdown() {
    const b = { material: 0, energy: 0, wear: 0, setup: 0, failure: 0, spools: 0 };
    for (const r of colorRows()) {
      const m = materialFor(r.hex, r.type);
      b.material += (r.grams / 1000) * (m ? effectiveCostPerKg(m) : fallbackCostPerKg());
    }
    b.energy = energyCost();
    const p = selectedPrinter();
    b.wear = totalHours() * num(p.wearPerHour);
    b.setup = totalPlates() * num(p.setupCost);
    b.base = b.material + b.energy + b.wear + b.setup;
    b.failure = (b.base * num(M.store.failurePct)) / 100;
    b.total = b.base + b.failure;
    b.spools = filamentCost();
    return b;
  }

  /** piatti leggeri dello stesso colore accorpabili su un piatto H2C */
  function mergeAdvice() {
    const out = [];
    for (const f of loadedFiles()) {
      const groups = {};
      for (const p of f.analysis.plates) {
        if (f.excluded.has(p.index)) continue;
        if (p.seconds > 6 * 3600 && p.grams > 300) continue; // piatto già pieno
        const key = Object.keys(p.colorGrams).sort().join('+') || 'x';
        (groups[key] = groups[key] || []).push(p);
      }
      for (const [key, plates] of Object.entries(groups)) {
        if (plates.length < 2) continue;
        const target = Math.max(1, Math.ceil(plates.length / 3)); // ~3 piatti piccoli per piatto H2C
        out.push({
          file: f.name.replace(/\.3mf$/i, ''),
          colors: key === 'x' ? [] : key.split('+'),
          from: plates.map((p) => p.index),
          to: target,
          saved: (plates.length - target) * SETUP_MIN,
        });
      }
    }
    return out.sort((a, b) => b.saved - a.saved);
  }

  /* ---------- caricamento file ---------- */

  async function addPaths(paths) {
    for (const p of paths) {
      if (!/\.3mf$/i.test(p)) continue;
      const name = p.split(/[\\/]/).pop();
      if (M.files.some((f) => f.path === p)) {
        toast(fmt(t('errAlready'), name));
        continue;
      }
      const res = await api.analyze(p);
      if (res.error === 'not3mf') {
        toast(fmt(t('errNot3mf'), name));
        continue;
      }
      const file = {
        id: ++seq,
        name,
        path: p,
        analysis: res.error ? null : res,
        excluded: new Set(),
        thumbs: [],
      };
      M.files.push(file);
      if (res.error === 'notSliced') toast(fmt(t('errNotSliced'), name));
      render();
      // le anteprime dei piatti arrivano dopo, senza bloccare l'interfaccia
      api.thumbnails(p).then((thumbs) => {
        file.thumbs = thumbs || [];
        if (M.section === 'files') render();
      });
    }
  }

  async function sliceFile(file) {
    setBusy(fmt(t('busy'), file.name));
    // un solo piatto selezionato tra tanti → si slica solo quello
    const total = file.thumbs.length;
    const included = [];
    for (let i = 1; i <= total; i++) if (!file.excluded.has(i)) included.push(i);
    const plate = total > 1 && included.length === 1 ? included[0] : 0;
    const res = await api.slice(file.path, plate);
    setBusy(null);
    if (res.error === 'noBambu') return toast(t('bambuMissing'));
    if (res.error) return toast(fmt(t('errSliceFail'), file.name));
    file.analysis = res;
    toast(fmt(t('okSliced'), file.name));
    render();
  }

  /* ---------- viste ---------- */

  function card(inner, cls = '', attrs = '') {
    return `<div class="card ${cls}" ${attrs}>${inner}</div>`;
  }

  function statCard({ icon, tint, k, v, d = '', goto = null, pop = null }) {
    const act = pop ? `data-pop="${pop}"` : goto ? `data-goto="${goto}"` : 'disabled';
    return `<button class="card stat${pop || goto ? ' link' : ''}" ${act}>
      <div class="stat-top"><span class="pill" style="--tint:${tint}">${icon}</span>${pop || goto ? '<span class="chev">›</span>' : ''}</div>
      <div class="k">${esc(k)}</div><div class="v">${esc(v)}</div>
      ${d ? `<div class="d" style="color:${tint}">${esc(d)}</div>` : ''}
    </button>`;
  }

  /** Dettaglio per colore delle schede Materiale: grammi esatti o spesa esatta. */
  function showStatPop(kind) {
    const items = colorRows()
      .map((r) => {
        let val;
        if (kind === 'grams') val = r.grams < 1000 ? `${Math.round(r.grams)} g` : `${(r.grams / 1000).toFixed(3)} kg`;
        else {
          const m = materialFor(r.hex, r.type);
          val = eur((r.grams / 1000) * (m ? effectiveCostPerKg(m) : fallbackCostPerKg()));
        }
        return `<div class="pop-row"><i style="background:${r.hex}"></i><span>${esc(r.name)}</span><b>${esc(val)}</b></div>`;
      })
      .join('');
    const ov = document.createElement('div');
    ov.className = 'pop-overlay';
    ov.innerHTML = `<div class="pop-card"><div class="k">${esc(kind === 'grams' ? t('kMat') : t('matReal'))}</div>${items}</div>`;
    ov.addEventListener('click', (e) => {
      if (e.target === ov) ov.remove();
    });
    document.body.appendChild(ov);
  }

  function viewOverview() {
    const loaded = loadedFiles();
    const rows = colorRows();
    const c = costBreakdown();
    const sub = loaded.length
      ? `${loaded.length} ${t('files')} · ${totalPlates()} ${t('kPlates').toLowerCase()} · ${esc(selectedPrinter().name)}`
      : t('dropStart');
    const dash = loaded.length ? null : '—';

    const cards = [
      statCard({ icon: '⏱', tint: '#4aa3ff', k: t('kTime'), v: dash || `${Math.floor(totalSeconds() / 3600)} h`,
        d: loaded.length ? `≈ ${Math.ceil(totalSeconds() / 86400)} ${t('days')}` : '', goto: loaded.length ? 'plates' : null }),
      statCard({ icon: '🧱', tint: '#b48cff', k: t('kMat'), v: dash || `${(totalGrams() / 1000).toFixed(1)} kg`,
        d: rows.length ? `${rows.length} ${t('colors')}` : '', pop: loaded.length ? 'grams' : null }),
      statCard({ icon: '💶', tint: '#43d17a', k: t('matReal'), v: dash || eur(c.material),
        d: loaded.length ? t('matUsed') : '', pop: loaded.length ? 'cost' : null }),
      statCard({ icon: '🧻', tint: '#2fd4c8', k: t('kSpools'), v: dash || String(totalSpools()),
        d: loaded.length ? `${eur(filamentCost())} · ${t('ifBuy')}` : '', goto: loaded.length ? 'colors' : null }),
      statCard({ icon: '⚡️', tint: '#ff9a4a', k: t('kEnergy'), v: dash || eur(energyCost()),
        d: loaded.length ? `${kWhUsed().toFixed(1)} kWh` : '', goto: loaded.length ? 'setup' : null }),
      statCard({ icon: '▦', tint: '#ff77c2', k: t('kPlates'), v: dash || String(totalPlates()),
        d: loaded.length ? t('nFiles') : '', goto: loaded.length ? 'files' : null }),
    ].join('');

    if (!loaded.length) return `<div class="sub">${esc(sub)}</div><div class="grid3">${cards}</div>`;

    const total = totalGrams() || 1;
    let acc = 0;
    const stops = rows
      .map((r) => {
        const from = (acc / total) * 100;
        acc += r.grams;
        return `${r.hex} ${from.toFixed(1)}% ${((acc / total) * 100).toFixed(1)}%`;
      })
      .join(',');

    const secs = loaded
      .map((f) => ({ f, s: f.analysis.plates.filter((p) => !f.excluded.has(p.index)).reduce((a, p) => a + p.seconds, 0) }))
      .filter((x) => x.s > 0)
      .sort((a, b) => b.s - a.s);
    const maxS = secs[0] ? secs[0].s : 1;

    const costRow = (key, v, tint) => `<div class="cost-row">
        <span class="dot" style="background:${tint}"></span><span class="lbl">${esc(t(key))}</span>
        <span class="bar"><i style="width:${Math.min(100, (v / Math.max(c.total, 0.01)) * 100).toFixed(1)}%;background:${tint}"></i></span>
        <span class="val">${esc(eur(v))}</span></div>`;

    return `<div class="sub">${esc(sub)}</div>
    <div class="grid3">${cards}</div>
    <div class="grid2 gap">
      ${card(`<div class="k">${esc(t('kByColor'))}</div>
        <div class="donut-wrap"><div class="donut" style="background:conic-gradient(${stops})"></div>
        <div class="donut-hole">${(totalGrams() / 1000).toFixed(1)} kg</div></div>
        <div class="legend">${rows.slice(0, 8).map((r) => `<span><i style="background:${r.hex}"></i>${esc(r.name)}</span>`).join('')}</div>`,
        'link', 'data-goto="colors"')}
      ${card(`<div class="k">${esc(t('kHours'))}</div>
        <div class="spark">${secs.map((x) => `<div class="bar" title="${esc(x.f.name)} — ${hms(x.s)}"><em>${Math.round(x.s / 3600)}h</em><i style="height:${Math.max(4, (x.s / maxS) * 100)}%"></i></div>`).join('')}</div>`,
        'link', 'data-goto="files"')}
    </div>
    ${card(`<div class="k">${esc(t('realCost'))}</div>
      <div class="cost">
        <div class="cost-rows">
          ${costRow('cMaterial', c.material, '#b48cff')}
          ${costRow('cEnergy', c.energy, '#ff9a4a')}
          ${costRow('cWear', c.wear, '#4aa3ff')}
          ${costRow('cSetup', c.setup, '#2fd4c8')}
          ${costRow('cFailure', c.failure, '#ff6b6b')}
        </div>
        <div class="cost-total">
          <div class="k">${esc(t('cTotal'))}</div>
          <div class="big green">${esc(eur(c.total))}</div>
          <div class="k small">${esc(t('cUpfront'))}</div>
          <div class="mid">${esc(eur(c.spools))}</div>
        </div>
      </div>`, 'link', 'data-goto="setup"')}`;
  }

  function viewFiles() {
    const banner = M.bambu
      ? ''
      : `<div class="warn">⚠️ ${esc(t('bambuMissing'))}
          <button class="btn small" data-act="locateBambu">${esc(t('locateBambu'))}</button></div>`;

    const cards = M.files.length
      ? M.files.map(fileCard).join('')
      : card(`<div class="empty">${esc(t('noFiles'))}</div>`);

    return `<div class="sub">${esc(t('sFiles'))}</div>
      ${banner}
      <button class="drop" data-act="pick3mf">⬇︎ ${esc(t('dropHere'))}</button>
      <div class="stack">${cards}</div>`;
  }

  function fileCard(f) {
    const head = f.analysis
      ? (() => {
          const inc = f.analysis.plates.filter((p) => !f.excluded.has(p.index));
          const secs = inc.reduce((s, p) => s + p.seconds, 0);
          const g = inc.reduce((s, p) => s + p.grams, 0);
          const stat = (v, k) => `<div class="fstat"><b>${esc(v)}</b><span>${esc(k)}</span></div>`;
          return (
            stat(`${inc.length}/${f.analysis.plates.length}`, t('thPlates')) +
            stat(hms(secs), t('thTime')) +
            stat(`${Math.round(g)} g`, t('thGrams')) +
            stat(eur((secs / 3600) * selectedPrinter().watts / 1000 * num(M.store.kwh)), t('thEnergy'))
          );
        })()
      : `<button class="btn small primary" data-slice="${f.id}">${esc(t('slice'))}</button>`;

    const thumbs = f.thumbs.length
      ? `<div class="thumbs">${f.thumbs
          .map((src, i) => {
            const on = !f.excluded.has(i + 1);
            return `<button class="thumb${on ? ' on' : ''}" data-plate="${f.id}:${i + 1}">
              <img src="${src}" alt="">
              <span class="tick">${on ? '✓' : ''}</span><span class="idx">${i + 1}</span></button>`;
          })
          .join('')}</div><div class="hint">${esc(t('plateHint'))}</div>`
      : '';

    return card(`<div class="frow">
        <span class="fname">📄 ${esc(f.name)}</span>
        <div class="fstats">${head}</div>
        <button class="x" data-del="${f.id}">✕</button>
      </div>${thumbs}`, 'file');
  }

  function sourcePicker() {
    const s = M.store;
    const seg = ['bambuRefill', 'bambuSpool', 'other']
      .map((v) => `<button class="seg${s.source === v ? ' on' : ''}" data-source="${v}">${esc(t(v === 'bambuRefill' ? 'srcRefill' : v === 'bambuSpool' ? 'srcSpool' : 'srcOther'))}</button>`)
      .join('');

    let body;
    if (s.source === 'other') {
      body = `<div class="row">
        <label class="field"><span>${esc(t('fOtherBrand'))}</span><input type="text" data-store="otherBrand" value="${esc(s.otherBrand)}"></label>
        <label class="field"><span>${esc(t('fOtherPrice'))}</span><input type="number" step="0.5" data-store="otherPrice" data-num="1" value="${esc(s.otherPrice)}"></label>
      </div><div class="note">${esc(t('otherNote'))}</div>`;
    } else {
      const key = s.source === 'bambuSpool' ? 'spoolPrice' : 'msrp';
      body = `<label class="field"><span>${esc(t(s.source === 'bambuSpool' ? 'fSpoolPrice' : 'fMsrp'))}</span>
        <input type="number" step="0.5" data-store="${key}" data-num="1" value="${esc(s[key])}"></label>
        <div class="note">${esc(t('tierNote'))}</div>`;
    }
    return card(`<div class="segbar">${seg}</div>${body}`);
  }

  function viewColors() {
    return `<div class="sub">${esc(t('sColors'))}</div>${sourcePicker()}
      ${card(`<table class="tbl">
        <thead><tr><th>${esc(t('thSpool'))}</th><th class="n">${esc(t('thGrams'))}</th><th class="n">${esc(t('thUsed'))}</th>
        <th class="n">${esc(t('thQty'))}</th><th class="n">${esc(t('thUnit'))}</th><th class="n">${esc(t('thTot'))}</th></tr></thead>
        <tbody id="colorsBody">${colorsBody()}</tbody></table>`, 'pad0')}`;
  }

  function colorsBody() {
    const rows = colorRows();
    if (!rows.length) return `<tr><td colspan="6" class="empty">${esc(t('noColors'))}</td></tr>`;
    const u = unitPrice();
    const usedCost = (r) => {
      const mat = materialFor(r.hex, r.type);
      return (r.grams / 1000) * (mat ? effectiveCostPerKg(mat) : fallbackCostPerKg());
    };
    return (
      rows
        .map(
          (r) => `<tr><td><span class="sw" style="background:${esc(r.hex)}"></span>${esc(r.type)} ${esc(r.name)}</td>
        <td class="n">${Math.round(r.grams)}</td><td class="n dim">${esc(eur(usedCost(r)))}</td><td class="n">${r.spools}</td>
        <td class="n">${esc(eur(u.price))}</td><td class="n b">${esc(eur(r.spools * u.price))}</td></tr>`
        )
        .join('') +
      `<tr class="tot"><td><b>${esc(t('total'))}</b></td><td class="n b">${Math.round(totalGrams())}</td>
        <td class="n b">${esc(eur(costBreakdown().material))}</td>
        <td class="n b">${totalSpools()}</td><td class="n dim">${esc(u.label)}</td><td class="n b green">${esc(eur(filamentCost()))}</td></tr>`
    );
  }

  function viewPlates() {
    const advice = mergeAdvice();
    const body = advice.length
      ? advice
          .map(
            (a) => `<div class="merge">
          <span class="chip">${a.colors.map((k) => `<i class="sw" style="background:${esc(k.split('|')[0])}"></i>`).join('')}${esc(a.file)}</span>
          <span class="chip">${esc(t('thPlates'))} ${a.from.join(', ')}</span><span class="arrow">→</span>
          <span class="chip green">${a.to} H2C</span><span class="gain">−${a.saved} min</span></div>`
          )
          .join('') +
        `<div class="hint">💡 ${esc(t('rule'))} <b>${(advice.reduce((s, a) => s + a.saved, 0) / 60).toFixed(1)} ${esc(t('hours'))}</b></div>`
      : `<div class="empty">${esc(t('noPlates'))}</div>`;
    return `<div class="sub">${esc(t('sPlates'))}</div>${card(body, 'pad0 merges')}`;
  }

  function viewMaterials() {
    const brands = [...new Set(window.PRESETS.map((p) => p.brand))];
    const brand = M.presetBrand || brands[0];
    const types = [...new Set(window.PRESETS.filter((p) => p.brand === brand).map((p) => p.type))];
    const type = types.includes(M.presetType) ? M.presetType : types[0];
    const items = window.PRESETS.filter((p) => p.brand === brand && p.type === type);

    const sel = (id, values, current) =>
      `<select data-preset="${id}">${values.map((v) => `<option value="${esc(v)}"${v === current ? ' selected' : ''}>${esc(v)}</option>`).join('')}</select>`;

    const rows = M.store.materials
      .map(
        (m, i) => `<tr>
        <td><input type="color" data-mat="${i}:colorHex" value="${esc(/^#[0-9a-f]{6}$/i.test(m.colorHex) ? m.colorHex : '#8E9089')}"></td>
        <td><input type="text" data-mat="${i}:name" value="${esc(m.name)}"></td>
        <td><input type="text" class="w90" data-mat="${i}:type" value="${esc(m.type)}"></td>
        <td class="n"><input type="number" step="0.5" class="w70 r" data-mat="${i}:costPerKg" value="${esc(m.costPerKg)}"></td>
        <td class="n sale">${onSale(m) ? `<span class="badge green">${esc(t('onSaleBadge'))}</span>` : ''}
          <input type="number" step="0.5" class="w60 r" placeholder="—" data-mat="${i}:salePrice" value="${m.salePrice != null && m.salePrice > 0 ? esc(m.salePrice) : ''}"></td>
        <td class="n"><input type="number" step="0.01" class="w70 r" data-mat="${i}:densityGcm3" value="${esc(m.densityGcm3)}"></td>
        <td class="n"><input type="number" step="0.1" class="w60 r" data-mat="${i}:stockKg" value="${m.stockKg != null ? esc(m.stockKg) : ''}"></td>
        <td class="n"><button class="x cart" data-buy="${i}" title="${esc(t('amazonSearch'))}">🛒</button>
          <button class="x" data-matdel="${i}">✕</button></td></tr>`
      )
      .join('');

    return `<div class="sub">${esc(t('sMaterials'))}</div>
      <div class="toolbar">
        ${sel('brand', brands, brand)}${sel('type', types, type)}
        <select data-preset="item">${items.map((p, i) => `<option value="${i}">${esc(p.colorName)} · ${p.costPerKg.toFixed(2)} €/kg</option>`).join('')}</select>
        <button class="btn small primary" data-act="addPreset">+ ${esc(t('addMaterial'))}</button>
        <button class="btn small" data-act="addBlank">${esc(t('blankMaterial'))}</button>
        <button class="btn small" data-act="resetMaterials">↺ ${esc(t('resetDefaults'))}</button>
        <span class="spacer"></span>
        <button class="btn small" data-open="https://eu.store.bambulab.com/collections/pla">🏷 Bambu Store</button>
        <button class="btn small" data-open="${esc(amazonURL('filamento stampa 3d 1kg'))}">🏷 ${esc(t('checkOffers'))}</button>
      </div>
      ${card(`<table class="tbl edit"><thead><tr>
        <th>${esc(t('mColor'))}</th><th>${esc(t('mName'))}</th><th>${esc(t('mType'))}</th>
        <th class="n">${esc(t('mCost'))}</th><th class="n">${esc(t('mSale'))}</th>
        <th class="n">${esc(t('mDensity'))}</th><th class="n">${esc(t('mStock'))}</th><th></th>
      </tr></thead><tbody>${rows}</tbody></table>`, 'pad0')}
      <div class="note">${esc(t('offersNote'))}</div>
      <div class="note dim">ⓘ ${esc(t('affiliate'))}</div>`;
  }

  function viewPrinters() {
    const rows = M.store.printers
      .map(
        (p, i) => `<tr>
        <td><button class="radio${M.store.selPrinter === p.name ? ' on' : ''}" data-selprinter="${i}" title="${esc(t('selected'))}"></button></td>
        <td><input type="text" data-prn="${i}:name" value="${esc(p.name)}"></td>
        <td class="n"><input type="number" step="5" class="w80 r" data-prn="${i}:watts" data-num="1" value="${esc(p.watts)}"></td>
        <td class="n"><input type="number" step="0.01" class="w80 r" data-prn="${i}:wearPerHour" data-num="1" value="${esc(p.wearPerHour)}"></td>
        <td class="n"><input type="number" step="0.05" class="w80 r" data-prn="${i}:setupCost" data-num="1" value="${esc(p.setupCost)}"></td>
        <td class="n"><button class="x" data-prndel="${i}">✕</button></td></tr>`
      )
      .join('');

    return `<div class="sub">${esc(t('sPrinters'))}</div>
      <div class="toolbar">
        <button class="btn small primary" data-act="addPrinter">+ ${esc(t('addPrinter'))}</button>
        <button class="btn small" data-act="resetPrinters">↺ ${esc(t('resetDefaults'))}</button>
        <span class="spacer"></span><span class="note">${esc(t('wearHint'))}</span>
      </div>
      ${card(`<table class="tbl edit"><thead><tr><th></th><th>${esc(t('pName'))}</th>
        <th class="n">${esc(t('pWatts'))}</th><th class="n">${esc(t('pWear'))}</th>
        <th class="n">${esc(t('pSetup'))}</th><th></th></tr></thead><tbody>${rows}</tbody></table>`, 'pad0')}`;
  }

  function viewSetup() {
    const s = M.store;
    const printers = s.printers
      .map((p) => `<option value="${esc(p.name)}"${p.name === selectedPrinter().name ? ' selected' : ''}>${esc(p.name)} · ${Math.round(p.watts)} W</option>`)
      .join('');
    const currencies = Object.entries(CURRENCIES)
      .map(([id, c]) => `<option value="${id}"${s.currency === id ? ' selected' : ''}>${c.symbol} ${c.code}</option>`)
      .join('');

    const slicerCard = card(`<div class="k">${esc(t('slicer'))}</div>
      <div class="note">${M.bambu ? `✓ ${esc(t('bambuOk'))}<div class="path">${esc(M.bambu)}</div>` : `⚠️ ${esc(t('bambuMissing'))}`}</div>
      <button class="btn small" data-act="locateBambu">${esc(t('locateBambu'))}</button>`);

    return `<div class="sub">${esc(t('sSetup'))}</div>
    <div class="grid2 gap">
      ${card(`
        <label class="field"><span>${esc(t('fPrinter'))}</span><select data-act="selPrinter">${printers}</select></label>
        <label class="field"><span>${esc(t('fKwh'))}</span><input type="number" step="0.001" data-store="kwh" data-num="1" value="${esc(s.kwh)}"></label>
        <label class="field"><span>${esc(t('fFailure'))}</span>
          <span class="slider"><input type="range" min="0" max="30" step="1" data-store="failurePct" data-num="1" value="${esc(s.failurePct)}">
          <b id="failLbl">${Math.round(s.failurePct)} %</b></span></label>
        <div class="note">${esc(t('failureNote'))}</div>
        <hr>
        <div class="row">
          <label class="field"><span>${esc(t('fCurrency'))}</span><select data-act="currency">${currencies}</select></label>
          <label class="field"><span>${esc(t('fRate'))}</span><input type="number" step="0.0001" data-store="eurRate" data-num="1" value="${esc(s.eurRate)}"></label>
        </div>
        <div class="note">${esc(t('currencyNote'))}</div>`)}
      <div class="stack">
        <div class="k">${esc(t('fSource'))}</div>${sourcePicker()}${slicerCard}
      </div>
    </div>`;
  }

  function viewOrient() {
    const head = `<div class="sub">${esc(t('sOrient'))}</div>
      <div class="toolbar"><button class="btn primary" data-act="pickModel">⬇︎ ${esc(t('loadModel'))}</button>
      ${M.meshName ? `<span class="note">${esc(M.meshName)}</span>` : ''}</div>`;

    if (!M.mesh) return `${head}${card(`<div class="empty">${esc(t('noModel'))}</div>`)}`;

    const poses = M.poses
      .map(
        (p, i) => `<button class="pose${M.chosenPose === p.id ? ' on' : ''}" data-pose="${i}">
        <span class="pname">${i === 0 ? `<b class="badge green">${esc(t('poseBest'))}</b>` : ''}${esc(POSE_LABELS[p.id][M.lang] || p.id)}</span>
        <span class="n">${p.height.toFixed(0)} mm</span>
        <span class="n${p.supportArea < 1 ? ' green' : ''}">${p.supportArea.toFixed(0)} mm²</span></button>`
      )
      .join('');

    return `${head}
    <div class="orient">
      ${card(`<canvas id="viewer"></canvas><div class="hint">${esc(t('viewerHint'))}</div>`, 'viewer')}
      <div class="stack">
        ${card(`<div class="k">${esc(t('threshold'))}</div>
          <span class="slider"><input type="range" min="20" max="70" step="5" data-act="threshold" value="${M.supportThreshold}">
          <b id="thrLbl">${M.supportThreshold}°</b></span>
          <div class="note">${esc(t('orientHint'))}</div>`)}
        ${card(`<div class="poses"><div class="phead"><span>${esc(t('poseName'))}</span><span class="n">${esc(t('poseHeight'))}</span><span class="n">${esc(t('poseSupport'))}</span></div>${poses}</div>`, 'pad0')}
        <button class="btn primary big" data-act="sliceOriented">${esc(t('sliceOriented'))}</button>
      </div>
    </div>`;
  }

  /* ---------- gate di sblocco ---------- */

  function renderGate() {
    const gate = $('#gate');
    if (M.store.unlocked) {
      gate.hidden = true;
      gate.innerHTML = '';
      return;
    }
    gate.hidden = false;
    // flusso in due passi: 1) apri e segui uno dei profili → 2) si attiva lo sblocco Telegram
    const followed = !!M.store.followClicked;
    const dis = followed ? '' : 'disabled';
    gate.innerHTML = `<div class="gatebox">
      <div class="lock">🔓</div>
      <h1>${esc(t('gateTitle'))}</h1>
      <p>${esc(t('gateBody'))}</p>
      <div class="socials">
        <button data-follow="${AUTHOR.instagram}"><i class="ig">📷</i>Instagram</button>
        <button data-follow="${AUTHOR.makerworld}"><i class="mw">🧊</i>MakerWorld</button>
        <button data-follow="${AUTHOR.youtube}"><i class="yt">▶︎</i>YouTube</button>
      </div>
      <hr>
      <div class="tgstep${followed ? '' : ' off'}">
        <button class="btn tg" data-act="openBot" ${dis}>✈︎ ${esc(t('gateTelegram'))}</button>
        <div class="note center">${esc(t(followed ? 'gateTgHint' : 'gateLocked'))}</div>
        <div class="note center">${esc(t('gateCodeMobile'))}</div>
        <div class="coderow">
          <input id="unlockCode" placeholder="${esc(t('gateCodePlaceholder'))}" autocomplete="off" spellcheck="false" ${dis}>
          <button class="btn primary" data-act="unlockCode" ${dis}>${esc(t('gateUnlock'))}</button>
        </div>
        <div class="err" id="codeErr" hidden>${esc(t('gateCodeWrong'))}</div>
      </div>
      <div class="note dim center">ⓘ ${esc(t('affiliate'))}</div>
    </div>`;
  }

  /* ---------- render ---------- */

  function renderSidebar() {
    const group = (title, ids) => `<div class="navgrp"><div class="grptitle">${esc(title)}</div>${ids
      .map((s) => `<button class="nav${M.section === s.id ? ' on' : ''}" data-nav="${s.id}"><span>${s.icon}</span>${esc(t(s.key))}</button>`)
      .join('')}</div>`;

    $('#sidebar').innerHTML = `
      <div class="brand">${esc(t('brand'))}</div>
      <div class="langs">${LANGS.map((l) => `<button class="lang${M.lang === l.id ? ' on' : ''}" data-lang="${l.id}" title="${esc(l.label)}">${l.flag}</button>`).join('')}</div>
      ${group(t('grpProject'), SECTIONS.filter((s) => s.group === 'project'))}
      ${group(t('grpSettings'), SECTIONS.filter((s) => s.group === 'settings'))}
      <div class="spacer"></div>
      <div class="credits">
        <div class="note">${esc(t('followFree'))}</div>
        <div class="crow"><b>${esc(t('madeBy'))} Emanuele</b>
          <button data-open="${AUTHOR.instagram}" title="Instagram">📷</button>
          <button data-open="${AUTHOR.telegram}" title="Telegram">✈︎</button>
          <button data-open="${AUTHOR.makerworld}" title="MakerWorld">🧊</button>
        </div>
      </div>`;
  }

  const VIEWS = {
    overview: viewOverview,
    files: viewFiles,
    orient: viewOrient,
    colors: viewColors,
    materials: viewMaterials,
    printers: viewPrinters,
    plates: viewPlates,
    setup: viewSetup,
  };

  function render() {
    renderSidebar();
    const section = SECTIONS.find((s) => s.id === M.section);
    $('#main').innerHTML = `<h1>${esc(t(section.key))}</h1>${VIEWS[M.section]()}`;
    $('#main').scrollTop = 0;
    if (M.section === 'orient' && M.mesh) mountViewer();
  }

  function mountViewer() {
    const canvas = $('#viewer');
    if (!canvas) return;
    if (viewer) viewer.destroy();
    viewer = new window.Viewer(canvas);
    viewer.setMesh(M.mesh, M.supportThreshold);
  }

  /* ---------- azioni ---------- */

  function setSection(id) {
    M.section = id;
    render();
  }

  function setLang(lang) {
    M.lang = lang;
    M.store.lang = lang;
    // come sull'app macOS: cambiando lingua si allinea anche la valuta
    const def = (LANGS.find((l) => l.id === lang) || LANGS[0]).currency;
    M.store.currency = def;
    M.store.eurRate = CURRENCIES[def].rate;
    persist();
    api.setMenuLang(lang);
    document.documentElement.lang = lang;
    render();
    renderGate();
  }

  function addPreset() {
    const brands = [...new Set(window.PRESETS.map((p) => p.brand))];
    const brand = M.presetBrand || brands[0];
    const types = [...new Set(window.PRESETS.filter((p) => p.brand === brand).map((p) => p.type))];
    const type = types.includes(M.presetType) ? M.presetType : types[0];
    const items = window.PRESETS.filter((p) => p.brand === brand && p.type === type);
    const p = items[M.presetItem || 0] || items[0];
    if (!p) return;
    M.store.materials.unshift({
      name: p.colorName,
      type: p.type,
      colorHex: p.hex,
      costPerKg: p.costPerKg,
      densityGcm3: p.density,
      stockKg: null,
      salePrice: null,
    });
    persist();
    render();
  }

  async function loadModel(path) {
    setBusy(fmt(t('loadingMesh'), path.split(/[\\/]/).pop()));
    const res = await api.readMesh(path);
    setBusy(null);
    if (res.error === 'noBambu') return toast(t('bambuMissing'));
    if (res.error === 'stepFail') return toast(t('errStep'));
    if (res.error) return toast(t('errMesh'));

    const verts = window.MeshLib.parse(res.buffer, res.ext);
    if (!verts) return toast(t('errMesh'));
    M.baseMesh = verts;
    M.meshName = res.name;
    M.mesh = window.MeshLib.place(verts, null);
    M.poses = window.MeshLib.candidates(verts, M.supportThreshold);
    M.chosenPose = 'orig';
    setSection('orient');
  }

  async function sliceOriented() {
    if (!M.mesh || !M.meshName) return;
    setBusy(fmt(t('busy'), M.meshName));
    const stl = window.MeshLib.exportSTL(M.mesh);
    const res = await api.sliceSTL(M.meshName.replace(/\.[^.]+$/, ''), stl);
    setBusy(null);
    if (res.error === 'noBambu') return toast(t('bambuMissing'));
    if (res.error) return toast(fmt(t('errSliceFail'), M.meshName));
    M.files.push({
      id: ++seq,
      name: M.meshName,
      path: `mesh:${M.meshName}:${seq}`,
      analysis: res,
      excluded: new Set(),
      thumbs: [],
    });
    toast(fmt(t('okSliced'), M.meshName));
    setSection('overview');
  }

  async function locateBambu() {
    const r = await api.locateBambu();
    M.bambu = r.bambu || '';
    toast(M.bambu ? t('bambuOk') : t('bambuMissing'));
    render();
  }

  async function submitCode() {
    const input = $('#unlockCode');
    const ok = await api.unlockCode(input.value);
    if (!ok) {
      $('#codeErr').hidden = false;
      input.classList.add('wrong');
      return;
    }
    M.store.unlocked = true;
    renderGate();
  }

  /* ---------- eventi ---------- */

  function bindEvents() {
    document.addEventListener('click', async (e) => {
      const hit = (attr) => e.target.closest(`[${attr}]`);

      // follow dal gate: apre il profilo e abilita il passaggio Telegram
      const fol = hit('data-follow');
      if (fol) {
        api.open(fol.getAttribute('data-follow'));
        if (!M.store.followClicked) {
          M.store.followClicked = true;
          persist();
          renderGate();
        }
        return;
      }

      const open = hit('data-open');
      if (open) return api.open(open.getAttribute('data-open'));

      const nav = hit('data-nav');
      if (nav) return setSection(nav.getAttribute('data-nav'));

      const lang = hit('data-lang');
      if (lang) return setLang(lang.getAttribute('data-lang'));

      const pop = hit('data-pop');
      if (pop) return showStatPop(pop.getAttribute('data-pop'));

      const goto = hit('data-goto');
      if (goto) return setSection(goto.getAttribute('data-goto'));

      const del = hit('data-del');
      if (del) {
        M.files = M.files.filter((f) => f.id !== +del.getAttribute('data-del'));
        return render();
      }

      const sl = hit('data-slice');
      if (sl) {
        const f = M.files.find((x) => x.id === +sl.getAttribute('data-slice'));
        return f && sliceFile(f);
      }

      const plate = hit('data-plate');
      if (plate) {
        const [id, idx] = plate.getAttribute('data-plate').split(':').map(Number);
        const f = M.files.find((x) => x.id === id);
        if (f) {
          if (f.excluded.has(idx)) f.excluded.delete(idx);
          else f.excluded.add(idx);
          render();
        }
        return;
      }

      const source = hit('data-source');
      if (source) {
        M.store.source = source.getAttribute('data-source');
        persist();
        return render();
      }

      const buy = hit('data-buy');
      if (buy) {
        const m = M.store.materials[+buy.getAttribute('data-buy')];
        return m && api.open(amazonURL(`${m.type} ${m.name} filamento 1kg`));
      }

      const matdel = hit('data-matdel');
      if (matdel) {
        M.store.materials.splice(+matdel.getAttribute('data-matdel'), 1);
        persist();
        return render();
      }

      const prndel = hit('data-prndel');
      if (prndel) {
        M.store.printers.splice(+prndel.getAttribute('data-prndel'), 1);
        persist();
        return render();
      }

      const selprn = hit('data-selprinter');
      if (selprn) {
        const p = M.store.printers[+selprn.getAttribute('data-selprinter')];
        if (p) {
          M.store.selPrinter = p.name;
          persist();
          render();
        }
        return;
      }

      const pose = hit('data-pose');
      if (pose) {
        const p = M.poses[+pose.getAttribute('data-pose')];
        if (p && M.baseMesh) {
          M.chosenPose = p.id;
          M.mesh = window.MeshLib.place(M.baseMesh, p.rot);
          render();
        }
        return;
      }

      const act = hit('data-act');
      if (!act) return;
      switch (act.getAttribute('data-act')) {
        case 'pick3mf':
          return addPaths(await api.pickFiles());
        case 'pickModel': {
          const p = await api.pickModel();
          return p && loadModel(p);
        }
        case 'locateBambu':
          return locateBambu();
        case 'addPreset':
          return addPreset();
        case 'addBlank':
          M.store.materials.unshift({ name: 'Nuovo', type: 'PLA Basic', colorHex: '#8E9089', costPerKg: 22.99, densityGcm3: 1.24, stockKg: null, salePrice: null });
          persist();
          return render();
        case 'resetMaterials':
          M.store.materials = window.DEFAULTS.materials.map((m) => ({ ...m }));
          persist();
          return render();
        case 'addPrinter':
          M.store.printers.unshift({ name: 'Nuova', watts: 120, wearPerHour: 0.08, setupCost: 0.15 });
          persist();
          return render();
        case 'resetPrinters':
          M.store.printers = window.DEFAULTS.printers.map((p) => ({ ...p }));
          M.store.selPrinter = M.store.printers[0].name;
          persist();
          return render();
        case 'sliceOriented':
          return sliceOriented();
        case 'openBot':
          return api.openBot();
        case 'unlockCode':
          return submitCode();
        case 'unlockHonor':
          if (await api.unlockHonor()) {
            M.store.unlocked = true;
            renderGate();
          }
          return;
        default:
          return;
      }
    });

    // campi di testo/numero: aggiornano il modello senza ridisegnare (non si perde il fuoco)
    document.addEventListener('input', (e) => {
      const el = e.target;

      const store = el.getAttribute('data-store');
      if (store) {
        M.store[store] = el.dataset.num ? num(el.value) : el.value;
        persist();
        if (store === 'failurePct') $('#failLbl').textContent = `${Math.round(num(el.value))} %`;
        if (['msrp', 'spoolPrice', 'otherPrice'].includes(store) && M.section === 'colors') {
          $('#colorsBody').innerHTML = colorsBody();
        }
        return;
      }

      const mat = el.getAttribute('data-mat');
      if (mat) {
        const [i, field] = mat.split(':');
        const m = M.store.materials[+i];
        if (!m) return;
        if (field === 'name' || field === 'type' || field === 'colorHex') m[field] = el.value;
        else if (field === 'salePrice' || field === 'stockKg') m[field] = el.value === '' ? null : num(el.value);
        else m[field] = num(el.value);
        // il badge "offerta" è l'unica cosa che cambia nella riga: si aggiorna a mano
        if (field === 'salePrice' || field === 'costPerKg') {
          const cell = el.closest('td');
          const badge = cell.querySelector('.badge');
          if (onSale(m) && !badge) cell.insertAdjacentHTML('afterbegin', `<span class="badge green">${esc(t('onSaleBadge'))}</span>`);
          if (!onSale(m) && badge) badge.remove();
        }
        persist();
        return;
      }

      const prn = el.getAttribute('data-prn');
      if (prn) {
        const [i, field] = prn.split(':');
        const p = M.store.printers[+i];
        if (!p) return;
        const wasSelected = M.store.selPrinter === p.name;
        p[field] = el.dataset.num ? num(el.value) : el.value;
        if (field === 'name' && wasSelected) M.store.selPrinter = p.name;
        persist();
        return;
      }

      if (el.getAttribute('data-act') === 'threshold') {
        M.supportThreshold = num(el.value, 45);
        $('#thrLbl').textContent = `${M.supportThreshold}°`;
        if (viewer) viewer.setThreshold(M.supportThreshold);
        return;
      }

      if (el.id === 'unlockCode') $('#codeErr').hidden = true;
    });

    document.addEventListener('change', (e) => {
      const el = e.target;

      const preset = el.getAttribute('data-preset');
      if (preset) {
        if (preset === 'brand') {
          M.presetBrand = el.value;
          M.presetType = null;
          M.presetItem = 0;
          return render();
        }
        if (preset === 'type') {
          M.presetType = el.value;
          M.presetItem = 0;
          return render();
        }
        M.presetItem = +el.value;
        return;
      }

      const act = el.getAttribute('data-act');
      if (act === 'selPrinter') {
        M.store.selPrinter = el.value;
        persist();
        return render();
      }
      if (act === 'currency') {
        M.store.currency = el.value;
        M.store.eurRate = CURRENCIES[el.value].rate;
        persist();
        return render();
      }
      // le pose si ricalcolano solo al rilascio dello slider: è l'operazione più pesante
      if (act === 'threshold' && M.baseMesh) {
        M.poses = window.MeshLib.candidates(M.baseMesh, M.supportThreshold);
        render();
      }
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && e.target.id === 'unlockCode') submitCode();
    });

    /* trascinamento dei file sulla finestra */
    const dropzone = $('#drag');
    const over = (on) => dropzone.classList.toggle('on', on);
    document.addEventListener('dragover', (e) => {
      e.preventDefault();
      over(true);
    });
    document.addEventListener('dragleave', (e) => {
      if (!e.relatedTarget) over(false);
    });
    document.addEventListener('drop', (e) => {
      e.preventDefault();
      over(false);
      const paths = [...e.dataTransfer.files].map((f) => api.pathFor(f)).filter(Boolean);
      const models = paths.filter((p) => /\.(stl|obj|step|stp)$/i.test(p));
      addPaths(paths);
      if (models.length && !paths.some((p) => /\.3mf$/i.test(p))) loadModel(models[0]);
    });

    /* eventi dal processo principale */
    api.onOpenFiles((files) => addPaths(files));
    api.onUnlocked(() => {
      M.store.unlocked = true;
      renderGate();
      toast(t('gateTitle'));
    });
    api.onMenu(async (action) => {
      if (action === 'open3mf') return addPaths(await api.pickFiles());
      if (action === 'openModel') {
        const p = await api.pickModel();
        return p && loadModel(p);
      }
      if (action === 'locateBambu') return locateBambu();
    });
  }

  /* ---------- avvio ---------- */

  async function start() {
    const [store, info, defaults] = await Promise.all([api.loadStore(), api.info(), api.defaults()]);
    M.store = store;
    M.bambu = info.bambu;
    // lingua: scelta salvata → lingua di sistema → inglese (per i sistemi non IT/EN/ES/FR)
    M.lang = store.lang
      || (LANGS.find((l) => l.id === (info.locale || 'en').slice(0, 2)) || LANGS.find((l) => l.id === 'en')).id;
    if (!store.selPrinter && store.printers.length) M.store.selPrinter = store.printers[0].name;
    document.documentElement.lang = M.lang;

    // i default servono ai pulsanti "ripristina" e al menu dei preset
    window.DEFAULTS = { materials: defaults.materials, printers: defaults.printers };
    window.PRESETS = defaults.presets;

    api.setMenuLang(M.lang);
    bindEvents();
    render();
    renderGate();

    const pending = await api.ready();
    if (pending.unlocked) {
      M.store.unlocked = true;
      renderGate();
    }
    if (pending.files.length) addPaths(pending.files);
  }

  /** un errore all'avvio non deve lasciare una finestra vuota e muta */
  function fatal(err) {
    console.error(err);
    document.getElementById('gate').hidden = true;
    document.getElementById('main').innerHTML =
      `<h1>⚠️</h1><div class="card"><div class="empty">${esc(String((err && err.message) || err))}</div></div>`;
  }

  window.addEventListener('error', (e) => console.error(e.error || e.message));
  window.addEventListener('unhandledrejection', (e) => console.error(e.reason));

  start().catch(fatal);
})();
