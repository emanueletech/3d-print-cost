'use strict';
/*
 * Lettore/scrittore ZIP puro JavaScript.
 *
 * L'app Mac si appoggiava a /usr/bin/unzip: su Windows non esiste, quindi il
 * formato .3mf (che è uno zip) va letto qui. Nessuna dipendenza esterna: usa
 * solo zlib di Node (inflateRaw/deflateRaw).
 */
const fs = require('fs');
const zlib = require('zlib');

const SIG_LOCAL = 0x04034b50;
const SIG_CD = 0x02014b50;
const SIG_EOCD = 0x06054b50;
const SIG_EOCD64 = 0x06064b50;
const SIG_EOCD64_LOC = 0x07064b50;

/* ---------- CRC32 (serve solo in scrittura) ---------- */

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[i] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

/* ---------- lettura ---------- */

function readChunk(fd, position, length) {
  if (length <= 0) return Buffer.alloc(0);
  const buf = Buffer.alloc(length);
  let read = 0;
  while (read < length) {
    const n = fs.readSync(fd, buf, read, length - read, position + read);
    if (n <= 0) break;
    read += n;
  }
  return read === length ? buf : buf.subarray(0, read);
}

// L'End Of Central Directory sta in fondo al file, dopo un commento di lunghezza
// variabile: si cerca la firma partendo dalla coda.
function findEOCD(fd, size) {
  const maxTail = Math.min(size, 0xffff + 22);
  const tail = readChunk(fd, size - maxTail, maxTail);
  for (let i = tail.length - 22; i >= 0; i--) {
    if (tail.readUInt32LE(i) === SIG_EOCD) {
      return { buf: tail.subarray(i), offset: size - maxTail + i };
    }
  }
  return null;
}

function centralDirectoryInfo(fd, size) {
  const eocd = findEOCD(fd, size);
  if (!eocd) return null;
  let entries = eocd.buf.readUInt16LE(10);
  let cdSize = eocd.buf.readUInt32LE(12);
  let cdOffset = eocd.buf.readUInt32LE(16);

  // ZIP64: i campi a 16/32 bit sono saturi, i valori veri stanno nel record esteso.
  if (entries === 0xffff || cdOffset === 0xffffffff || cdSize === 0xffffffff) {
    const locOff = eocd.offset - 20;
    if (locOff >= 0) {
      const loc = readChunk(fd, locOff, 20);
      if (loc.length === 20 && loc.readUInt32LE(0) === SIG_EOCD64_LOC) {
        const rec64Off = Number(loc.readBigUInt64LE(8));
        const rec = readChunk(fd, rec64Off, 56);
        if (rec.length === 56 && rec.readUInt32LE(0) === SIG_EOCD64) {
          entries = Number(rec.readBigUInt64LE(32));
          cdSize = Number(rec.readBigUInt64LE(40));
          cdOffset = Number(rec.readBigUInt64LE(48));
        }
      }
    }
  }
  return { entries, cdSize, cdOffset };
}

// Legge i campi ZIP64 dell'extra field solo per i valori effettivamente saturi.
function patchFromZip64Extra(extra, entry) {
  let p = 0;
  while (p + 4 <= extra.length) {
    const id = extra.readUInt16LE(p);
    const len = extra.readUInt16LE(p + 2);
    if (id === 0x0001) {
      let q = p + 4;
      const take = () => {
        const v = Number(extra.readBigUInt64LE(q));
        q += 8;
        return v;
      };
      if (entry.size === 0xffffffff && q + 8 <= p + 4 + len) entry.size = take();
      if (entry.compressedSize === 0xffffffff && q + 8 <= p + 4 + len) entry.compressedSize = take();
      if (entry.headerOffset === 0xffffffff && q + 8 <= p + 4 + len) entry.headerOffset = take();
      return;
    }
    p += 4 + len;
  }
}

/** Elenca le voci del file zip (senza estrarre i dati). */
function list(file) {
  let fd;
  try {
    fd = fs.openSync(file, 'r');
  } catch {
    return [];
  }
  try {
    const size = fs.fstatSync(fd).size;
    const info = centralDirectoryInfo(fd, size);
    if (!info) return [];
    const cd = readChunk(fd, info.cdOffset, info.cdSize);
    const out = [];
    let p = 0;
    while (p + 46 <= cd.length && cd.readUInt32LE(p) === SIG_CD) {
      const nameLen = cd.readUInt16LE(p + 28);
      const extraLen = cd.readUInt16LE(p + 30);
      const commentLen = cd.readUInt16LE(p + 32);
      const entry = {
        name: cd.subarray(p + 46, p + 46 + nameLen).toString('utf8'),
        method: cd.readUInt16LE(p + 10),
        crc: cd.readUInt32LE(p + 16),
        compressedSize: cd.readUInt32LE(p + 20),
        size: cd.readUInt32LE(p + 24),
        headerOffset: cd.readUInt32LE(p + 42),
      };
      patchFromZip64Extra(cd.subarray(p + 46 + nameLen, p + 46 + nameLen + extraLen), entry);
      out.push(entry);
      p += 46 + nameLen + extraLen + commentLen;
    }
    return out;
  } catch {
    return [];
  } finally {
    fs.closeSync(fd);
  }
}

