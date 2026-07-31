'use strict';
/*
 * Verifica dello sblocco con firma Ed25519.
 *
 * Il bot firma con la chiave PRIVATA, che vive solo sul suo server; l'app
 * incorpora la sola chiave PUBBLICA. Nel sorgente e nei binari non c'è alcun
 * segreto: il repository può essere pubblico senza regalare lo sblocco.
 *
 *   messaggio = "printcost:unlock:<scadenzaUnix>"
 *   token     = "<scadenzaUnix>.<firma Ed25519 in hex (128 caratteri)>"
 *
 * Lo stesso token vale per il deep-link (printcost://unlock?t=…) e, incollato
 * a mano, per il campo codice della schermata di sblocco.
 */
const crypto = require('crypto');
const { Author } = require('./store');

// intestazione DER (SPKI) per una chiave pubblica Ed25519 grezza da 32 byte
const SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

let cached = { hex: null, key: null };

function publicKey() {
  const hex = String(Author.unlockPublicKey || '').toLowerCase();
  if (cached.hex === hex) return cached.key;
  let key = null;
  if (/^[0-9a-f]{64}$/.test(hex)) {
    try {
      key = crypto.createPublicKey({
        key: Buffer.concat([SPKI_PREFIX, Buffer.from(hex, 'hex')]),
        format: 'der',
        type: 'spki',
      });
    } catch {
      key = null;
    }
  }
  cached = { hex, key };
  return key;
}

/** Token firmato "<exp>.<sig hex>": vero se la firma è valida e non è scaduto. */
function validToken(token) {
  const key = publicKey();
  if (!key || typeof token !== 'string') return false;
  const dot = token.indexOf('.');
  if (dot <= 0) return false;
  const exp = token.slice(0, dot);
  const sig = token.slice(dot + 1).toLowerCase();
  if (!/^\d{1,12}$/.test(exp) || !/^[0-9a-f]{128}$/.test(sig)) return false;
  if (Number(exp) < Date.now() / 1000) return false;
  try {
    return crypto.verify(null, Buffer.from(`printcost:unlock:${exp}`, 'utf8'), key, Buffer.from(sig, 'hex'));
  } catch {
    return false;
  }
}

/** Codice incollato a mano nella schermata di sblocco: è lo stesso token. */
function validCode(input) {
  return typeof input === 'string' && validToken(input.trim());
}

/** Estrae e verifica il token da un URL printcost://unlock?t=… */
function tokenFromURL(raw) {
  try {
    const url = new URL(raw);
    if (url.protocol.replace(':', '').toLowerCase() !== Author.urlScheme) return null;
    const isUnlock = url.hostname === 'unlock' || url.pathname.includes('unlock');
    if (!isUnlock) return null;
    const t = url.searchParams.get('t');
    return t && validToken(t) ? t : null;
  } catch {
    return null;
  }
}

module.exports = { validToken, validCode, tokenFromURL };
