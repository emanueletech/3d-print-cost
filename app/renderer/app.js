/* Costo Stampa 3D — renderer */
const $ = (id) => document.getElementById(id);

const PRINTERS = [
  { id: 'h2c', name: 'Bambu Lab H2C', watts: 180 },
  { id: 'h2d', name: 'Bambu Lab H2D', watts: 180 },
  { id: 'h2dpro', name: 'Bambu Lab H2D Pro', watts: 200 },
  { id: 'h2s', name: 'Bambu Lab H2S', watts: 160 },
  { id: 'x1c', name: 'Bambu Lab X1C', watts: 110 },
  { id: 'p1s', name: 'Bambu Lab P1S', watts: 105 },
  { id: 'a1', name: 'Bambu Lab A1', watts: 80 },
  { id: 'altro', name: 'Altra stampante', watts: 120 },
];

const NAMES = {
  'PLA Basic': { '#FFFFFF':'Jade White','#000000':'Black','#C12E1F':'Red','#0A2989':'Blue','#8E9089':'Gray',
    '#00AE42':'Bambu Green','#3F8E43':'Mistletoe Green','#0086D6':'Cyan','#FEC600':'Sunflower Yellow',
    '#482960':'Indigo Purple','#6F5034':'Cocoa Brown','#F5547C':'Hot Pink','#FF9016':'Pumpkin Orange',
    '#E4BD68':'Gold','#5E43B7':'Purple','#0056B8':'Cobalt Blue','#F55A74':'Pink','#D3B7A7':'Beige' },
  'PLA Matte': { '#FFFFFF':'Ivory White','#CBC6B8':'Bone White','#E8DBB7':'Desert Tan','#D3B7A7':'Latte Brown',
    '#AE835B':'Caramel','#B15533':'Terracotta','#7D6556':'Dark Brown','#4D3324':'Dark Chocolate',
    '#AE96D4':'Lilac Purple','#E8AFCF':'Sakura Pink','#F99963':'Mandarin Orange','#F7D959':'Lemon Yellow',
    '#950051':'Plum','#DE4343':'Scarlet Red','#BB3D43':'Dark Red','#68724D':'Dark Green','#61C680':'Grass Green',
    '#C2E189':'Apple Green','#A3D8E1':'Ice Blue','#56B7E6':'Sky Blue','#0078BF':'Marine Blue','#042F56':'Dark Blue',
    '#9B9EA0':'Ash Gray','#757575':'Nardo Gray','#000000':'Charcoal' },
};

const SETUP_MIN = 8;          // minuti di riscaldamento+calibrazione per avvio piatto
const files = [];             // { name, path, data:{plates,seconds,grams,perColor} }

/* ---------- navigazione ---------- */
document.querySelectorAll('#nav a').forEach(a => a.addEventListener('click', () => {
  document.querySelectorAll('#nav a').forEach(x => x.classList.toggle('on', x === a));
  document.querySelectorAll('main section').forEach(s => s.hidden = s.id !== 'sec-' + a.dataset.sec);
}));

/* ---------- setup ---------- */
const printerSel = $('printer');
PRINTERS.forEach(p => { const o = document.createElement('option'); o.value = p.id; o.textContent = `${p.name} · ${p.watts} W`; printerSel.appendChild(o); });
printerSel.addEventListener('change', () => { $('watts').value = PRINTERS.find(p => p.id === printerSel.value).watts; render(); });
$('watts').value = 180;
['watts', 'kwh', 'msrp'].forEach(id => $(id).addEventListener('input', render));

/* ---------- helpers ---------- */
const hms = (s) => { const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60); return h ? `${h}h ${String(m).padStart(2, '0')}m` : `${m}m`; };
const eur = (v) => v.toLocaleString('it-IT', { style: 'currency', currency: 'EUR' });
function tierPrice(totSpools, msrp) {
  if (totSpools >= 10) return { p: msrp * .5, l: 'sconto 50% (10+)' };
  if (totSpools >= 6) return { p: msrp * .55, l: 'sconto 45% (6+)' };
  if (totSpools >= 4) return { p: msrp * .65, l: 'sconto 35% (4+)' };
  return { p: msrp, l: 'listino pieno' };
}
function spoolName(color, type) { return (NAMES[type] || {})[color] || color; }
function toast(msg, spin = false) {
  const t = $('toast'); t.hidden = false;
  t.innerHTML = (spin ? '<span class="spin"></span>' : '') + msg;
  if (!spin) setTimeout(() => t.hidden = true, 3500);
}

