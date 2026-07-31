# Sblocco app via Telegram — lato bot

L'app "3D Print Cost" si sblocca con un token **firmato Ed25519** che il **bot**
genera solo dopo aver verificato che l'utente è iscritto al canale.

La chiave **privata** vive solo sul server del bot; le app (macOS e Windows)
incorporano la sola chiave **pubblica**. Nel repository e nei binari non c'è
alcun segreto: chi legge il codice non può fabbricare token validi.

## Come funziona
1. In-app l'utente tocca **"Sblocca con Telegram"** → apre `https://t.me/emanueletech_bot?start=unlock`.
2. Il bot su `/start unlock` controlla con `getChatMember` che l'utente sia nel canale.
3. Se iscritto → firma `printcost:unlock:<exp>` con la chiave privata e risponde con:
   - il link `printcost://unlock?t=<exp>.<firma hex>` (aprendolo, l'app si sblocca da sola);
   - lo stesso token come testo, da incollare nel campo della schermata di sblocco
     se il link non si apre (es. Telegram Web).
4. L'app verifica firma e scadenza con la chiave pubblica, offline.

## Formato del token
```
messaggio = "printcost:unlock:<exp>"        # exp = scadenza Unix in secondi
token     = "<exp>.<firma Ed25519 in hex>"  # firma = 64 byte → 128 caratteri hex
```

## Generare (o ruotare) le chiavi
```bash
python3 - <<'PY'
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization as s
sk = Ed25519PrivateKey.generate()
print("privata :", sk.private_bytes(s.Encoding.Raw, s.PrivateFormat.Raw, s.NoEncryption()).hex())
print("pubblica:", sk.public_key().public_bytes(s.Encoding.Raw, s.PublicFormat.Raw).hex())
PY
```
- **privata** → solo nel bot (variabile d'ambiente, mai committata);
- **pubblica** → `Author.unlockPublicKey` in `Sources/Store.swift` **e** in `app/lib/store.js`
  (devono essere identiche), poi ricompila/ripubblica le app.

## Snippet (python-telegram-bot v20+)
```python
import os, time
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from telegram import Update
from telegram.ext import ContextTypes, CommandHandler

SK = Ed25519PrivateKey.from_private_bytes(bytes.fromhex(os.environ["UNLOCK_PRIVATE_KEY"]))
CHANNEL = "@emanueletech"
TOKEN_TTL = 900                                            # 15 min

async def start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    args = ctx.args or []
    if not args or args[0] != "unlock":
        await update.message.reply_text("Ciao! Apri l'app e premi «Sblocca con Telegram».")
        return
    uid = update.effective_user.id
    try:
        member = await ctx.bot.get_chat_member(CHANNEL, uid)
        ok = member.status in ("member", "administrator", "creator")
    except Exception:
        ok = False
    if not ok:
        await update.message.reply_text(
            f"Prima iscriviti al canale {CHANNEL}, poi ripremi «Sblocca con Telegram» nell'app."
        )
        return
    exp = int(time.time()) + TOKEN_TTL
    sig = SK.sign(f"printcost:unlock:{exp}".encode()).hex()
    token = f"{exp}.{sig}"
    await update.message.reply_text(
        "✅ Verificato! Apri questo link per sbloccare l'app:\n"
        f"printcost://unlock?t={token}\n\n"
        "Se il link non si apre, incolla questo codice nell'app:\n"
        f"{token}"
    )

# app.add_handler(CommandHandler("start", start))
```

## Note
- Il token **scade in 15 minuti**: un link condiviso ad altri smette di funzionare presto.
- Le build **precedenti** delle app usavano un HMAC condiviso: non accettano i nuovi
  token. Chi ha una vecchia build deve aggiornarla (o usare lo sblocco "onore").
- Solo **Telegram** è verificabile davvero (Instagram/MakerWorld non hanno API sui
  follower): in-app quei due restano come follow + eventuale sblocco "onore"
  (disattivabile con `Author.allowHonorUnlock = false`).
