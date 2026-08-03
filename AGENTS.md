# Convenzioni del repository

## Identità dei commit

Tutte le modifiche vanno firmate a nome del proprietario del repository:

```
emanueletech <281643038+emanueletech@users.noreply.github.com>
```

Da impostare all'inizio di ogni sessione di lavoro:

```bash
git config user.name "emanueletech"
git config user.email "281643038+emanueletech@users.noreply.github.com"
git config commit.gpgsign false
```

L'ultima riga è necessaria negli ambienti remoti che firmano i commit con una
chiave propria: quella chiave non è registrabile sull'account del proprietario
e su GitHub produrrebbe il distintivo "Unverified". Meglio commit non firmati
(nessun distintivo) che firme non verificabili.

## Attribuzione

Niente attribuzioni a strumenti o assistenti automatici, in nessun punto visibile
su GitHub: né nei messaggi di commit (trailer `Co-Authored-By`, link di sessione),
né nei titoli o nei corpi delle pull request, né nei commenti, né nei file del
progetto. I messaggi di commit descrivono solo la modifica.

## Lingue

I testi rivolti al pubblico su GitHub — note di release, descrizione del
repository, documenti come il README — vanno scritti **sia in italiano sia in
inglese** (prima IT, poi EN, come già fa il README). I messaggi di commit
restano in italiano.

## Struttura

- `index.html` — versione web
- `app/` — app desktop Electron (Windows/macOS/Linux); `npm test` prima di ogni commit
- `native/` — app nativa macOS (SwiftUI)
- `.github/workflows/` — costruzione dell'installer Windows
