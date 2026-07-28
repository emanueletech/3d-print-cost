'use strict';
/*
 * Verifica dello sblocco: stesso schema HMAC del bot Telegram e dell'app macOS,
 * così lo stesso codice/link funziona su tutti i dispositivi.
 *
 *   token  = "<scadenzaUnix>.<hmacSHA256(segreto, scadenzaUnix) hex>"   (deep-link)
 *   codice = primi 6 hex di HMAC(segreto, finestra) in maiuscolo        (dal telefono)
 */
const crypto = require('crypto');
const { Author } = require('./store');

const WINDOW = 300; // durata della finestra del codice, in secondi

function hmacHex(message) {
  return crypto.createHmac('sha256', Buffer.from(Author.unlockSecret, 'utf8')).update(String(message), 'utf8').digest('hex');
}

function equalsConstantTime(a, b) {
  const ba = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

/** Token firmato che arriva dal deep-link printcost://unlock?t=… */
function validToken(token) {
  if (typeof token !== 'string') return false;
  const dot = token.indexOf('.');
  if (dot <= 0) return false;
  const exp = token.slice(0, dot);
  const mac = token.slice(dot + 1);
  const expiry = Number(exp);
  if (!Number.isFinite(expiry) || expiry < Date.now() / 1000) return false;
  return equalsConstantTime(hmacHex(exp), mac.toLowerCase());
}

/** Codice della finestra temporale indicata (identico a quello generato dal bot). */
function windowCode(w) {
  return hmacHex(w).slice(0, 6).toUpperCase();
}

/** Codice corto valido per la finestra corrente e le due precedenti (~15 min). */
function validCode(input) {
  if (typeof input !== 'string') return false;
  const s = input.trim().toUpperCase();
  if (s.length !== 6) return false;
  const now = Math.floor(Date.now() / 1000 / WINDOW);
  for (let d = 0; d <= 2; d++) if (equalsConstantTime(windowCode(now - d), s)) return true;
  return false;
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

module.exports = { validToken, validCode, windowCode, tokenFromURL, WINDOW };
