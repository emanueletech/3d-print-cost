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
        "sFiles": ["it":"I 3mf già slicati vengono letti al volo; quelli non slicati li slico con Bambu Studio (profilo H2C).",
                   "en":"Already-sliced 3mf are read instantly; unsliced ones are sliced with Bambu Studio (H2C profile).",
                   "es":"Los 3mf ya laminados se leen al instante; los no laminados se laminan con Bambu Studio (perfil H2C).",
                   "fr":"Les 3mf déjà découpés sont lus instantanément; les autres sont découpés avec Bambu Studio (profil H2C)."],
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
        let sys = Locale.current.language.languageCode?.identifier ?? "it"
        return Lang(rawValue: sys) ?? .it
    }() { didSet {
        UserDefaults.standard.set(lang.rawValue, forKey: "lang")
        // cambiando lingua, allinea la valuta (e il tasso di default)
        currency = lang.defaultCurrency; eurRate = currency.defaultRate
    } }

    @Published var currency: Currency = .eur { didSet { Money.currency = currency; persist() } }
    @Published var eurRate: Double = 1.0 { didSet { Money.rate = eurRate; persist() } }
    // tag affiliato BLOCCATO al valore incorporato: non modificabile dall'utente (app dell'autore)
    func amazonURL(_ query: String) -> String { Store.amazonSearch(query, tag: Store.defaultAmazonTag) }

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

    init() {
        let s = Store.load()
        materials = s.materials; printersDB = s.printers; failurePct = s.failurePct; kwh = s.kwh
        currency = Currency(rawValue: s.currency ?? "eur") ?? .eur
        eurRate = s.eurRate ?? currency.defaultRate
        Money.currency = currency; Money.rate = eurRate
        selPrinterID = s.printers.first?.id
        if let p = s.printers.first { watts = p.watts }
    }
    func persist() {
        // evita salvataggi durante l'init
        guard !materials.isEmpty || !printersDB.isEmpty else { return }
        Store.save(StoreData(materials: materials, printers: printersDB, failurePct: failurePct, kwh: kwh,
                             currency: currency.rawValue, eurRate: eurRate, amazonTag: nil))
    }
    var selectedPrinter: PrinterProfile? { printersDB.first { $0.id == selPrinterID } ?? printersDB.first }

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
        case overview, files, orient, colors, materials, printers, plates, setup
        var id: String { rawValue }
        var locKey: String { ["overview":"nOverview","files":"nFiles","orient":"nOrient","colors":"nColors","materials":"nMaterials","printers":"nPrinters","plates":"nPlates","setup":"nSetup"][rawValue]! }
        var icon: String {
            switch self {
            case .overview: "square.grid.2x2.fill"; case .files: "doc.fill"; case .orient: "rotate.3d.fill"
            case .colors: "paintpalette.fill"
            case .materials: "cylinder.split.1x2.fill"; case .printers: "printer.fill"
            case .plates: "puzzlepiece.fill"; case .setup: "gearshape.fill"
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
        for p in paths where p.lowercased().hasSuffix(".3mf") {
            let name = (p as NSString).lastPathComponent
            if files.contains(where: { $0.path == p }) { continue }
            let lf = LoadedFile(name: name, path: p, state: Slicer.analyze(p))
            files.append(lf)
            // anteprime piatti in background (non bloccano l'interfaccia)
            Task.detached {
                let imgs = Slicer.thumbnails(p)
                await MainActor.run { lf.thumbs = imgs }
            }
        }
    }
    func remove(_ f: LoadedFile) { files.removeAll { $0.id == f.id } }
    func togglePlate(_ f: LoadedFile, _ index: Int) {
        if f.excluded.contains(index) { f.excluded.remove(index) } else { f.excluded.insert(index) }
        objectWillChange.send()
    }
    func slice(_ f: LoadedFile) {
        busy = String(format: t("busy"), f.name)
        let path = f.path
        Task.detached {
            let st = Slicer.slice(path)
            await MainActor.run { f.state = st; self.objectWillChange.send(); self.busy = nil }
        }
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
