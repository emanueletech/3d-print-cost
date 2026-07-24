#!/bin/bash
# Crea un .dmg distribuibile di "3D Print Cost" (build pulita + istruzioni).
set -e
cd "$(dirname "$0")"

echo "▸ Build dell'app…"
bash build.sh >/dev/null

APP="3D Print Cost.app"
VOL="3D Print Cost"
STAGE="$(mktemp -d)/dmg"
OUT="$HOME/Desktop/3D-Print-Cost.dmg"
mkdir -p "$STAGE"

# app + scorciatoia Applicazioni
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applicazioni"

# istruzioni (IT + EN)
cat > "$STAGE/LEGGIMI - INSTALLA.txt" <<'TXT'
3D Print Cost — installazione (macOS)

REQUISITI
• macOS 26 (Tahoe) o successivo.
• Per lo slicing automatico serve Bambu Studio installato in Applicazioni
  (opzionale: i file .3mf GIÀ slicati funzionano anche senza).

INSTALLAZIONE
1) Trascina "3D Print Cost" dentro la cartella "Applicazioni".
2) PRIMA APERTURA — l'app non è firmata con un account Apple a pagamento,
   quindi macOS la blocca. Sbloccala così (una volta sola):
   • Apri l'app "Terminale" e incolla questo comando, poi Invio:

       xattr -dr com.apple.quarantine "/Applications/3D Print Cost.app"

   • Poi apri normalmente l'app da Applicazioni (o tasto destro → Apri).

SBLOCCO
L'app è gratuita: al primo avvio ti chiede di seguire l'autore su Telegram
(o Instagram/MakerWorld). Segui il canale, il bot ti manda il codice/link
e l'app si sblocca. Grazie del supporto!

────────────────────────────────────────────────────────────
3D Print Cost — install (macOS)

REQUIREMENTS
• macOS 26 (Tahoe) or later.
• Automatic slicing needs Bambu Studio installed (optional: already-sliced
  .3mf files work without it).

INSTALL
1) Drag "3D Print Cost" into the "Applications" folder.
2) FIRST LAUNCH — the app isn't signed with a paid Apple account, so macOS
   blocks it. Unblock it once with Terminal:

       xattr -dr com.apple.quarantine "/Applications/3D Print Cost.app"

   Then open it normally (or right-click → Open).

UNLOCK
Free app: on first launch it asks you to follow the author on Telegram
(or Instagram/MakerWorld). Follow the channel, the bot sends you the
code/link, and the app unlocks. Thanks for the support!
TXT

echo "▸ Creo il DMG…"
rm -f "$OUT"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
rm -rf "$(dirname "$STAGE")"
echo "✓ Pronto: $OUT"
du -h "$OUT"
