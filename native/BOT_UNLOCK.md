# Sblocco app via Telegram — lato bot

L'app "3D Print Cost" si sblocca aprendo un link `printcost://unlock?t=<exp>.<hmac>` che il
**bot** genera **solo** dopo aver verificato che l'utente è iscritto al canale.

## Come funziona
1. In-app l'utente tocca **"Sblocca con Telegram"** → apre `https://t.me/emanueletech_bot?start=unlock`.
2. Il bot su `/start unlock` controlla con `getChatMember` che l'utente sia nel canale.
3. Se iscritto → firma un token HMAC con scadenza e risponde con il link `printcost://unlock?t=…`.
4. macOS apre l'app, che verifica firma+scadenza e si sblocca. Nessun codice da digitare.

## Da impostare (deve combaciare con l'app)
- **Segreto**: uguale a `Author.unlockSecret` in `Sources/Store.swift`. Cambialo con uno lungo e casuale (es. `openssl rand -hex 32`) e mettilo **identico** qui e nell'app.
- **Canale**: lo username/id del tuo canale (es. `@emanueletech`).

## Snippet (python-telegram-bot v20+)
```python
import hmac, hashlib, time
from telegram import Update
from telegram.ext import ContextTypes, CommandHandler

UNLOCK_SECRET = b"cambia-questo-segreto-lungo-e-casuale"   # == Author.unlockSecret nell'app
CHANNEL = "@emanueletech"                                  # il tuo canale
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
    sig = hmac.new(UNLOCK_SECRET, str(exp).encode(), hashlib.sha256).hexdigest()
    link = f"printcost://unlock?t={exp}.{sig}"
    await update.message.reply_text(f"✅ Verificato! Apri l'app per sbloccarla:\n{link}")

# app.add_handler(CommandHandler("start", start))
```

## Note
- Il token **scade in 15 minuti**: un link condiviso ad altri smette di funzionare presto.
- Solo **Telegram** è verificabile davvero (Instagram/MakerWorld non hanno API sui follower):
  in-app quei due restano come follow + eventuale sblocco "onore" (disattivabile con
  `Author.allowHonorUnlock = false`, così vale solo la verifica Telegram).
- Il bot gira già sul tuo NAS (infra `telegram_business_bot`): basta aggiungere questo handler.
