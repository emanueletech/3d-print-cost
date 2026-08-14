import SwiftUI
import UniformTypeIdentifiers
import AppKit
import simd

// MARK: - Lingue

enum Lang: String, CaseIterable, Identifiable {
    case it, en, es, fr
    var id: String { rawValue }
    var flag: String { ["it":"🇮🇹","en":"🇺🇸","es":"🇪🇸","fr":"🇫🇷"][rawValue]! }
    var label: String { ["it":"Italiano","en":"English","es":"Español","fr":"Français"][rawValue]! }
    /// valuta di default per la lingua (IT/ES/FR = €, EN 🇺🇸 = $)
    var defaultCurrency: Currency { self == .en ? .usd : .eur }
    /// locale per date e nomi dei mesi (storico costi)
    var localeId: String { ["it":"it_IT","en":"en_US","es":"es_ES","fr":"fr_FR"][rawValue]! }
}

enum Loc {
    static let s: [String: [String: String]] = [
        "brand": ["it":"Costo Stampa 3D","en":"3D Print Cost","es":"Coste Impresión 3D","fr":"Coût Impression 3D"],
        "nOverview": ["it":"Panoramica","en":"Overview","es":"Resumen","fr":"Aperçu"],
        "nFiles": ["it":"File & Slicing","en":"Files & Slicing","es":"Archivos","fr":"Fichiers"],
        "nColors": ["it":"Colori & Bobine","en":"Colors & Spools","es":"Colores y Bobinas","fr":"Couleurs & Bobines"],
        "nPlates": ["it":"Ottimizza piatti","en":"Optimize plates","es":"Optimizar placas","fr":"Optimiser plateaux"],
        "nSetup": ["it":"Costi & Setup","en":"Costs & Setup","es":"Costes y Ajustes","fr":"Coûts & Réglages"],
        "kTime": ["it":"Tempo di stampa","en":"Print time","es":"Tiempo de impresión","fr":"Temps d'impression"],
        "kMat": ["it":"Materiale","en":"Material","es":"Material","fr":"Matériau"],
        "kSpools": ["it":"Bobine da comprare","en":"Spools to buy","es":"Bobinas a comprar","fr":"Bobines à acheter"],
        "kFil": ["it":"Filamento","en":"Filament","es":"Filamento","fr":"Filament"],
        "kEnergy": ["it":"Corrente","en":"Electricity","es":"Electricidad","fr":"Électricité"],
        "kPlates": ["it":"Piatti","en":"Plates","es":"Placas","fr":"Plateaux"],
        "kByColor": ["it":"Materiale per colore","en":"Material by color","es":"Material por color","fr":"Matériau par couleur"],
        "kHours": ["it":"Ore per file","en":"Hours per file","es":"Horas por archivo","fr":"Heures par fichier"],
        "dropStart": ["it":"Trascina i tuoi file .3mf per iniziare","en":"Drop your .3mf files to get started","es":"Arrastra tus archivos .3mf para empezar","fr":"Déposez vos fichiers .3mf pour commencer"],
        "days": ["it":"giorni di stampa","en":"days of printing","es":"días de impresión","fr":"jours d'impression"],
        "colors": ["it":"colori","en":"colors","es":"colores","fr":"couleurs"],
        "refills": ["it":"refill 1 kg","en":"1 kg refills","es":"recargas 1 kg","fr":"recharges 1 kg"],
        "files": ["it":"file","en":"files","es":"archivos","fr":"fichiers"],
        "sFiles": ["it":"I 3mf già slicati (di qualsiasi slicer) vengono letti al volo. Lo slicing dall'app usa sempre Bambu Studio con profilo H2C: la stampante scelta sopra incide solo sui costi.",
                   "en":"Already-sliced 3mf (from any slicer) are read instantly. In-app slicing always uses Bambu Studio with the H2C profile: the printer picked above only affects costs.",
                   "es":"Los 3mf ya laminados (de cualquier laminador) se leen al instante. El laminado desde la app usa siempre Bambu Studio con el perfil H2C: la impresora elegida solo afecta a los costes.",
                   "fr":"Les 3mf déjà découpés (de n'importe quel slicer) sont lus instantanément. La découpe depuis l'app utilise toujours Bambu Studio avec le profil H2C : l'imprimante choisie n'influe que sur les coûts."],
        "sFilesBambu": ["it":"I 3mf già slicati (di qualsiasi slicer) vengono letti al volo. Slicing integrato con Bambu Studio: ugello %@ mm, layer %@ mm.",
                        "en":"Already-sliced 3mf (from any slicer) are read instantly. In-app slicing with Bambu Studio: %@ mm nozzle, %@ mm layer.",
                        "es":"Los 3mf ya laminados (de cualquier laminador) se leen al instante. Laminado integrado con Bambu Studio: boquilla de %@ mm, capa de %@ mm.",
                        "fr":"Les 3mf déjà découpés (de n'importe quel slicer) sont lus instantanément. Découpe intégrée avec Bambu Studio : buse %@ mm, couche %@ mm."],
        "sFilesExport": ["it":"I 3mf già slicati (di qualsiasi slicer) vengono letti al volo. Per %@ lo slicing integrato non è ancora disponibile: slica in %@ ed esporta il «file del piatto slicato» — l'app lo legge subito.",
                         "en":"Already-sliced 3mf (from any slicer) are read instantly. In-app slicing isn't available for %@ yet: slice in %@ and export the \u{201C}plate sliced file\u{201D} — the app reads it right away.",
                         "es":"Los 3mf ya laminados (de cualquier laminador) se leen al instante. El laminado integrado aún no está disponible para %@: lamina en %@ y exporta el «archivo de placa laminado» — la app lo lee al momento.",
                         "fr":"Les 3mf déjà découpés (de n'importe quel slicer) sont lus instantanément. La découpe intégrée n'est pas encore disponible pour %@ : découpez dans %@ et exportez le « fichier de plateau découpé » — l'app le lit aussitôt."],
        "sliceOtherNote": ["it":"Numeri calcolati col profilo Bambu H2C: per %@ slica in %@ ed esporta il 3mf per i consumi veri.",
                           "en":"Figures computed with the Bambu H2C profile: for %@, slice in %@ and export the 3mf for true usage.",
                           "es":"Cifras calculadas con el perfil Bambu H2C: para %@, lamina en %@ y exporta el 3mf para consumos reales.",
                           "fr":"Chiffres calculés avec le profil Bambu H2C : pour %@, découpez dans %@ et exportez le 3mf pour la consommation réelle."],
        "lblNozzle": ["it":"Ugello","en":"Nozzle","es":"Boquilla","fr":"Buse"],
        "lblLayer": ["it":"Layer","en":"Layer","es":"Capa","fr":"Couche"],
        "expOnly": ["it":"solo lettura export","en":"export reading only","es":"solo lectura de export","fr":"lecture d'export seule"],
        "pSlicer": ["it":"Slicer","en":"Slicer","es":"Laminador","fr":"Slicer"],
        "reslice": ["it":"Rislica con stampante, ugello e layer attuali","en":"Re-slice with the current printer, nozzle and layer","es":"Relamina con impresora, boquilla y capa actuales","fr":"Redécoupe avec l'imprimante, la buse et la couche actuelles"],
        "openIn": ["it":"Apri in %@","en":"Open in %@","es":"Abrir en %@","fr":"Ouvrir dans %@"],
        "selAll": ["it":"Tutti","en":"All","es":"Todas","fr":"Tous"],
        "selNone": ["it":"Nessuno","en":"None","es":"Ninguna","fr":"Aucun"],
        // confronto stampanti (v1.3)
        "cmpTitle": ["it":"Confronto stampanti","en":"Printer comparison","es":"Comparación de impresoras","fr":"Comparaison d'imprimantes"],
        "cmpHint": ["it":"Stesso file e stessi piatti, slicati coi profili di un'altra stampante: tempi e costi a confronto con %@.",
                    "en":"Same file and plates, sliced with another printer's profiles: times and costs compared with %@.",
                    "es":"Mismo archivo y placas, laminados con los perfiles de otra impresora: tiempos y costes frente a %@.",
                    "fr":"Même fichier et mêmes plateaux, découpés avec les profils d'une autre imprimante : temps et coûts face à %@."],
        "cmpWith": ["it":"Confronta con","en":"Compare with","es":"Comparar con","fr":"Comparer avec"],
        "cmpRun": ["it":"Confronta","en":"Compare","es":"Comparar","fr":"Comparer"],
        "cmpBusy": ["it":"Confronto: slicing di %@ per %@…","en":"Comparing: slicing %@ for %@…",
                    "es":"Comparando: laminando %@ para %@…","fr":"Comparaison : découpe de %@ pour %@…"],
        "cmpFail": ["it":"Confronto non riuscito: nessun piatto slicabile per %@",
                    "en":"Comparison failed: no plate could be sliced for %@",
                    "es":"Comparación fallida: ninguna placa laminable para %@",
                    "fr":"Comparaison échouée : aucun plateau découpable pour %@"],
        "cmpCur": ["it":"attuale","en":"current","es":"actual","fr":"actuelle"],
        // NB: %% = simbolo % letterale (queste stringhe passano da String(format:))
        "cmpSaves": ["it":"Con %@ spendi %@ in meno (−%@%%)","en":"With %@ you spend %@ less (−%@%%)",
                     "es":"Con %@ gastas %@ menos (−%@%%)","fr":"Avec %@ vous dépensez %@ de moins (−%@%%)"],
        "cmpEqual": ["it":"Costo praticamente identico con le due stampanti.","en":"Practically the same cost on both printers.",
                     "es":"Coste prácticamente idéntico en ambas impresoras.","fr":"Coût quasiment identique sur les deux imprimantes."],
        "cmpFailed": ["it":"Piatti non slicabili con %@: %@ — confronto sui soli piatti riusciti.",
                      "en":"Plates not sliceable on %@: %@ — comparison covers the successful plates only.",
                      "es":"Placas no laminables con %@: %@ — comparación solo de las placas logradas.",
                      "fr":"Plateaux non découpables avec %@ : %@ — comparaison sur les seuls plateaux réussis."],
        // storico & registro costi (v1.3)
        "nHistory": ["it":"Storico costi","en":"Cost history","es":"Historial de costes","fr":"Historique des coûts"],
        "sHistory": ["it":"Le stampe salvate restano qui: totali per mese e registro completo, esportabile in CSV. I dati vivono solo sul tuo Mac.",
                     "en":"Saved prints live here: monthly totals and the full log, exportable as CSV. Data never leaves your Mac.",
                     "es":"Las impresiones guardadas viven aquí: totales por mes y registro completo, exportable a CSV. Los datos no salen de tu Mac.",
                     "fr":"Les impressions enregistrées vivent ici : totaux par mois et journal complet, exportable en CSV. Les données restent sur votre Mac."],
        "histSave": ["it":"Salva nel registro costi","en":"Save to the cost log",
                     "es":"Guardar en el registro de costes","fr":"Enregistrer dans le journal des coûts"],
        "histSaveProj": ["it":"Salva il progetto nel registro","en":"Save project to the log",
                         "es":"Guardar el proyecto en el registro","fr":"Enregistrer le projet dans le journal"],
        "histSaved": ["it":"Salvato nel registro ✓","en":"Saved to the log ✓","es":"Guardado en el registro ✓","fr":"Enregistré dans le journal ✓"],
        "histEmpty": ["it":"Registro vuoto. Salva una stampa dal pulsante sulla scheda del file, o tutto il progetto col pulsante qui sopra.",
                      "en":"The log is empty. Save a print from the button on a file card, or the whole project with the button above.",
                      "es":"Registro vacío. Guarda una impresión desde el botón de la tarjeta del archivo, o todo el proyecto con el botón de arriba.",
                      "fr":"Journal vide. Enregistrez une impression depuis le bouton de la carte du fichier, ou tout le projet avec le bouton ci-dessus."],
        "histExport": ["it":"Esporta CSV","en":"Export CSV","es":"Exportar CSV","fr":"Exporter CSV"],
        "histExported": ["it":"Registro esportato ✓","en":"Log exported ✓","es":"Registro exportado ✓","fr":"Journal exporté ✓"],
        "hMonth": ["it":"Mese","en":"Month","es":"Mes","fr":"Mois"],
        "hPrints": ["it":"Stampe","en":"Prints","es":"Impresiones","fr":"Impressions"],
        "hHours": ["it":"Ore","en":"Hours","es":"Horas","fr":"Heures"],
        "thDate": ["it":"Data","en":"Date","es":"Fecha","fr":"Date"],
        // preventivo per clienti (v1.3)
        "nQuote": ["it":"Preventivo","en":"Quote","es":"Presupuesto","fr":"Devis"],
        "sQuote": ["it":"Il costo reale del progetto caricato diventa un preventivo da mandare al cliente: margine, intestazione e note sono tuoi, il PDF esce pronto.",
                   "en":"The loaded project's real cost becomes a quote you can send to the customer: margin, header and notes are yours, the PDF comes out ready.",
                   "es":"El coste real del proyecto cargado se convierte en un presupuesto para el cliente: margen, encabezado y notas son tuyos, el PDF sale listo.",
                   "fr":"Le coût réel du projet chargé devient un devis à envoyer au client : marge, en-tête et notes sont à vous, le PDF sort prêt."],
        "qBiz": ["it":"Nome attività / firma","en":"Business name / signature","es":"Nombre del negocio / firma","fr":"Nom de l'activité / signature"],
        "qBizPlaceholder": ["it":"La tua attività","en":"Your business","es":"Tu negocio","fr":"Votre activité"],
        "qContact": ["it":"Contatti (email, telefono…)","en":"Contact details (email, phone…)","es":"Contacto (email, teléfono…)","fr":"Contact (email, téléphone…)"],
        "qClient": ["it":"Cliente (facoltativo)","en":"Customer (optional)","es":"Cliente (opcional)","fr":"Client (facultatif)"],
        "qMargin": ["it":"Margine","en":"Margin","es":"Margen","fr":"Marge"],
        "qModePct": ["it":"Percentuale","en":"Percent","es":"Porcentaje","fr":"Pourcentage"],
        "qModeFlat": ["it":"Importo fisso","en":"Fixed amount","es":"Importe fijo","fr":"Montant fixe"],
        "qValidity": ["it":"Validità (giorni)","en":"Validity (days)","es":"Validez (días)","fr":"Validité (jours)"],
        "qNotes": ["it":"Note in calce","en":"Footer notes","es":"Notas al pie","fr":"Notes de bas de page"],
        "qDetail": ["it":"Mostra costo di produzione e margine","en":"Show production cost and margin",
                    "es":"Mostrar coste de producción y margen","fr":"Afficher coût de production et marge"],
        "qTitle": ["it":"Preventivo","en":"Quote","es":"Presupuesto","fr":"Devis"],
        "qValidUntil": ["it":"Valido fino al %@","en":"Valid until %@","es":"Válido hasta el %@","fr":"Valable jusqu'au %@"],
        "qFor": ["it":"Per","en":"For","es":"Para","fr":"Pour"],
        "qProject": ["it":"Oggetto","en":"Subject","es":"Objeto","fr":"Objet"],
        "qProduction": ["it":"Costo di produzione","en":"Production cost","es":"Coste de producción","fr":"Coût de production"],
        "qMarginLine": ["it":"Lavorazione e margine","en":"Labor and margin","es":"Trabajo y margen","fr":"Main-d'œuvre et marge"],
        "qTotal": ["it":"Prezzo finale","en":"Final price","es":"Precio final","fr":"Prix final"],
        "qExport": ["it":"Esporta PDF","en":"Export PDF","es":"Exportar PDF","fr":"Exporter PDF"],
        "qExported": ["it":"Preventivo esportato ✓","en":"Quote exported ✓","es":"Presupuesto exportado ✓","fr":"Devis exporté ✓"],
        "qEmpty": ["it":"Carica e slica dei file: il preventivo nasce dal loro costo reale.",
                   "en":"Load and slice some files: the quote is built from their real cost.",
                   "es":"Carga y lamina archivos: el presupuesto nace de su coste real.",
                   "fr":"Chargez et découpez des fichiers : le devis naît de leur coût réel."],
        "plateMoreHint": ["it":"I piatti spenti non sono ancora slicati: toccali per selezionarli, poi premi Slica.",
                          "en":"Dimmed plates aren't sliced yet: tap to select them, then hit Slice.",
                          "es":"Las placas apagadas aún no están laminadas: tócalas para seleccionarlas y pulsa Laminar.",
                          "fr":"Les plateaux éteints ne sont pas encore découpés : touchez-les pour les sélectionner, puis lancez Découper."],
        "platesFailed": ["it":"Piatti non slicabili: %@ — aprili in Bambu Studio",
                         "en":"Plates that couldn't be sliced: %@ — open them in Bambu Studio",
                         "es":"Placas no laminables: %@ — ábrelas en Bambu Studio",
                         "fr":"Plateaux non découpables : %@ — ouvrez-les dans Bambu Studio"],
        "sliceFailed": ["it":"Slicing fallito — riprova o aprilo in Bambu Studio",
                        "en":"Slicing failed — retry or open it in Bambu Studio",
                        "es":"Laminado fallido — reintenta o ábrelo en Bambu Studio",
                        "fr":"Découpe échouée — réessayez ou ouvrez-le dans Bambu Studio"],
        "noBambuShort": ["it":"Bambu Studio non trovato — indica il percorso in Costi & Setup",
                         "en":"Bambu Studio not found — set its path in Costs & Setup",
                         "es":"Bambu Studio no encontrado — indica la ruta en Costes y Setup",
                         "fr":"Bambu Studio introuvable — indiquez le chemin dans Coûts & Setup"],
        "dropHere": ["it":"Trascina qui i .3mf  ·  oppure clicca per sceglierli","en":"Drop .3mf here  ·  or click to choose","es":"Arrastra .3mf aquí  ·  o haz clic para elegir","fr":"Déposez les .3mf ici  ·  ou cliquez pour choisir"],
        "noFiles": ["it":"Nessun file caricato.","en":"No files loaded.","es":"Ningún archivo cargado.","fr":"Aucun fichier chargé."],
        "thFile": ["it":"File","en":"File","es":"Archivo","fr":"Fichier"],
        "thPlates": ["it":"Piatti","en":"Plates","es":"Placas","fr":"Plateaux"],
        "thTime": ["it":"Tempo","en":"Time","es":"Tiempo","fr":"Temps"],
        "thGrams": ["it":"Grammi","en":"Grams","es":"Gramos","fr":"Grammes"],
        "thEnergy": ["it":"Corrente","en":"Energy","es":"Energía","fr":"Énergie"],
        "thSpool": ["it":"Bobina","en":"Spool","es":"Bobina","fr":"Bobine"],
        "thQty": ["it":"Bobine","en":"Spools","es":"Bobinas","fr":"Bobines"],
        "thUnit": ["it":"€/bobina","en":"€/spool","es":"€/bobina","fr":"€/bobine"],
        "thTot": ["it":"Totale","en":"Total","es":"Total","fr":"Total"],
        "total": ["it":"Totale","en":"Total","es":"Total","fr":"Total"],
        "sColors": ["it":"Prezzo per bobina in base alla scelta filamento; sconti quantità Bambu applicati in automatico.",
                    "en":"Per-spool price based on the filament choice; Bambu volume discounts applied automatically.",
                    "es":"Precio por bobina según la elección de filamento; descuentos por volumen de Bambu automáticos.",
                    "fr":"Prix par bobine selon le choix de filament; remises quantité Bambu automatiques."],
        "noColors": ["it":"Carica dei file per vedere i colori.","en":"Load files to see colors.","es":"Carga archivos para ver colores.","fr":"Chargez des fichiers pour voir les couleurs."],
        "slice": ["it":"Slica","en":"Slice","es":"Laminar","fr":"Découper"],
        "sPlates": ["it":"Piatti leggeri dello stesso colore accorpabili su un piatto H2C: meno riscaldamenti e cambi manuali.",
                    "en":"Light same-color plates you can merge on one H2C bed: fewer heat-ups and manual swaps.",
                    "es":"Placas ligeras del mismo color combinables en una H2C: menos calentamientos y cambios manuales.",
                    "fr":"Plateaux légers de même couleur à fusionner sur un lit H2C: moins de chauffes et de changements."],
        "noPlates": ["it":"Carica dei file per i consigli.","en":"Load files for advice.","es":"Carga archivos para consejos.","fr":"Chargez des fichiers pour les conseils."],
        "rule": ["it":"Regola d'oro: accorpa solo pezzi dello stesso colore. Risparmio stimato:",
                 "en":"Golden rule: merge only same-color parts. Estimated saving:",
                 "es":"Regla de oro: combina solo piezas del mismo color. Ahorro estimado:",
                 "fr":"Règle d'or: fusionnez seulement les pièces de même couleur. Économie estimée:"],
        "hours": ["it":"ore","en":"hours","es":"horas","fr":"heures"],
        "sSetup": ["it":"I valori si applicano subito a tutti i calcoli.","en":"Values apply instantly to every calculation.","es":"Los valores se aplican al instante.","fr":"Les valeurs s'appliquent instantanément."],
        "fPrinter": ["it":"Stampante (precompila i watt)","en":"Printer (pre-fills wattage)","es":"Impresora (rellena vatios)","fr":"Imprimante (pré-remplit les watts)"],
        "fWatts": ["it":"Potenza media in stampa (W)","en":"Average printing power (W)","es":"Potencia media (W)","fr":"Puissance moyenne (W)"],
        "fKwh": ["it":"Energia — costo marginale (€/kWh)","en":"Energy — marginal cost (€/kWh)","es":"Energía — coste marginal (€/kWh)","fr":"Énergie — coût marginal (€/kWh)"],
        "fSource": ["it":"Filamento","en":"Filament","es":"Filamento","fr":"Filament"],
        "srcRefill": ["it":"Bambu refill","en":"Bambu refill","es":"Bambu recarga","fr":"Bambu recharge"],
        "srcSpool": ["it":"Bambu con bobina","en":"Bambu with spool","es":"Bambu con bobina","fr":"Bambu avec bobine"],
        "srcOther": ["it":"Altra marca","en":"Other brand","es":"Otra marca","fr":"Autre marque"],
        "fMsrp": ["it":"Listino refill 1 kg (€)","en":"Refill MSRP 1 kg (€)","es":"PVP recarga 1 kg (€)","fr":"Prix recharge 1 kg (€)"],
        "fSpoolPrice": ["it":"Prezzo con bobina 1 kg (€)","en":"With-spool price 1 kg (€)","es":"Precio con bobina 1 kg (€)","fr":"Prix avec bobine 1 kg (€)"],
        "fOtherBrand": ["it":"Nome marca","en":"Brand name","es":"Nombre marca","fr":"Nom marque"],
        "fOtherPrice": ["it":"Prezzo bobina 1 kg (€)","en":"Spool price 1 kg (€)","es":"Precio bobina 1 kg (€)","fr":"Prix bobine 1 kg (€)"],
        "tierNote": ["it":"Sconti Bambu: −35% da 4 · −45% da 6 · −50% da 10 (auto sul totale bobine)",
                     "en":"Bambu discounts: −35% at 4 · −45% at 6 · −50% at 10 (auto on total spools)",
                     "es":"Descuentos Bambu: −35% desde 4 · −45% desde 6 · −50% desde 10 (auto)",
                     "fr":"Remises Bambu: −35% dès 4 · −45% dès 6 · −50% dès 10 (auto)"],
        "otherNote": ["it":"Prezzo fisso per bobina, senza sconti quantità.","en":"Flat per-spool price, no volume discount.","es":"Precio fijo por bobina, sin descuentos.","fr":"Prix fixe par bobine, sans remise."],
        "full": ["it":"listino pieno","en":"full price","es":"precio lleno","fr":"plein tarif"],
        "t4": ["it":"−35% (4+)","en":"−35% (4+)","es":"−35% (4+)","fr":"−35% (4+)"],
        "t6": ["it":"−45% (6+)","en":"−45% (6+)","es":"−45% (6+)","fr":"−45% (6+)"],
        "t10": ["it":"−50% (10+)","en":"−50% (10+)","es":"−50% (10+)","fr":"−50% (10+)"],
        "other": ["it":"Altra","en":"Other","es":"Otra","fr":"Autre"],
        "busy": ["it":"Slicing di %@ con Bambu Studio…","en":"Slicing %@ with Bambu Studio…","es":"Laminando %@ con Bambu Studio…","fr":"Découpage de %@ avec Bambu Studio…"],
        // sezioni nuove
        "nMaterials": ["it":"Materiali","en":"Materials","es":"Materiales","fr":"Matériaux"],
        "nPrinters": ["it":"Stampanti","en":"Printers","es":"Impresoras","fr":"Imprimantes"],
        // costo reale
        "realCost": ["it":"Costo reale della stampa","en":"Real print cost","es":"Coste real de impresión","fr":"Coût réel d'impression"],
        "cMaterial": ["it":"Materiale consumato","en":"Material used","es":"Material usado","fr":"Matériau utilisé"],
        "cEnergy": ["it":"Energia","en":"Energy","es":"Energía","fr":"Énergie"],
        "cWear": ["it":"Usura macchina","en":"Machine wear","es":"Desgaste máquina","fr":"Usure machine"],
        "cSetup": ["it":"Avvii / setup","en":"Setup / starts","es":"Arranques","fr":"Démarrages"],
        "cFailure": ["it":"Fallimenti","en":"Failures","es":"Fallos","fr":"Échecs"],
        "cTotal": ["it":"Costo reale totale","en":"Total real cost","es":"Coste real total","fr":"Coût réel total"],
        "cUpfront": ["it":"Bobine da comprare (spesa iniziale)","en":"Spools to buy (upfront)","es":"Bobinas a comprar (inicial)","fr":"Bobines à acheter (initial)"],
        "matReal": ["it":"Materiale (reale)","en":"Material (real)","es":"Material (real)","fr":"Matériau (réel)"],
        "openSection": ["it":"Apri la sezione","en":"Open section","es":"Abrir la sección","fr":"Ouvrir la section"],
        "thUsed": ["it":"Consumato","en":"Used","es":"Consumido","fr":"Consommé"],
        "usedColors": ["it":"Colori usati nel progetto","en":"Colors used in this project","es":"Colores usados en el proyecto","fr":"Couleurs utilisées dans le projet"],
        "updateAvail": ["it":"È disponibile la versione %@","en":"Version %@ is available","es":"La versión %@ está disponible","fr":"La version %@ est disponible"],
        "updateGet": ["it":"Scarica","en":"Download","es":"Descargar","fr":"Télécharger"],
        "errGcode": ["it":"Questo file non è un .3mf: dallo slicer esporta il «file del piatto slicato» (.gcode.3mf), non il G-code puro.",
                     "en":"That file isn't a .3mf: from your slicer export the \u{201C}plate sliced file\u{201D} (.gcode.3mf), not the plain G-code.",
                     "es":"Ese archivo no es un .3mf: desde el laminador exporta el «archivo de placa laminado» (.gcode.3mf), no el G-code puro.",
                     "fr":"Ce fichier n'est pas un .3mf : depuis le slicer, exportez le « fichier de plateau découpé » (.gcode.3mf), pas le G-code brut."],
        "matUsed": ["it":"consumato in stampa","en":"used in this print","es":"usado en impresión","fr":"utilisé à l'impression"],
        "ifBuy": ["it":"se le compri","en":"if you buy them","es":"si las compras","fr":"si vous les achetez"],
        // materiali
        "sMaterials": ["it":"Il costo reale usa il €/kg e la densità del materiale abbinato a ogni colore.","en":"Real cost uses each color's material €/kg and density.","es":"El coste real usa €/kg y densidad de cada material.","fr":"Le coût réel utilise le €/kg et la densité de chaque matériau."],
        "mName": ["it":"Nome","en":"Name","es":"Nombre","fr":"Nom"],
        "mType": ["it":"Tipo","en":"Type","es":"Tipo","fr":"Type"],
        "mColor": ["it":"Colore","en":"Color","es":"Color","fr":"Couleur"],
        "mCost": ["it":"€/kg","en":"€/kg","es":"€/kg","fr":"€/kg"],
        "mDensity": ["it":"Densità g/cm³","en":"Density g/cm³","es":"Densidad g/cm³","fr":"Densité g/cm³"],
        "mStock": ["it":"Scorta kg","en":"Stock kg","es":"Stock kg","fr":"Stock kg"],
        "addMaterial": ["it":"Aggiungi materiale","en":"Add material","es":"Añadir material","fr":"Ajouter matériau"],
        "blankMaterial": ["it":"Vuoto (personalizzato)","en":"Blank (custom)","es":"Vacío (personalizado)","fr":"Vide (personnalisé)"],
        "mSale": ["it":"Offerta €/kg","en":"Sale €/kg","es":"Oferta €/kg","fr":"Promo €/kg"],
        "checkOffers": ["it":"Verifica offerte","en":"Check offers","es":"Ver ofertas","fr":"Voir offres"],
        "onSaleBadge": ["it":"offerta","en":"sale","es":"oferta","fr":"promo"],
        "offersNote": ["it":"Imposta il prezzo in offerta che trovi: verrà usato al posto del listino nel costo reale. I link aprono gli store per controllare le promo.","en":"Enter the sale price you find: it's used instead of list price in the real cost. Links open the stores to check promos.","es":"Introduce el precio de oferta: se usa en vez del de lista. Los enlaces abren las tiendas.","fr":"Saisissez le prix promo: utilisé au lieu du tarif. Les liens ouvrent les boutiques."],
        "fAmazon": ["it":"Tag affiliato Amazon.it","en":"Amazon.it affiliate tag","es":"Tag afiliado Amazon.it","fr":"Tag affilié Amazon.it"],
        "amazonHint": ["it":"Il tuo tag Associates (es. iltuonome-21). Viene agganciato ai link Amazon dei filamenti.","en":"Your Associates tag (e.g. yourname-21). Added to the filament Amazon links.","es":"Tu tag Associates (p.ej. tunombre-21). Se añade a los enlaces de Amazon.","fr":"Votre tag Associates (ex. votrenom-21). Ajouté aux liens Amazon."],
        "amazonSearch": ["it":"Cerca su Amazon","en":"Search on Amazon","es":"Buscar en Amazon","fr":"Chercher sur Amazon"],
        "madeBy": ["it":"Creata da","en":"Made by","es":"Creada por","fr":"Créée par"],
        "followFree": ["it":"App gratuita — se ti è utile, seguimi 🙌","en":"Free app — if it helps, follow me 🙌","es":"App gratis — si te sirve, sígueme 🙌","fr":"App gratuite — si utile, suivez-moi 🙌"],
        "affiliate": ["it":"In qualità di Affiliato Amazon, ricevo un guadagno dagli acquisti idonei.","en":"As an Amazon Associate I earn from qualifying purchases.","es":"Como Afiliado de Amazon, gano con las compras que cumplen los requisitos.","fr":"En tant que Partenaire Amazon, je réalise un bénéfice sur les achats remplissant les conditions requises."],
        // schermata di sblocco
        "gateTitle": ["it":"App gratuita","en":"Free app","es":"App gratis","fr":"App gratuite"],
        "gateBody": ["it":"Questa app è gratis. In cambio ti chiedo solo un follow: apri uno dei miei profili qui sotto e seguimi, poi sblocca con Telegram.","en":"This app is free. In return I just ask for a follow: open one of my profiles below and follow me, then unlock with Telegram.","es":"Esta app es gratis. A cambio solo te pido un follow: abre uno de mis perfiles aquí abajo y sígueme, luego desbloquea con Telegram.","fr":"Cette app est gratuite. En échange, juste un follow : ouvrez un de mes profils ci-dessous et suivez-moi, puis déverrouillez avec Telegram."],
        "gateLocked": ["it":"Si attiva dopo che hai aperto uno dei profili qui sopra.","en":"Unlocks after you open one of the profiles above.","es":"Se activa después de abrir uno de los perfiles de arriba.","fr":"S'active après l'ouverture d'un des profils ci-dessus."],
        "gateStep": ["it":"Poi inserisci il codice di sblocco che trovi sul mio profilo/canale.","en":"Then enter the unlock code you'll find on my profile/channel.","es":"Luego introduce el código de desbloqueo de mi perfil/canal.","fr":"Puis entrez le code de déblocage sur mon profil/canal."],
        "gateCode": ["it":"Codice di sblocco","en":"Unlock code","es":"Código de desbloqueo","fr":"Code de déblocage"],
        "gateUnlock": ["it":"Sblocca l'app","en":"Unlock the app","es":"Desbloquear","fr":"Déverrouiller"],
        "gateWrong": ["it":"Codice non valido. Controlla sul profilo/canale che segui.","en":"Invalid code. Check on the profile/channel you follow.","es":"Código no válido. Míralo en el perfil/canal.","fr":"Code invalide. Vérifiez sur le profil/canal."],
        "gateThanks": ["it":"Grazie per il supporto! 🙌","en":"Thanks for the support! 🙌","es":"¡Gracias por el apoyo! 🙌","fr":"Merci pour le soutien ! 🙌"],
        "gateTelegram": ["it":"Sblocca con Telegram","en":"Unlock with Telegram","es":"Desbloquear con Telegram","fr":"Déverrouiller avec Telegram"],
        "gateTgHint": ["it":"Iscriviti al canale e il bot sblocca l'app da solo — nessun codice da scrivere.","en":"Join the channel and the bot unlocks the app for you — no codes to type.","es":"Únete al canal y el bot desbloquea la app — sin códigos.","fr":"Rejoignez le canal et le bot déverrouille l'app — sans code."],
        "gateOr": ["it":"Non usi Telegram? Seguimi qui e continua:","en":"No Telegram? Follow me here and continue:","es":"¿Sin Telegram? Sígueme aquí y continúa:","fr":"Pas de Telegram ? Suivez-moi ici et continuez :"],
        "gateHonor": ["it":"Ho seguito, continua","en":"I followed, continue","es":"Ya te sigo, continuar","fr":"Je vous suis, continuer"],
        "gateCodeMobile": ["it":"Il link non si apre? Incolla qui il codice completo che ti manda il bot:","en":"Link won't open? Paste the full code the bot sends you:","es":"¿No se abre el enlace? Pega aquí el código completo del bot:","fr":"Le lien ne s'ouvre pas ? Collez ici le code complet du bot :"],
        "gateCodePlaceholder": ["it":"CODICE","en":"CODE","es":"CÓDIGO","fr":"CODE"],
        "gateCodeWrong": ["it":"Codice non valido o scaduto.","en":"Invalid or expired code.","es":"Código no válido o caducado.","fr":"Code invalide ou expiré."],
        "resetDefaults": ["it":"Ripristina predefiniti","en":"Reset defaults","es":"Restaurar valores","fr":"Réinitialiser"],
        // stampanti
        "sPrinters": ["it":"Potenza, usura oraria e costo di avvio entrano nel costo reale.","en":"Wattage, hourly wear and startup cost feed the real cost.","es":"Potencia, desgaste y arranque entran en el coste real.","fr":"Puissance, usure et démarrage alimentent le coût réel."],
        "pName": ["it":"Stampante","en":"Printer","es":"Impresora","fr":"Imprimante"],
        "pWatts": ["it":"Watt","en":"Watts","es":"Vatios","fr":"Watts"],
        "pWear": ["it":"Usura €/h","en":"Wear €/h","es":"Desgaste €/h","fr":"Usure €/h"],
        "pSetup": ["it":"Setup €","en":"Setup €","es":"Setup €","fr":"Setup €"],
        "addPrinter": ["it":"Aggiungi stampante","en":"Add printer","es":"Añadir impresora","fr":"Ajouter imprimante"],
        "selected": ["it":"In uso","en":"In use","es":"En uso","fr":"En usage"],
        // setup
        "fFailure": ["it":"Tasso di fallimento stampe (%)","en":"Print failure rate (%)","es":"Tasa de fallos (%)","fr":"Taux d'échec (%)"],
        "failureNote": ["it":"Quota aggiunta al costo per coprire le stampe fallite/riprovate.","en":"Added to cost to cover failed/retried prints.","es":"Añadido al coste para cubrir fallos.","fr":"Ajouté au coût pour couvrir les échecs."],
        "wearHint": ["it":"Usura = prezzo macchina ÷ ore di vita utile. Es. 1500€ / 12000h ≈ 0,12 €/h.","en":"Wear = machine price ÷ useful-life hours. E.g. 1500€ / 12000h ≈ 0.12 €/h.","es":"Desgaste = precio ÷ horas de vida. Ej. 1500€ / 12000h ≈ 0,12 €/h.","fr":"Usure = prix ÷ heures de vie. Ex. 1500€ / 12000h ≈ 0,12 €/h."],
        // orientamento 3D
        "nOrient": ["it":"Orienta 3D","en":"3D orient","es":"Orientar 3D","fr":"Orienter 3D"],
        "sOrient": ["it":"Carica STL / STEP / OBJ: ti mostro come orientarlo per meno supporti, poi lo slico e lo aggiungo ai costi.","en":"Load STL / STEP / OBJ: see how to orient it for fewer supports, then slice it into the costs.","es":"Carga STL / STEP / OBJ: te muestro cómo orientarlo con menos soportes y lo laminó.","fr":"Chargez STL / STEP / OBJ: voyez comment l'orienter avec moins de supports, puis découpe."],
        "loadModel": ["it":"Carica modello 3D","en":"Load 3D model","es":"Cargar modelo 3D","fr":"Charger modèle 3D"],
        "noModel": ["it":"Nessun modello caricato.","en":"No model loaded.","es":"Ningún modelo cargado.","fr":"Aucun modèle chargé."],
        "poseName": ["it":"Posa","en":"Pose","es":"Pose","fr":"Pose"],
        "poseHeight": ["it":"Altezza","en":"Height","es":"Altura","fr":"Hauteur"],
        "poseSupport": ["it":"Supporti","en":"Supports","es":"Soportes","fr":"Supports"],
        "poseFootprint": ["it":"Base","en":"Footprint","es":"Base","fr":"Base"],
        "poseBest": ["it":"Consigliata","en":"Best","es":"Mejor","fr":"Meilleure"],
        "threshold": ["it":"Angolo sbalzo supporti (°)","en":"Support overhang angle (°)","es":"Ángulo voladizo (°)","fr":"Angle de surplomb (°)"],
        "sliceOriented": ["it":"Slica questa posa e aggiungi ai costi","en":"Slice this pose and add to costs","es":"Laminar esta pose y añadir","fr":"Découper cette pose et ajouter"],
        "orientHint": ["it":"Meno supporti = meno materiale sprecato e pulizia. Più bassa = più veloce e stabile.","en":"Fewer supports = less wasted material and cleanup. Lower = faster and more stable.","es":"Menos soportes = menos desperdicio. Más baja = más rápida.","fr":"Moins de supports = moins de gaspillage. Plus basse = plus rapide."],
        // gruppi menu + selezione piatti
        "grpProject": ["it":"Progetto","en":"Project","es":"Proyecto","fr":"Projet"],
        "grpSettings": ["it":"Impostazioni","en":"Settings","es":"Ajustes","fr":"Réglages"],
        "plateHint": ["it":"Tocca un piatto per includerlo o escluderlo dal calcolo.","en":"Tap a plate to include or exclude it from the totals.","es":"Toca una placa para incluirla o excluirla.","fr":"Touchez un plateau pour l'inclure ou l'exclure."],
        "platesOn": ["it":"su","en":"of","es":"de","fr":"sur"],
        // valuta
        "fCurrency": ["it":"Valuta","en":"Currency","es":"Moneda","fr":"Devise"],
        "fRate": ["it":"Tasso da EUR (1 € = …)","en":"Rate from EUR (1 € = …)","es":"Cambio desde EUR (1 € = …)","fr":"Taux depuis EUR (1 € = …)"],
        "currencyNote": ["it":"I prezzi sono in euro; qui converto per la vista. Si allinea alla lingua, ma tasso e valuta sono modificabili.","en":"Prices are in euro; converted here for display. Follows the language, but rate and currency are editable.","es":"Los precios están en euros; se convierten aquí. Sigue el idioma, pero es editable.","fr":"Les prix sont en euros; convertis ici. Suit la langue, mais modifiable."],
    ]
}