function extractWithFd(fd, entry) {
  // L'header locale ripete nome/extra con lunghezze potenzialmente diverse
  // da quelle del central directory: vanno rilette da qui.
  const head = readChunk(fd, entry.headerOffset, 30);
  if (head.length !== 30 || head.readUInt32LE(0) !== SIG_LOCAL) return null;
  const dataStart = entry.headerOffset + 30 + head.readUInt16LE(26) + head.readUInt16LE(28);
  const raw = readChunk(fd, dataStart, entry.compressedSize);
  if (raw.length !== entry.compressedSize) return null;
  if (entry.method === 0) return raw;
  if (entry.method === 8) {
    try {
      return zlib.inflateRawSync(raw);
    } catch {
      return null;
    }
  }
  return null; // metodi esotici (bzip2, lzma…): non usati dai 3mf
}

/** Estrae una singola voce; restituisce un Buffer oppure null. */
function read(file, name) {
  const entries = list(file);
  const entry = entries.find((e) => e.name === name);
  if (!entry) return null;
  let fd;
  try {
    fd = fs.openSync(file, 'r');
  } catch {
    return null;
  }
  try {
    return extractWithFd(fd, entry);
  } finally {
    fs.closeSync(fd);
  }
}

/** Estrae più voci in una sola apertura del file: { nome: Buffer }. */
function readMany(file, names) {
  const wanted = new Set(names);
  const entries = list(file).filter((e) => wanted.has(e.name));
  const out = {};
  if (!entries.length) return out;
  let fd;
  try {
    fd = fs.openSync(file, 'r');
  } catch {
    return out;
  }
  try {
    for (const e of entries) {
      const data = extractWithFd(fd, e);
      if (data) out[e.name] = data;
    }
  } finally {
    fs.closeSync(fd);
  }
  return out;
}

/** Testo UTF-8 di una voce (null se assente o illeggibile). */
function readText(file, name) {
  const buf = read(file, name);
  return buf ? buf.toString('utf8') : null;
}

/* ---------- scrittura ---------- */

function dosDateTime(date) {
  const y = Math.max(1980, date.getFullYear());
  return {
    time: (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1),
    date: ((y - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
  };
}

/**
 * Scrive uno zip deflated. `entries` = [{ name, data:Buffer }].
 * Serve al rimappaggio del 3mf per la griglia H2C (l'equivalente di remap.py).
 */
function write(file, entries, when = new Date()) {
  const { time, date } = dosDateTime(when);
  const chunks = [];
  const central = [];
  let offset = 0;

  for (const e of entries) {
    const name = Buffer.from(e.name, 'utf8');
    const data = Buffer.isBuffer(e.data) ? e.data : Buffer.from(e.data);
    const deflated = zlib.deflateRawSync(data, { level: 6 });
    // se comprimere non conviene si memorizza il dato grezzo
    const useStore = deflated.length >= data.length;
    const payload = useStore ? data : deflated;
    const method = useStore ? 0 : 8;
    const crc = crc32(data);

    const local = Buffer.alloc(30);
    local.writeUInt32LE(SIG_LOCAL, 0);
    local.writeUInt16LE(20, 4); // versione richiesta
    local.writeUInt16LE(0x0800, 6); // nomi in UTF-8
    local.writeUInt16LE(method, 8);
    local.writeUInt16LE(time, 10);
    local.writeUInt16LE(date, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(payload.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    chunks.push(local, name, payload);

    const cd = Buffer.alloc(46);
    cd.writeUInt32LE(SIG_CD, 0);
    cd.writeUInt16LE(20, 4); // versione di creazione
    cd.writeUInt16LE(20, 6);
    cd.writeUInt16LE(0x0800, 8);
    cd.writeUInt16LE(method, 10);
    cd.writeUInt16LE(time, 12);
    cd.writeUInt16LE(date, 14);
    cd.writeUInt32LE(crc, 16);
    cd.writeUInt32LE(payload.length, 20);
    cd.writeUInt32LE(data.length, 24);
    cd.writeUInt16LE(name.length, 28);
    cd.writeUInt32LE(offset, 42);
    central.push(cd, name);

    offset += local.length + name.length + payload.length;
  }

  const cdBuf = Buffer.concat(central);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(SIG_EOCD, 0);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(cdBuf.length, 12);
  eocd.writeUInt32LE(offset, 16);

  fs.writeFileSync(file, Buffer.concat([...chunks, cdBuf, eocd]));
}

module.exports = { list, read, readMany, readText, write, crc32 };