/* ---------- caricamento file ---------- */
async function addPath(p) {
  const name = p.split('/').pop();
  if (files.some(f => f.path === p)) return toast(`${name}: già caricato`);
  const res = await window.api.analyze(p);
  if (res.error === 'not3mf') return toast(`${name}: non è un progetto 3mf valido`);
  if (res.error === 'notSliced') {
    files.push({ name, path: p, data: null });
    render();
    return toast(`${name}: non slicato — premi «Slica» nella lista`);
  }
  files.push({ name, path: p, data: res });
  render();
}
async function sliceFile(i) {
  const f = files[i];
  toast(`Slicing di ${f.name} con Bambu Studio… può volerci qualche minuto`, true);
  const res = await window.api.slice(f.path);
  $('toast').hidden = true;
  if (res.error === 'noBambu') return toast('Bambu Studio non trovato in /Applications');
  if (res.error) return toast(`${f.name}: slicing fallito — aprilo in Bambu Studio`);
  f.data = res; render(); toast(`${f.name}: slicato ✓`);
}

const drop = $('drop');
['dragenter', 'dragover'].forEach(ev => document.addEventListener(ev, e => { e.preventDefault(); drop.classList.add('over'); }));
['dragleave', 'drop'].forEach(ev => document.addEventListener(ev, e => { e.preventDefault(); if (ev === 'dragleave' && e.relatedTarget) return; drop.classList.remove('over'); }));
document.addEventListener('drop', e => {
  [...e.dataTransfer.files].forEach(f => { const p = window.api.pathFor(f); if (p && p.endsWith('.3mf')) addPath(p); });
});
$('pick').addEventListener('click', async () => (await window.api.pickFiles()).forEach(addPath));

/* ---------- consigli piatti ---------- */
function mergeAdvice() {
  const out = [];
  for (const f of files) {
    if (!f.data) continue;
    const groups = {};
    for (const p of f.data.plates) {
      if (p.seconds > 6 * 3600 && p.grams > 300) continue;      // piatto già pieno
      const key = p.colors.slice().sort().join('+') || 'vuoto';
      (groups[key] = groups[key] || []).push(p);
    }
    for (const [key, plates] of Object.entries(groups)) {
      if (plates.length < 2) continue;
      const target = Math.max(1, Math.ceil(plates.length / 3));   // ~3 piatti P1S per piatto H2C
      const saved = (plates.length - target) * SETUP_MIN;
      out.push({ file: f.name.replace('.3mf', ''), colors: key.split('+'),
        from: plates.map(p => p.n), to: target, saved });
    }
  }
  return out.sort((a, b) => b.saved - a.saved);
}