// MARK: - Stato applicazione

@MainActor
final class AppModel: ObservableObject {
    @Published var files: [LoadedFile] = []
    @Published var watts: Double = 180
    @Published var kwh: Double = 0.209 { didSet { persist() } }
    @Published var section: Section = .overview
    @Published var busy: String? = nil

    @Published var lang: Lang = {
        if let s = UserDefaults.standard.string(forKey: "lang"), let l = Lang(rawValue: s) { return l }
        let sys = Locale.current.language.languageCode?.identifier ?? "en"
        return Lang(rawValue: sys) ?? .en   // ripiego inglese per le lingue non tradotte
    }() { didSet {
        UserDefaults.standard.set(lang.rawValue, forKey: "lang")
        // cambiando lingua, allinea la valuta (e il tasso di default)
        currency = lang.defaultCurrency; eurRate = currency.defaultRate
    } }

    @Published var currency: Currency = .eur { didSet { Money.currency = currency; persist() } }
    @Published var eurRate: Double = 1.0 { didSet { Money.rate = eurRate; persist() } }
    // tag affiliato BLOCCATO al valore incorporato: non modificabile dall'utente (app dell'autore)
    func amazonURL(_ query: String) -> String { Store.amazonSearch(query, tag: Store.defaultAmazonTag) }

