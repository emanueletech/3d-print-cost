/*
 * Mesh STL/OBJ e analisi di orientamento.
 * Porting delle stesse formule di Mesh.swift: i risultati (altezza, area di
 * supporto, posa consigliata) coincidono con quelli dell'app macOS.
 */
'use strict';

// tutto racchiuso: nel renderer gli script condividono lo scope globale
(() => {

  /* ---------- matrici 3×3 (row-major) ---------- */

  const IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1];

  function mul(a, b) {
    const o = new Array(9);
    for (let r = 0; r < 3; r++)
      for (let c = 0; c < 3; c++)
        o[r * 3 + c] = a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
    return o;
  }
  function addM(a, b) {
    return a.map((v, i) => v + b[i]);
  }
  function scaleM(a, k) {
    return a.map((v) => v * k);
  }
  function apply(m, x, y, z) {
    return [
      m[0] * x + m[1] * y + m[2] * z,
      m[3] * x + m[4] * y + m[5] * z,
      m[6] * x + m[7] * y + m[8] * z,
    ];
  }

  /** rotazione che porta `axis` del modello a puntare verso −Z (cioè "in giù") */
  function rotToDown(ax, ay, az) {
    const len = Math.hypot(ax, ay, az) || 1;
    const a = [ax / len, ay / len, az / len];
    const d = -a[2]; // dot(a, (0,0,-1))
    if (d > 0.9999) return IDENTITY.slice();
    if (d < -0.9999) return [1, 0, 0, 0, -1, 0, 0, 0, -1]; // ribalta di 180°
    const v = [-a[1], a[0], 0]; // cross(a, down)
    const s2 = v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
    const vx = [0, -v[2], v[1], v[2], 0, -v[0], -v[1], v[0], 0];
    return addM(addM(IDENTITY, vx), scaleM(mul(vx, vx), (1 - d) / s2)); // Rodrigues
  }

  /* ---------- geometria ---------- */

  function bounds(verts, rot) {
    const lo = [Infinity, Infinity, Infinity];
    const hi = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < verts.length; i += 3) {
      const p = rot ? apply(rot, verts[i], verts[i + 1], verts[i + 2]) : [verts[i], verts[i + 1], verts[i + 2]];
      for (let k = 0; k < 3; k++) {
        if (p[k] < lo[k]) lo[k] = p[k];
        if (p[k] > hi[k]) hi[k] = p[k];
      }
    }
    if (!verts.length) return { lo: [0, 0, 0], hi: [0, 0, 0] };
    return { lo, hi };
  }

  /** ruota e appoggia al piatto: Z minima a 0, X/Y centrati */
  function place(verts, rot) {
    const b = bounds(verts, rot);
    const off = [(b.lo[0] + b.hi[0]) / 2, (b.lo[1] + b.hi[1]) / 2, b.lo[2]];
    const out = new Float32Array(verts.length);
    for (let i = 0; i < verts.length; i += 3) {
      const p = rot ? apply(rot, verts[i], verts[i + 1], verts[i + 2]) : [verts[i], verts[i + 1], verts[i + 2]];
      out[i] = p[0] - off[0];
      out[i + 1] = p[1] - off[1];
      out[i + 2] = p[2] - off[2];
    }
    return out;
  }

  /** normale (normalizzata) e area del triangolo che inizia all'indice i */
  function faceGeometry(v, i) {
    const ax = v[i], ay = v[i + 1], az = v[i + 2];
    const bx = v[i + 3] - ax, by = v[i + 4] - ay, bz = v[i + 5] - az;
    const cx = v[i + 6] - ax, cy = v[i + 7] - ay, cz = v[i + 8] - az;
    const nx = by * cz - bz * cy;
    const ny = bz * cx - bx * cz;
    const nz = bx * cy - by * cx;
    const len = Math.hypot(nx, ny, nz);
    return len > 0
      ? { nx: nx / len, ny: ny / len, nz: nz / len, area: len * 0.5 }
      : { nx: 0, ny: 0, nz: 1, area: 0 };
  }

  /**
   * Statistiche di una posa: altezza, ingombro e mm² di superficie da supportare.
   * Una faccia rivolta in giù chiede supporto se è più orizzontale della soglia
   * e non poggia già sul piatto.
   */
  function poseStats(verts, id, rot, thresholdDeg) {
    const m = place(verts, rot);
    const b = bounds(m, null);
    const cutoff = Math.cos((thresholdDeg * Math.PI) / 180);
    const bedEps = 0.4;
    let support = 0;
    let contact = 0;

    for (let i = 0; i < m.length; i += 9) {
      const g = faceGeometry(m, i);
      const zmin = Math.min(m[i + 2], m[i + 5], m[i + 8]);
      const zmax = Math.max(m[i + 2], m[i + 5], m[i + 8]);
      if (zmax < bedEps && g.nz < -0.7) {
        contact += g.area; // appoggio sul piatto: non è un supporto
        continue;
      }
      if (g.nz < 0 && -g.nz > cutoff && zmin > bedEps) support += g.area;
    }

    return {
      id,
      rot,
      height: b.hi[2] - b.lo[2],
      footprintX: b.hi[0] - b.lo[0],
      footprintY: b.hi[1] - b.lo[1],
      supportArea: support,
      contactArea: contact,
    };
  }

  const POSE_AXES = [
    ['xDown', 1, 0, 0],
    ['xUp', -1, 0, 0],
    ['yDown', 0, 1, 0],
    ['yUp', 0, -1, 0],
    ['headDown', 0, 0, 1],
    ['baseDown', 0, 0, -1],
  ];

  /** pose candidate: originale + i 6 assi verso il basso, ordinate per supporti crescenti */
  function candidates(verts, thresholdDeg = 45) {
    const out = [poseStats(verts, 'orig', IDENTITY.slice(), thresholdDeg)];
    for (const [id, x, y, z] of POSE_AXES) out.push(poseStats(verts, id, rotToDown(x, y, z), thresholdDeg));
    return out.sort((a, b) => a.supportArea - b.supportArea);
  }

  /* ---------- lettura file ---------- */

  function parseSTLBinary(buffer) {
    const dv = new DataView(buffer);
    const n = dv.getUint32(80, true);
    // 84 byte di intestazione + 50 per triangolo: se non torna, il file è ASCII o corrotto
    const usable = Math.min(n, Math.floor((buffer.byteLength - 84) / 50));
    const verts = new Float32Array(usable * 9);
    let o = 84;
    let w = 0;
    for (let t = 0; t < usable; t++) {
      for (let k = 0; k < 3; k++) {
        const vo = o + 12 + k * 12; // salta la normale dichiarata: la ricalcoliamo
        verts[w++] = dv.getFloat32(vo, true);
        verts[w++] = dv.getFloat32(vo + 4, true);
        verts[w++] = dv.getFloat32(vo + 8, true);
      }
      o += 50;
    }
    return verts;
  }

  function parseSTLAscii(text) {
    const out = [];
    for (const line of text.split('\n')) {
      const t = line.trim();
      if (t.startsWith('vertex')) {
        const c = t.split(/\s+/).slice(1).map(Number).filter((v) => Number.isFinite(v));
        if (c.length >= 3) out.push(c[0], c[1], c[2]);
      }
    }
    return new Float32Array(out);
  }

  function parseOBJ(text) {
    const pts = [];
    const out = [];
    for (const line of text.split('\n')) {
      if (line.startsWith('v ')) {
        const c = line.slice(2).trim().split(/\s+/).map(Number).filter((v) => Number.isFinite(v));
        if (c.length >= 3) pts.push([c[0], c[1], c[2]]);
      } else if (line.startsWith('f ')) {
        const idx = line
          .slice(2)
          .trim()
          .split(/\s+/)
          .map((tok) => {
            const i = parseInt(tok.split('/')[0], 10);
            if (!Number.isFinite(i)) return -1;
            return i > 0 ? i - 1 : pts.length + i;
          })
          .filter((i) => i >= 0 && i < pts.length);
        for (let k = 1; k + 1 < idx.length; k++) {
          // ventaglio di triangoli sui poligoni con più di 3 vertici
          for (const j of [0, k, k + 1]) out.push(pts[idx[j]][0], pts[idx[j]][1], pts[idx[j]][2]);
        }
      }
    }
    return new Float32Array(out);
  }

  /** Riconosce STL binario/ASCII e OBJ; restituisce i vertici o null. */
  function parse(buffer, ext) {
    try {
      if (ext === 'obj') return orNull(parseOBJ(new TextDecoder().decode(buffer)));
      if (buffer.byteLength < 84) return null;
      const head = new TextDecoder('ascii').decode(new Uint8Array(buffer, 0, Math.min(512, buffer.byteLength)));
      if (head.trimStart().startsWith('solid') && /facet/.test(head)) {
        const verts = parseSTLAscii(new TextDecoder().decode(buffer));
        if (verts.length >= 9) return verts;
      }
      return orNull(parseSTLBinary(buffer));
    } catch {
      return null;
    }
  }

  function orNull(verts) {
    return verts && verts.length >= 9 ? verts : null;
  }

  /** Esporta la mesh in STL binario (per rislicare la posa scelta). */
  function exportSTL(verts) {
    const tris = Math.floor(verts.length / 9);
    const buf = new ArrayBuffer(84 + tris * 50);
    const dv = new DataView(buf);
    dv.setUint32(80, tris, true);
    let o = 84;
    for (let i = 0; i < tris * 9; i += 9) {
      const g = faceGeometry(verts, i);
      dv.setFloat32(o, g.nx, true);
      dv.setFloat32(o + 4, g.ny, true);
      dv.setFloat32(o + 8, g.nz, true);
      for (let k = 0; k < 9; k++) dv.setFloat32(o + 12 + k * 4, verts[i + k], true);
      dv.setUint16(o + 48, 0, true);
      o += 50;
    }
    return buf;
  }

  window.MeshLib = { IDENTITY, parse, place, bounds, candidates, poseStats, exportSTL, faceGeometry };
})();