/* ---------- render ---------- */
function render() {
  const watts = +$('watts').value || 0;
  const kwh = +$('kwh').value || 0;
  const msrp = +$('msrp').value || 0;
  $('footWatts').textContent = `${watts} W · ${kwh.toLocaleString('it-IT')} €/kWh`;

  const loaded = files.filter(f => f.data);
  let totSec = 0, totG = 0;
  const perColor = {};
  for (const f of loaded) {
    totSec += f.data.seconds; totG += f.data.grams;
    for (const [k, g] of Object.entries(f.data.perColor)) perColor[k] = (perColor[k] || 0) + g;
  }
  const rows = Object.entries(perColor).map(([k, g]) => {
    const [color, type] = k.split('|');
    return { color, type, g, spools: Math.max(1, Math.ceil(g / 1000)) };
  }).sort((a, b) => b.g - a.g);
  const totSpools = rows.reduce((s, r) => s + r.spools, 0);
  const tier = tierPrice(totSpools, msrp);
  const filCost = totSpools * tier.p;
  const kWh = totSec / 3600 * watts / 1000;
  const enCost = kWh * kwh;

  /* dashboard */
  $('dashSub').textContent = loaded.length
    ? `${loaded.length} file · ${loaded.reduce((s, f) => s + f.data.plates.length, 0)} piatti · Bambu Lab H2C`
    : 'Trascina i tuoi file .3mf per iniziare';
  $('tTime').innerHTML = loaded.length ? `${Math.floor(totSec / 3600)}<small> h</small>` : '—';
  $('tTimeD').textContent = loaded.length ? `≈ ${Math.ceil(totSec / 86400)} giorni di stampa continua` : '';
  $('tGrams').innerHTML = loaded.length ? `${(totG / 1000).toFixed(1)}<small> kg</small>` : '—';
  $('tColorsD').textContent = rows.length ? `${rows.length} colori` : '';
  $('tSpools').textContent = loaded.length ? totSpools : '—';
  $('tFilCost').textContent = loaded.length ? eur(filCost) : '—';
  $('tTierD').textContent = loaded.length ? tier.l : '';
  $('tEnCost').textContent = loaded.length ? eur(enCost) : '—';
  $('tEnD').textContent = loaded.length ? `${kWh.toFixed(1)} kWh` : '';

  /* donut + legenda */
  if (rows.length) {
    let acc = 0;
    const stops = rows.map(r => { const from = acc / totG * 100; acc += r.g; return `${r.color} ${from.toFixed(1)}% ${(acc / totG * 100).toFixed(1)}%`; });
    $('donut').style.background = `conic-gradient(${stops.join(',')})`;
    $('donutTot').textContent = (totG / 1000).toFixed(1) + ' kg';
    $('legend').innerHTML = rows.slice(0, 8).map(r => `<span><i style="background:${r.color}"></i>${spoolName(r.color, r.type)}</span>`).join('');
  } else { $('donut').style.background = 'rgba(120,130,160,.15)'; $('donutTot').textContent = ''; $('legend').innerHTML = ''; }

  /* spark ore per file */
  const maxSec = Math.max(...loaded.map(f => f.data.seconds), 1);
  $('spark').innerHTML = loaded
    .slice().sort((a, b) => b.data.seconds - a.data.seconds)
    .map(f => `<div class="bar" style="height:${Math.max(4, f.data.seconds / maxSec * 100)}%" title="${f.name} — ${hms(f.data.seconds)}"><em>${Math.round(f.data.seconds / 3600)}h</em></div>`)
    .join('');

  /* tabella file */
  const tb = $('filesTable').querySelector('tbody');
  tb.innerHTML = files.map((f, i) => {
    if (!f.data) return `<tr><td>${f.name}</td><td class="n">—</td><td class="n">—</td><td class="n">—</td><td class="n">—</td>
      <td><button class="slicebtn" data-slice="${i}">Slica</button> <button class="iconbtn" data-del="${i}">✕</button></td></tr>`;
    const c = f.data.seconds / 3600 * watts / 1000 * kwh;
    return `<tr><td>${f.name}</td><td class="n">${f.data.plates.length}</td><td class="n">${hms(f.data.seconds)}</td>
      <td class="n">${f.data.grams.toFixed(0)}</td><td class="n">${eur(c)}</td>
      <td><span class="badge g">ok</span> <button class="iconbtn" data-del="${i}">✕</button></td></tr>`;
  }).join('');
  $('filesEmpty').hidden = files.length > 0;
  tb.querySelectorAll('[data-del]').forEach(b => b.addEventListener('click', () => { files.splice(+b.dataset.del, 1); render(); }));
  tb.querySelectorAll('[data-slice]').forEach(b => b.addEventListener('click', () => sliceFile(+b.dataset.slice)));

  /* colori */
  const ctb = $('colorsTable').querySelector('tbody');
  ctb.innerHTML = rows.map(r => `<tr>
    <td><span class="sw" style="background:${r.color}"></span>${r.type} ${spoolName(r.color, r.type)}</td>
    <td class="n">${r.g.toFixed(0)}</td><td class="n">${r.spools}</td>
    <td class="n">${eur(tier.p)}</td><td class="n">${eur(r.spools * tier.p)}</td></tr>`).join('') +
    (rows.length ? `<tr><td><b>Totale</b></td><td class="n"><b>${totG.toFixed(0)}</b></td><td class="n"><b>${totSpools}</b></td><td></td><td class="n"><b>${eur(filCost)}</b></td></tr>` : '');
  $('colorsEmpty').hidden = rows.length > 0;

  /* consigli piatti */
  const advice = mergeAdvice();
  $('mergeList').innerHTML = advice.length ? advice.map(a => `
    <div class="merge">
      <span class="chip">${a.colors.map(k => `<span class="sw" style="background:${k.split('|')[0]}"></span>`).join('')}${a.file}</span>
      <span class="chip">piatti ${a.from.join(', ')}</span> →
      <span class="chip">${a.to} piatt${a.to > 1 ? 'i' : 'o'} H2C</span>
      <span class="gain">−${a.saved} min di avvii</span>
    </div>`).join('') +
    `<div class="merge" style="color:var(--mut);font-size:12px">Regola d'oro: accorpa solo pezzi dello stesso colore — trascinali in Bambu Studio sul piatto di destinazione. Risparmio totale stimato: <b style="margin-left:4px">${Math.round(advice.reduce((s, a) => s + a.saved, 0) / 60 * 10) / 10} ore</b></div>`
    : '<div class="empty">Carica dei file per i consigli.</div>';
}

render();