    // Sblocco: verifica Telegram (token firmato via deep-link) oppure "onore" per IG/MakerWorld
    @Published var unlocked: Bool = UserDefaults.standard.bool(forKey: "app_unlocked")
    /// il passaggio Telegram del gate si attiva solo dopo aver aperto uno dei profili social
    @Published var followClicked: Bool = UserDefaults.standard.bool(forKey: "follow_clicked")
    func followTapped(_ url: String) {
        openSocial(url)
        followClicked = true
        UserDefaults.standard.set(true, forKey: "follow_clicked")
    }
    private func setUnlocked() { unlocked = true; UserDefaults.standard.set(true, forKey: "app_unlocked") }
    func unlockHonor() { setUnlocked() }
    /// sblocco cross-device: codice corto ricevuto dal bot (per chi usa Telegram dal telefono)
    @discardableResult
    func tryUnlockCode(_ code: String) -> Bool {
        let ok = Verify.validCode(code)
        if ok { setUnlocked() }
        return ok
    }
    /// Apre un link social. Per i link Telegram usa l'app nativa (tg://) quando è installata:
    /// evita la scheda t.me nel browser che poi rilancia Telegram a ogni avvio del browser.
    func openSocial(_ url: String) {
        if let deep = Author.telegramDeepLink(url), let d = URL(string: deep),
           NSWorkspace.shared.urlForApplication(toOpen: d) != nil {
            NSWorkspace.shared.open(d); return
        }
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }

