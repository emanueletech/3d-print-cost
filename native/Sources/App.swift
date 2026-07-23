import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Lingue

enum Lang: String, CaseIterable, Identifiable {
    case it, en, es, fr
    var id: String { rawValue }
    var flag: String { ["it":"🇮🇹","en":"🇬🇧","es":"🇪🇸","fr":"🇫🇷"][rawValue]! }
    var label: String { ["it":"Italiano","en":"English","es":"Español","fr":"Français"][rawValue]! }
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
        "thUnit": ["it":"€/cad","en":"€/ea","es":"€/ud","fr":"€/pce"],
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
    ]
}

// MARK: - Stato applicazione

@MainActor
final class AppModel: ObservableObject {
    @Published var files: [LoadedFile] = []
    @Published var watts: Double = 180
    @Published var kwh: Double = 0.209
    @Published var section: Section = .overview
    @Published var busy: String? = nil

    @Published var lang: Lang = {
        if let s = UserDefaults.standard.string(forKey: "lang"), let l = Lang(rawValue: s) { return l }
        let sys = Locale.current.language.languageCode?.identifier ?? "it"
        return Lang(rawValue: sys) ?? .it
    }() { didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") } }

    func t(_ k: String) -> String { Loc.s[k]?[lang.rawValue] ?? Loc.s[k]?["en"] ?? k }

    enum FilamentSource: String, CaseIterable { case bambuRefill, bambuSpool, other }
    @Published var source: FilamentSource = .bambuRefill
    @Published var msrp: Double = 22.99
    @Published var spoolPrice: Double = 25.99
    @Published var otherBrand: String = "Generico"
    @Published var otherPrice: Double = 20.0

    enum Section: String, CaseIterable, Identifiable {
        case overview, files, colors, plates, setup
        var id: String { rawValue }
        var locKey: String { ["overview":"nOverview","files":"nFiles","colors":"nColors","plates":"nPlates","setup":"nSetup"][rawValue]! }
        var icon: String {
            switch self {
            case .overview: "square.grid.2x2.fill"; case .files: "doc.fill"; case .colors: "paintpalette.fill"
            case .plates: "puzzlepiece.fill"; case .setup: "gearshape.fill"
            }
        }
    }

    let printers: [(String, Double)] = [
        ("Bambu Lab H2C", 180), ("Bambu Lab H2D", 180), ("Bambu Lab H2D Pro", 200),
        ("Bambu Lab H2S", 160), ("Bambu Lab X1C", 110), ("Bambu Lab P1S", 105),
        ("Bambu Lab A1", 80), ("—", 120)]

    var loaded: [LoadedFile] { files.filter { $0.analysis != nil } }
    var totalSeconds: Double { loaded.reduce(0) { $0 + $1.analysis!.seconds } }
    var totalGrams: Double { loaded.reduce(0) { $0 + $1.analysis!.grams } }
    var totalPlates: Int { loaded.reduce(0) { $0 + $1.analysis!.plates.count } }

    var colorRows: [ColorRow] {
        var per: [String: Double] = [:]
        for f in loaded { for (k, g) in f.analysis!.perColor { per[k, default: 0] += g } }
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

    struct MergeAdvice: Identifiable { let id = UUID(); let file: String; let colors: [String]; let from: [Int]; let to: Int; let saved: Int }
    var mergeAdvice: [MergeAdvice] {
        var out: [MergeAdvice] = []
        for f in loaded {
            var groups: [String: [PlateInfo]] = [:]
            for p in f.analysis!.plates {
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
            files.append(LoadedFile(name: name, path: p, state: Slicer.analyze(p)))
        }
    }
    func remove(_ f: LoadedFile) { files.removeAll { $0.id == f.id } }
    func slice(_ f: LoadedFile) {
        busy = String(format: t("busy"), f.name)
        let path = f.path
        Task.detached {
            let st = Slicer.slice(path)
            await MainActor.run { f.state = st; self.objectWillChange.send(); self.busy = nil }
        }
    }
}

// MARK: - Format helpers

func hms(_ s: Double) -> String {
    let h = Int(s) / 3600, m = Int((s.truncatingRemainder(dividingBy: 3600)) / 60 + 0.5)
    return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
}
func eur(_ v: Double) -> String {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "EUR"; f.locale = Locale(identifier: "it_IT")
    return f.string(from: NSNumber(value: v)) ?? "€\(v)"
}
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(.sRGB, red: Double((v>>16)&0xff)/255, green: Double((v>>8)&0xff)/255, blue: Double(v&0xff)/255)
    }
}