    /// gestisce il ritorno dal bot: printcost://unlock?t=<exp>.<hmac>
    func handleURL(_ url: URL) {
        guard url.scheme?.lowercased() == Author.urlScheme else { return }
        let isUnlock = (url.host == "unlock") || url.path.contains("unlock")
        guard isUnlock,
              let t = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "t" })?.value,
              Verify.validToken(t) else { return }
        setUnlocked()
    }

    func t(_ k: String) -> String { Loc.s[k]?[lang.rawValue] ?? Loc.s[k]?["en"] ?? k }

    enum FilamentSource: String, CaseIterable { case bambuRefill, bambuSpool, other }
    @Published var source: FilamentSource = .bambuRefill
    @Published var msrp: Double = 22.99
    @Published var spoolPrice: Double = 25.99
    @Published var otherBrand: String = "Generico"
    @Published var otherPrice: Double = 20.0

    // Database persistenti + parametri costo "maker"
    @Published var materials: [Material] = [] { didSet { persist() } }
    @Published var printersDB: [PrinterProfile] = [] { didSet { persist() } }
    @Published var selPrinterID: UUID? { didSet { if let p = selectedPrinter { watts = p.watts }; persist() } }
    @Published var failurePct: Double = 7 { didSet { persist() } }
    // slicing integrato: ugello e altezza layer scelti (v1.2)
    @Published var nozzle: Double = 0.4 { didSet { persist() } }
    @Published var layerHeight: Double = 0.20 { didSet { persist() } }

    init() {
        let s = Store.load()
        materials = s.materials; printersDB = s.printers; failurePct = s.failurePct; kwh = s.kwh
        nozzle = s.nozzle ?? 0.4
        layerHeight = s.layerHeight ?? 0.20
        history = s.history ?? []
        quote = s.quote ?? QuoteSettings()
        currency = Currency(rawValue: s.currency ?? "eur") ?? .eur
        eurRate = s.eurRate ?? currency.defaultRate
        Money.currency = currency; Money.rate = eurRate
        selPrinterID = s.printers.first?.id
        if let p = s.printers.first { watts = p.watts }
        checkUpdate()
    }

    // MARK: - Controllo aggiornamenti (release GitHub più recente; muto se offline)
    @Published var updateTag: String? = nil
    func checkUpdate() {
        guard let url = URL(string: "https://api.github.com/repos/emanueletech/3d-print-cost/releases/latest") else { return }
        var req = URLRequest(url: url); req.timeoutInterval = 8
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let cur = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
            let a = parts(latest), b = parts(cur)
            var newer = false
            for i in 0..<max(a.count, b.count) {
                let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
                if x != y { newer = x > y; break }
            }
            if newer { DispatchQueue.main.async { self.updateTag = tag } }
        }.resume()
    }
    func persist() {
        // evita salvataggi durante l'init
        guard !materials.isEmpty || !printersDB.isEmpty else { return }
        Store.save(StoreData(materials: materials, printers: printersDB, failurePct: failurePct, kwh: kwh,
                             currency: currency.rawValue, eurRate: eurRate, amazonTag: nil,
                             nozzle: nozzle, layerHeight: layerHeight, history: history, quote: quote))
    }
    var selectedPrinter: PrinterProfile? { printersDB.first { $0.id == selPrinterID } ?? printersDB.first }

    /// Nome dell'app slicer per un motore della famiglia Orca.
    func slicerAppName(_ engine: String) -> String {
        switch engine {
        case "bambu": return "Bambu Studio"
        case "elegoo": return "ElegooSlicer"
        case "snapmaker": return "Snapmaker Orca"
        case "orca": return "OrcaSlicer"
        default: return "—"
        }
    }

    /// Percorso dell'app slicer installata per un motore, se presente (v1.2 M4).
    func slicerAppPath(_ engine: String) -> String? {
        let cands: [String]
        switch engine {
        case "elegoo": cands = ["/Applications/ElegooSlicer.app", "/Applications/Elegoo Slicer.app"]
        case "snapmaker": cands = ["/Applications/Snapmaker Orca.app", "/Applications/Snapmaker_Orca.app"]
        case "orca": cands = ["/Applications/OrcaSlicer.app"]
        case "bambu": cands = ["/Applications/BambuStudio.app"]
        default: return nil
        }
        return cands.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Apre il 3mf nello slicer della stampante selezionata (flusso manuale U1/Elegoo).
    func openInSlicer(_ f: LoadedFile) {
        guard let spec = selectedPrinter?.slicing, let app = slicerAppPath(spec.engine) else { return }
        NSWorkspace.shared.open([URL(fileURLWithPath: f.path)],
                                withApplicationAt: URL(fileURLWithPath: app),
                                configuration: NSWorkspace.OpenConfiguration())
    }

    /// materiale associato a un colore del progetto (per costo consumato a €/kg):
    /// match esatto sull'hex, altrimenti il colore più vicino (entro soglia), altrimenti nil.
    func material(forHex hex: String, type: String) -> Material? {
        let up = hex.uppercased()
        if let m = materials.first(where: { $0.colorHex.uppercased() == up && $0.type == type }) { return m }
        if let m = materials.first(where: { $0.colorHex.uppercased() == up }) { return m }
        // colore più vicino, preferendo lo stesso tipo
        func rgb(_ h: String) -> (Double,Double,Double)? {
            var s = h.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
            guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
            return (Double((v>>16)&0xff), Double((v>>8)&0xff), Double(v&0xff))
        }
        guard let c = rgb(up) else { return nil }
        var best: (Material, Double)? = nil
        for m in materials {
            guard let mc = rgb(m.colorHex) else { continue }
            var d = pow(c.0-mc.0,2)+pow(c.1-mc.1,2)+pow(c.2-mc.2,2)
            if m.type != type { d += 1200 }   // penalità tipo diverso
            if best == nil || d < best!.1 { best = (m, d) }
        }
        // accetta solo se ragionevolmente vicino (distanza RGB² < ~40² su un canale medio)
        if let b = best, b.1 < 4800 { return b.0 }
        return nil
    }

    /// €/kg di ripiego quando un colore non è in database (prezzo pieno di una bobina 1 kg)
    var fallbackCostPerKg: Double {
        switch source { case .bambuRefill: msrp; case .bambuSpool: spoolPrice; case .other: otherPrice }
    }

    enum Section: String, CaseIterable, Identifiable {
        case overview, files, orient, colors, materials, printers, plates, history, quote, setup
        var id: String { rawValue }
        var locKey: String { ["overview":"nOverview","files":"nFiles","orient":"nOrient","colors":"nColors","materials":"nMaterials","printers":"nPrinters","plates":"nPlates","history":"nHistory","quote":"nQuote","setup":"nSetup"][rawValue]! }
        var icon: String {
            switch self {
            case .overview: "square.grid.2x2.fill"; case .files: "doc.fill"; case .orient: "rotate.3d.fill"
            case .colors: "paintpalette.fill"
            case .materials: "cylinder.split.1x2.fill"; case .printers: "printer.fill"
            case .plates: "puzzlepiece.fill"; case .history: "book.closed.fill"
            case .quote: "doc.text.fill"; case .setup: "gearshape.fill"
            }
        }
    }

    var loaded: [LoadedFile] { files.filter { $0.analysis != nil } }
    // aggregazione sui soli piatti INCLUSI (rispetta le esclusioni per file)
    var includedPlates: [PlateInfo] { loaded.flatMap { $0.includedPlates } }
    var totalSeconds: Double { includedPlates.reduce(0) { $0 + $1.seconds } }
    var totalGrams: Double { includedPlates.reduce(0) { $0 + $1.grams } }
    var totalPlates: Int { includedPlates.count }

    var colorRows: [ColorRow] {
        var per: [String: Double] = [:]
        for p in includedPlates { for (k, g) in p.colorGrams { per[k, default: 0] += g } }
        return per.map { (k, g) in
            let parts = k.split(separator: "|", maxSplits: 1).map(String.init)
            return ColorRow(hex: parts[0], type: parts.count > 1 ? parts[1] : "PLA Basic", grams: g)
        }.sorted { $0.grams > $1.grams }
    }
    var totalSpools: Int { colorRows.reduce(0) { $0 + $1.spools } }

    var unitPrice: (price: Double, label: String) {
        func tierPct() -> (Double, String) {
            let n = totalSpools
            if n >= 10 { return (0.5, t("t10")) }
            if n >= 6 { return (0.55, t("t6")) }
            if n >= 4 { return (0.65, t("t4")) }
            return (1.0, t("full"))
        }
        switch source {
        case .bambuRefill: let (m, l) = tierPct(); return (msrp * m, "Bambu refill · \(l)")
        case .bambuSpool:  let (m, l) = tierPct(); return (spoolPrice * m, "Bambu bobina · \(l)")
        case .other:       return (otherPrice, otherBrand)
        }
    }
    var filamentCost: Double { Double(totalSpools) * unitPrice.price }
    var kWh: Double { totalSeconds / 3600 * watts / 1000 }
    var energyCost: Double { kWh * kwh }
    var totalHours: Double { totalSeconds / 3600 }

    /// Costo REALE della stampa (vista maker): materiale consumato + energia + usura + setup + fallimenti.
    var cost: CostBreakdown {
        var b = CostBreakdown()
        for r in colorRows {
            let perKg = material(forHex: r.hex, type: r.type)?.effectiveCostPerKg ?? fallbackCostPerKg
            b.material += r.grams / 1000.0 * perKg
        }
        b.energy = energyCost
        if let p = selectedPrinter {
            b.wear = totalHours * p.wearPerHour
            b.setup = Double(totalPlates) * p.setupCost
        }
        b.failure = b.base * failurePct / 100.0
        b.spools = filamentCost
        return b
    }

    struct MergeAdvice: Identifiable { let id = UUID(); let file: String; let colors: [String]; let from: [Int]; let to: Int; let saved: Int }
    var mergeAdvice: [MergeAdvice] {
        var out: [MergeAdvice] = []
        for f in loaded {
            var groups: [String: [PlateInfo]] = [:]
            for p in f.includedPlates {
                if p.seconds > 6*3600 && p.grams > 300 { continue }
                let key = p.colorKeys.sorted().joined(separator: "+")
                groups[key.isEmpty ? "x" : key, default: []].append(p)
            }
            for (key, plates) in groups where plates.count >= 2 {
                let target = max(1, Int(ceil(Double(plates.count)/3.0)))
                out.append(MergeAdvice(file: f.name.replacingOccurrences(of: ".3mf", with: ""),
                    colors: key.split(separator: "+").map(String.init),
                    from: plates.map { $0.index }, to: target, saved: (plates.count - target) * 8))
            }
        }
        return out.sorted { $0.saved > $1.saved }
    }

    func add(paths: [String]) {
        var rejected = false
        var added3mf = false
        for p in paths {
            let low = p.lowercased()
            if low.hasSuffix(".3mf") {
                let name = (p as NSString).lastPathComponent
                if files.contains(where: { $0.path == p }) { continue }
                let lf = LoadedFile(name: name, path: p, state: Slicer.analyze(p))
                files.append(lf)
                added3mf = true
                // anteprime piatti in background (non bloccano l'interfaccia)
                Task.detached {
                    let imgs = Slicer.thumbnails(p)
                    await MainActor.run { lf.thumbs = imgs }
                }
            } else if ["stl", "obj", "step", "stp"].contains((low as NSString).pathExtension) {
                section = .orient
                loadMesh(p)
            } else {
                rejected = true   // es. G-code puro: senza metadati 3mf non c'è nulla da leggere
            }
        }
        // un file nuovo porta dritti dove si lavora: File & Slicing
        if added3mf { section = .files }
        if rejected { flash("errGcode") }
    }

    /// Avviso temporaneo in basso (l'equivalente del toast dell'app desktop).
    @Published var notice: String? = nil
    func flash(_ key: String) { flashText(t(key)) }
    func flashText(_ msg: String) {
        notice = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            if self?.notice == msg { self?.notice = nil }
        }
    }
    func remove(_ f: LoadedFile) { files.removeAll { $0.id == f.id } }
    func togglePlate(_ f: LoadedFile, _ index: Int) {
        if f.excluded.contains(index) { f.excluded.remove(index) } else { f.excluded.insert(index) }
        objectWillChange.send()
    }
    func togglePick(_ f: LoadedFile, _ index: Int) {
        if f.toSlice.contains(index) { f.toSlice.remove(index) } else { f.toSlice.insert(index) }
        objectWillChange.send()
    }
    /// Tutte le spunte accese: piatti con dati inclusi nei conti, piatti spenti scelti per lo slicing.
    func selectAllPlates(_ f: LoadedFile) {
        f.excluded = []
        if let a = f.analysis, !f.thumbs.isEmpty {
            let have = Set(a.plates.map { $0.index })
            f.toSlice = Set((1...f.thumbs.count).filter { !have.contains($0) })
        }
        objectWillChange.send()
    }
    /// Tutte le spunte spente.
    func selectNoPlates(_ f: LoadedFile) {
        if let a = f.analysis {
            f.excluded = Set(a.plates.map { $0.index })
        } else if !f.thumbs.isEmpty {
            f.excluded = Set(1...f.thumbs.count)
        }
        f.toSlice = []
        objectWillChange.send()
    }
    /// `fresh` = rislica da capo coi parametri attuali (stampante/ugello/layer),
    /// anche se il file ha già un risultato.
    func slice(_ f: LoadedFile, fresh: Bool = false) {
        let path = f.path
        // file già slicato → giro incrementale sui piatti spenti selezionati;
        // altrimenti si slicano i piatti spuntati tra le anteprime (tutti, se tutti spuntati)
        let incremental = !fresh && f.analysis != nil
        let sel: [Int]
        if incremental {
            sel = f.toSlice.sorted()
            if sel.isEmpty { return }
        } else {
            let total = f.thumbs.count
            sel = total > 0 ? (1...total).filter { !f.excluded.contains($0) } : []
        }
        busy = String(format: t("busy"), f.name)
        // stampante non Bambu selezionata: i numeri escono comunque dal profilo H2C —
        // meglio dirlo subito, coi consumi veri che passano dall'export del suo slicer
        if let sp = selectedPrinter, let spec = sp.slicing, spec.engine != "bambu" {
            flashText(String(format: t("sliceOtherNote"), sp.name, slicerAppName(spec.engine)))
        }
        let name = f.name
        let nz = nozzle, lh = layerHeight
        let spSlicing = selectedPrinter?.slicing
        Task.detached {
            let st = Slicer.slice(path, plates: sel, nozzle: nz, layer: lh, spec: spSlicing) { k, total in
                // avanzamento piatto per piatto nella barra di lavoro
                let pct = Int(Double(k - 1) / Double(total) * 100)
                Task { @MainActor in
                    self.busy = String(format: self.t("busy"), name) + "  ·  \(k)/\(total) · \(pct)%"
                }
            }
            await MainActor.run {
                self.busy = nil
                if incremental {
                    f.toSlice = []
                    if case .sliced(let add) = st, case .sliced(var cur) = f.state {
                        cur.plates = (cur.plates + add.plates).sorted { $0.index < $1.index }
                        cur.seconds += add.seconds
                        cur.grams += add.grams
                        for (k, g) in add.perColor { cur.perColor[k, default: 0] += g }
                        let okIdx = Set(add.plates.map { $0.index })
                        cur.failed = Array(Set(cur.failed).subtracting(okIdx).union(add.failed)).sorted()
                        f.state = .sliced(cur)
                        if !add.failed.isEmpty {
                            self.flashText(String(format: self.t("platesFailed"),
                                                  add.failed.map(String.init).joined(separator: ", ")))
                        }
                    } else {
                        self.flash("sliceFailed")
                    }
                } else {
                    f.state = st
                    if case .sliced(let a) = st, !a.failed.isEmpty {
                        self.flashText(String(format: self.t("platesFailed"),
                                              a.failed.map(String.init).joined(separator: ", ")))
                    }
                }
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Confronto stampanti (v1.3)

    /// un lato della tabella comparativa: numeri e costo dei piatti per UNA stampante
    struct CompareSide {
        let printer: String
        let seconds: Double
        let grams: Double
        let kWh: Double
        let plateCount: Int
        let cost: CostBreakdown
    }
    struct CompareData: Identifiable {
        let id = UUID()
        let file: String
        let a: CompareSide      // stampante attuale, numeri già sulla scheda
        let b: CompareSide      // l'altra stampante, appena slicata
        let bFailed: [Int]      // piatti che coi profili di B non si sono slicati
    }
    @Published var compareData: CompareData? = nil

    /// stampanti Bambu proponibili come secondo termine di confronto
    var compareTargets: [PrinterProfile] {
        printersDB.filter { $0.slicing?.engine == "bambu" && $0.id != selectedPrinter?.id }
    }

    /// costo dei piatti dati coi parametri di una stampante (kwh/fallimenti globali)
    func sideBreakdown(_ plates: [PlateInfo], printer: PrinterProfile) -> CompareSide {
        var per: [String: Double] = [:]
        var secs = 0.0, grams = 0.0
        for p in plates {
            secs += p.seconds; grams += p.grams
            for (k, g) in p.colorGrams { per[k, default: 0] += g }
        }
        var b = CostBreakdown()
        for (k, g) in per {
            let parts = k.split(separator: "|", maxSplits: 1).map(String.init)
            let perKg = material(forHex: parts[0], type: parts.count > 1 ? parts[1] : "PLA Basic")?.effectiveCostPerKg ?? fallbackCostPerKg
            b.material += g / 1000 * perKg
        }
        let hours = secs / 3600
        b.energy = hours * printer.watts / 1000 * kwh
        b.wear = hours * printer.wearPerHour
        b.setup = Double(plates.count) * printer.setupCost
        b.failure = b.base * failurePct / 100
        return CompareSide(printer: printer.name, seconds: secs, grams: grams,
                           kWh: hours * printer.watts / 1000, plateCount: plates.count, cost: b)
    }

    /// Slica gli stessi piatti coi profili dell'altra stampante e apre la tabella comparativa.
    func compare(_ f: LoadedFile, with target: PrinterProfile) {
        guard let cur = selectedPrinter, f.analysis != nil else { return }
        let platesA = f.includedPlates
        let sel = platesA.map { $0.index }.sorted()
        guard !sel.isEmpty else { return }
        let path = f.path, name = f.name
        let nz = nozzle, lh = layerHeight, spec = target.slicing
        let base = String(format: t("cmpBusy"), name, target.name)
        busy = base
        Task.detached {
            let st = Slicer.slice(path, plates: sel, nozzle: nz, layer: lh, spec: spec) { k, total in
                let pct = Int(Double(k - 1) / Double(total) * 100)
                Task { @MainActor in self.busy = base + "  ·  \(k)/\(total) · \(pct)%" }
            }
            await MainActor.run {
                self.busy = nil
                guard case .sliced(let res) = st, !res.plates.isEmpty else {
                    if case .error("noBambu") = st { self.flash("noBambuShort") }
                    else { self.flashText(String(format: self.t("cmpFail"), target.name)) }
                    return
                }
                self.compareData = CompareData(file: name,
                                               a: self.sideBreakdown(platesA, printer: cur),
                                               b: self.sideBreakdown(res.plates, printer: target),
                                               bFailed: res.failed)
            }
        }
    }

    // MARK: - Storico & registro costi (v1.3)

    @Published var history: [HistoryEntry] = [] { didSet { persist() } }

    /// salva nel registro i piatti dati (costo con la stampante selezionata)
    func logEntry(name: String, plates: [PlateInfo]) {
        guard let p = selectedPrinter, !plates.isEmpty else { return }
        let s = sideBreakdown(plates, printer: p)
        history.insert(HistoryEntry(date: Date(), name: name, printer: p.name,
                                    plates: s.plateCount, grams: s.grams, seconds: s.seconds,
                                    material: s.cost.material, energy: s.cost.energy, wear: s.cost.wear,
                                    setup: s.cost.setup, failure: s.cost.failure, total: s.cost.total),
                       at: 0)
        flash("histSaved")
    }

    /// un'unica voce per tutto il progetto caricato (tutti i file, piatti inclusi)
    func logProject() {
        let names = loaded.map { $0.name.replacingOccurrences(of: ".3mf", with: "") }
        guard !names.isEmpty else { return }
        let name = names.count <= 2 ? names.joined(separator: " + ") : "\(names[0]) +\(names.count - 1)"
        logEntry(name: name, plates: includedPlates)
    }

    /// registro → CSV (separatore ;, decimali col punto, intestazione localizzata)
    func historyCSV() -> String {
        let head = [t("thDate"), t("thFile"), t("pName"), t("thPlates"), t("hHours"), t("thGrams"),
                    t("cMaterial"), t("cEnergy"), t("cWear"), t("cSetup"), t("cFailure"), t("cTotal")]
            .joined(separator: ";")
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        func cell(_ s: String) -> String { s.replacingOccurrences(of: ";", with: ",") }
        let rows = history.map { e in
            [iso.string(from: e.date), cell(e.name), cell(e.printer), String(e.plates),
             String(format: "%.2f", e.seconds / 3600), String(Int(e.grams.rounded())),
             String(format: "%.2f", e.material), String(format: "%.2f", e.energy),
             String(format: "%.2f", e.wear), String(format: "%.2f", e.setup),
             String(format: "%.2f", e.failure), String(format: "%.2f", e.total)]
                .joined(separator: ";")
        }
        return ([head] + rows).joined(separator: "\n") + "\n"
    }

    // MARK: - Preventivo per clienti (v1.3)

    @Published var quote = QuoteSettings() { didSet { persist() } }
    /// nome del cliente: per-preventivo, non finisce nello store
    @Published var quoteClient = ""

    /// margine e prezzo finale a partire dal costo reale del progetto caricato
    var quoteNumbers: (cost: Double, margin: Double, final: Double) {
        let c = cost.total
        let margin = quote.mode == "flat" ? quote.flat : c * quote.pct / 100
        return (c, margin, c + margin)
    }

    // MARK: - Orientamento 3D (STL/OBJ/STEP)
    @Published var meshName: String? = nil
    @Published var baseMesh: Mesh? = nil        // originale (non ruotato)
    @Published var mesh: Mesh? = nil            // posa corrente, appoggiata al piatto
    @Published var poses: [PoseStats] = []
    @Published var chosenPose: String? = nil
    @Published var supportThreshold: Double = 45 { didSet { recomputePoses() } }

    func loadMesh(_ path: String) {
        let ext = (path as NSString).pathExtension.lowercased()
        busy = "Carico \(( path as NSString).lastPathComponent)…"
        Task.detached {
            var p = path
            if ext == "step" || ext == "stp" { p = Slicer.stepToSTL(path) ?? path }
            let mesh = MeshLoader.load(p)
            await MainActor.run {
                self.busy = nil
                guard let mesh else { return }
                self.baseMesh = mesh
                self.meshName = (path as NSString).lastPathComponent
                self.chosenPose = "Originale"
                self.mesh = mesh.onBed()
                self.recomputePoses()
                self.section = .orient
            }
        }
    }
    func recomputePoses() {
        guard let bm = baseMesh else { poses = []; return }
        poses = Orient.candidates(bm, thresholdDeg: Float(supportThreshold)).sorted { $0.supportArea < $1.supportArea }
    }
    func applyPose(_ p: PoseStats) {
        guard let bm = baseMesh else { return }
        chosenPose = p.name
        mesh = bm.rotated(p.rot).onBed()
    }
    func sliceOriented() {
        guard let mesh, let name = meshName else { return }
        busy = String(format: t("busy"), name)
        Task.detached {
            let tmp = NSTemporaryDirectory() + "orient-\(UUID().uuidString).stl"
            _ = mesh.exportSTLbinary(to: tmp)
            let st = Slicer.sliceRaw(tmp)
            try? FileManager.default.removeItem(atPath: tmp)
            await MainActor.run {
                self.busy = nil
                if case .sliced = st {
                    let lf = LoadedFile(name: name, path: "mesh:" + name, state: st)
                    self.files.append(lf)
                    self.section = .overview
                }
            }
        }
    }
}

// MARK: - Format helpers

func hms(_ s: Double) -> String {
    let h = Int(s) / 3600, m = Int((s.truncatingRemainder(dividingBy: 3600)) / 60 + 0.5)
    return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
}
/// formatta un valore in EUR nella valuta attualmente selezionata (con conversione)
func eur(_ v: Double) -> String { Money.fmt(v) }
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(.sRGB, red: Double((v>>16)&0xff)/255, green: Double((v>>8)&0xff)/255, blue: Double(v&0xff)/255)
    }
}
