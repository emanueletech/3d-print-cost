import Foundation
import CryptoKit

// MARK: - Verifica token di sblocco (firma Ed25519 del bot)
// Il bot firma con la chiave PRIVATA, che vive solo sul suo server; l'app
// incorpora la sola chiave PUBBLICA: nel sorgente e nel binario non c'è
// alcun segreto, quindi il repository può essere pubblico.
enum Verify {
    /// messaggio firmato = "printcost:unlock:<expiryUnix>"
    /// token = "<expiryUnix>.<firma Ed25519 in hex (128 caratteri)>"
    static func validToken(_ token: String) -> Bool {
        let parts = token.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, let exp = Double(parts[0]), exp >= Date().timeIntervalSince1970,
              let sig = Data(hexString: parts[1]), sig.count == 64,
              let raw = Data(hexString: Author.unlockPublicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
        else { return false }
        return key.isValidSignature(sig, for: Data("printcost:unlock:\(parts[0])".utf8))
    }

    /// codice incollato a mano nella schermata di sblocco: è lo stesso token
    static func validCode(_ input: String) -> Bool {
        validToken(input.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

extension Data {
    /// da stringa esadecimale (lunghezza pari); nil se non valida
    init?(hexString: String) {
        let s = hexString.lowercased()
        guard s.count % 2 == 0 else { return nil }
        var out = Data(capacity: s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let next = s.index(idx, offsetBy: 2)
            guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
            out.append(b)
            idx = next
        }
        self = out
    }
}

// MARK: - Valuta (i prezzi interni sono sempre in EUR; qui la conversione per la vista)

enum Currency: String, CaseIterable, Codable, Identifiable {
    case eur, gbp, usd, chf
    var id: String { rawValue }
    var code: String { rawValue.uppercased() }
    var symbol: String { ["eur":"€","gbp":"£","usd":"$","chf":"CHF"][rawValue]! }
    var localeId: String { ["eur":"it_IT","gbp":"en_GB","usd":"en_US","chf":"de_CH"][rawValue]! }
    /// tasso EUR→valuta (aggiornabile dall'utente); default reali al 23/07/2026
    var defaultRate: Double { ["eur":1.0,"gbp":0.8532,"usd":1.1392,"chf":0.9295][rawValue]! }
}

// MARK: - Autore & social (crediti in-app)
enum Author {
    static let name = "Emanuele"
    static let instagram = "https://www.instagram.com/emanuele_tech"
    static let telegram = "https://t.me/emanueletech"
    static let makerworld = "https://makerworld.com/en/@Emanuele_tech"
    static let youtube = "https://youtube.com/@emanuele_tech"
    static let tiktok = "https://www.tiktok.com/@emanuele_tech"
    static let linktree = "https://linktr.ee/emanuele_tech"
    /// deep-link al bot che verifica l'iscrizione al canale e rimanda lo sblocco
    static let telegramBot = "https://t.me/emanueletech_bot?start=unlock"
    /// chiave PUBBLICA Ed25519 (hex) che verifica i token firmati dal bot.
    /// La chiave privata sta solo sul server del bot: vedi BOT_UNLOCK.md.
    static let unlockPublicKey = "a40ab23d9a295c5809dc7cfd926dce85abeee3aa435cec04bd75871769abcaff"
    /// consente lo sblocco "onore" per chi segue su IG/MakerWorld (non verificabile).
    /// Metti false per accettare SOLO la verifica Telegram.
    static let allowHonorUnlock = true
    static let urlScheme = "printcost"

    /// Converte un link `https://t.me/<nome>[?start=x]` nel deep-link nativo `tg://resolve?...`.
    /// Serve a NON lasciare una scheda t.me aperta nel browser: quella pagina rilancia Telegram
    /// da sola a ogni ricarica/ripristino sessione (Chrome ricorda il permesso per lo schema tg:),
    /// per cui aprendo un qualsiasi altro link — es. le offerte Amazon — Telegram tornava in primo piano.
    static func telegramDeepLink(_ https: String) -> String? {
        guard let c = URLComponents(string: https), let host = c.host,
              host == "t.me" || host == "telegram.me" else { return nil }
        let name = c.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !name.isEmpty, !name.contains("/") else { return nil }   // solo @username / bot
        var out = URLComponents(string: "tg://resolve")!
        var q = [URLQueryItem(name: "domain", value: name)]
        if let start = c.queryItems?.first(where: { $0.name == "start" })?.value {
            q.append(URLQueryItem(name: "start", value: start))
        }
        out.queryItems = q
        return out.url?.absoluteString
    }
}

/// stato di formattazione valuta corrente (aggiornato dal modello, letto da eur())
enum Money {
    static var currency: Currency = .eur
    static var rate: Double = 1.0
    static func fmt(_ eurValue: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = currency.code; f.locale = Locale(identifier: currency.localeId)
        return f.string(from: NSNumber(value: eurValue * rate)) ?? "\(currency.symbol)\(eurValue * rate)"
    }
}

// MARK: - Modelli persistenti (materiali & stampanti) + parametri costo

struct Material: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: String        // "PLA Basic", "PLA Matte", "PETG", ...
    var colorHex: String    // "#RRGGBB"
    var costPerKg: Double    // € per kg — prezzo di listino
    var densityGcm3: Double  // densità (per volume→peso e viceversa)
    var stockKg: Double?     // scorta disponibile (opzionale)
    var salePrice: Double?   // € per kg in offerta (se presente, usato al posto del listino)
    /// prezzo effettivo: l'offerta se c'è ed è più bassa, altrimenti il listino
    var effectiveCostPerKg: Double {
        if let s = salePrice, s > 0, s < costPerKg { return s }
        return costPerKg
    }
    var onSale: Bool { if let s = salePrice, s > 0, s < costPerKg { return true }; return false }
}

/// Come si slica per una stampante: quale motore della famiglia Orca e quale profilo macchina.
struct SlicingSpec: Codable, Hashable {
    var engine: String    // "bambu" | "elegoo" | "snapmaker" | "orca"
    var vendor: String    // cartella vendor nell'albero profili dello slicer (BBL, Elegoo, Snapmaker…)
    var machine: String   // nome base del profilo macchina, senza suffisso ugello
}

struct PrinterProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var watts: Double            // potenza media in stampa
    var wearPerHour: Double      // ammortamento/usura € per ora di stampa
    var setupCost: Double        // costo fisso per avvio stampa (preparazione)
    var slicing: SlicingSpec? = nil   // nil = nessuno slicing dedicato (voce generica)
}

// Costo di stampa scomposto (vista "maker")
struct CostBreakdown {
    var material: Double = 0     // materiale consumato (g × €/kg)
    var energy: Double = 0       // kWh × €/kWh
    var wear: Double = 0         // ore × €/ora
    var setup: Double = 0        // avvii × costo setup
    var failure: Double = 0      // quota fallimenti
    var spools: Double = 0       // bobine da comprare (spesa upfront)
    var base: Double { material + energy + wear + setup }
    var total: Double { base + failure }   // costo reale della stampa
}

// MARK: - Persistenza

struct StoreData: Codable {
    var materials: [Material]
    var printers: [PrinterProfile]
    var failurePct: Double
    var kwh: Double
    var currency: String?     // opzionali per retrocompatibilità con vecchi store.json
    var eurRate: Double?
    var amazonTag: String?    // tag affiliato Amazon.it dell'utente
    var nozzle: Double?       // ugello scelto per lo slicing integrato (default 0.4)
    var layerHeight: Double?  // altezza layer scelta (default 0.20)
}

enum Store {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("3D Print Cost", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("store.json")
    }

    static func load() -> StoreData {
        if let d = try? Data(contentsOf: url), var s = try? JSONDecoder().decode(StoreData.self, from: d) {
            // migrazione non distruttiva: aggiunge stampanti predefinite nuove mancanti (per nome)
            let have = Set(s.printers.map { $0.name })
            for p in defaultPrinters() where !have.contains(p.name) { s.printers.append(p) }
            // migrazione v1.2: completa il blocco slicing sulle stampanti esistenti (per nome)
            let specs = Dictionary(uniqueKeysWithValues: defaultPrinters().compactMap { p in p.slicing.map { (p.name, $0) } })
            for i in s.printers.indices where s.printers[i].slicing == nil {
                s.printers[i].slicing = specs[s.printers[i].name]
            }
            // tiene la voce generica ("Altra") sempre in fondo
            let generic: Set<String> = ["Altra", "Other", "Otra", "Autre", "—"]
            s.printers = s.printers.filter { !generic.contains($0.name) } + s.printers.filter { generic.contains($0.name) }
            return s
        }
        return StoreData(materials: defaultMaterials(), printers: defaultPrinters(), failurePct: 7, kwh: 0.209, currency: "eur", eurRate: 1.0, amazonTag: defaultAmazonTag, nozzle: 0.4, layerHeight: 0.20)
    }

    /// tag affiliato incorporato e bloccato (app dell'autore)
    static let defaultAmazonTag = "emanueleesp-21"

    /// costruisce un link di ricerca affiliato su amazon.it (tag opzionale)
    static func amazonSearch(_ query: String, tag: String) -> String {
        var c = URLComponents(string: "https://www.amazon.it/s")!
        c.queryItems = [URLQueryItem(name: "k", value: query)]
        if !tag.trimmingCharacters(in: .whitespaces).isEmpty {
            c.queryItems!.append(URLQueryItem(name: "tag", value: tag.trimmingCharacters(in: .whitespaces)))
        }
        return c.url?.absoluteString ?? "https://www.amazon.it"
    }

    static func save(_ s: StoreData) {
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: url) }
    }

    // Materiali di default: palette Bambu con densità PLA e prezzi refill indicativi.
    static func defaultMaterials() -> [Material] {
        func m(_ n: String, _ t: String, _ hex: String, _ cost: Double, _ dens: Double = 1.24) -> Material {
            Material(name: n, type: t, colorHex: hex, costPerKg: cost, densityGcm3: dens)
        }
        return [
            m("Latte Brown", "PLA Matte", "#D3B7A7", 22.99),
            m("Nardo Gray", "PLA Matte", "#757575", 22.99),
            m("Ivory White", "PLA Matte", "#FFFFFF", 22.99),
            m("Scarlet Red", "PLA Matte", "#DE4343", 22.99),
            m("Charcoal", "PLA Matte", "#000000", 22.99),
            m("Jade White", "PLA Basic", "#FFFFFF", 22.99),
            m("Black", "PLA Basic", "#000000", 22.99),
            m("Red", "PLA Basic", "#C12E1F", 22.99),
            m("Cobalt Blue", "PLA Basic", "#0056B8", 22.99),
            m("Gold", "PLA Basic", "#E4BD68", 22.99),
            m("Cocoa Brown", "PLA Basic", "#6F5034", 22.99),
            m("Sunflower Yellow", "PLA Basic", "#FEC600", 22.99),
            m("Purple", "PLA Basic", "#5E43B7", 22.99),
            m("Mistletoe Green", "PLA Basic", "#3F8E43", 22.99),
            m("Pink", "PLA Basic", "#F55A74", 22.99),
        ]
    }

    // Preset materiali per marca: aggiungendo un materiale si sceglie da qui (dati già compilati).
    struct MaterialPreset: Identifiable {
        let id = UUID()
        let brand: String; let type: String; let colorName: String
        let hex: String; let costPerKg: Double; let density: Double
        func make() -> Material { Material(name: colorName, type: type, colorHex: hex, costPerKg: costPerKg, densityGcm3: density) }
    }
    static let presetBrandOrder = ["Bambu Lab", "eSun", "Generico"]
    static func presets() -> [MaterialPreset] {
        var out: [MaterialPreset] = []
        // Bambu Lab: tutti i colori PLA Basic e Matte dalla palette ufficiale
        for (hex, name) in defaultMaterials().map({ ($0.colorHex, $0.name) }) { _ = hex; _ = name } // no-op
        let basic = ["#FFFFFF":"Jade White","#000000":"Black","#C12E1F":"Red","#0A2989":"Blue","#8E9089":"Gray","#00AE42":"Bambu Green","#3F8E43":"Mistletoe Green","#0086D6":"Cyan","#FEC600":"Sunflower Yellow","#482960":"Indigo Purple","#6F5034":"Cocoa Brown","#F5547C":"Hot Pink","#FF9016":"Pumpkin Orange","#E4BD68":"Gold","#5E43B7":"Purple","#0056B8":"Cobalt Blue","#F55A74":"Pink","#D3B7A7":"Beige"]
        let matte = ["#FFFFFF":"Ivory White","#CBC6B8":"Bone White","#E8DBB7":"Desert Tan","#D3B7A7":"Latte Brown","#AE835B":"Caramel","#B15533":"Terracotta","#7D6556":"Dark Brown","#4D3324":"Dark Chocolate","#AE96D4":"Lilac Purple","#E8AFCF":"Sakura Pink","#F99963":"Mandarin Orange","#F7D959":"Lemon Yellow","#950051":"Plum","#DE4343":"Scarlet Red","#BB3D43":"Dark Red","#68724D":"Dark Green","#61C680":"Grass Green","#C2E189":"Apple Green","#A3D8E1":"Ice Blue","#56B7E6":"Sky Blue","#0078BF":"Marine Blue","#042F56":"Dark Blue","#9B9EA0":"Ash Gray","#757575":"Nardo Gray","#000000":"Charcoal"]
        for (h, n) in basic.sorted(by: { $0.value < $1.value }) { out.append(.init(brand:"Bambu Lab", type:"PLA Basic", colorName:n, hex:h, costPerKg:22.99, density:1.24)) }
        for (h, n) in matte.sorted(by: { $0.value < $1.value }) { out.append(.init(brand:"Bambu Lab", type:"PLA Matte", colorName:n, hex:h, costPerKg:22.99, density:1.24)) }
        out += [
            .init(brand:"Bambu Lab", type:"PETG HF", colorName:"Nero", hex:"#000000", costPerKg:22.99, density:1.27),
            .init(brand:"Bambu Lab", type:"ABS", colorName:"Nero", hex:"#000000", costPerKg:22.99, density:1.04),
            .init(brand:"Bambu Lab", type:"ASA", colorName:"Nero", hex:"#000000", costPerKg:24.99, density:1.07),
            .init(brand:"Bambu Lab", type:"PLA Silk", colorName:"Oro", hex:"#E4BD68", costPerKg:29.99, density:1.24),
            .init(brand:"Bambu Lab", type:"TPU 95A", colorName:"Nero", hex:"#000000", costPerKg:34.99, density:1.21),
        ]
        // eSun
        let esunCols = [("Nero","#1A1A1A"),("Bianco","#F5F5F5"),("Grigio","#808080"),("Rosso","#C0392B"),("Blu","#2049B0"),("Giallo","#F2C200")]
        for (n,h) in esunCols { out.append(.init(brand:"eSun", type:"PLA+", colorName:n, hex:h, costPerKg:19.99, density:1.24)) }
        out += [
            .init(brand:"eSun", type:"PETG", colorName:"Nero", hex:"#1A1A1A", costPerKg:21.99, density:1.27),
            .init(brand:"eSun", type:"ABS+", colorName:"Nero", hex:"#1A1A1A", costPerKg:20.99, density:1.06),
        ]
        // Generico per tipo di materiale (densità corrette, prezzo indicativo)
        for (t, d) in [("PLA",1.24),("PLA Matte",1.24),("PETG",1.27),("ABS",1.04),("ASA",1.07),("TPU 95A",1.21),("Nylon PA",1.14)] {
            out.append(.init(brand:"Generico", type:t, colorName:"—", hex:"#8E9089", costPerKg:20.0, density:d))
        }
        return out
    }
    static func presetTypes(_ brand: String) -> [String] {
        var seen = Set<String>(); var order: [String] = []
        for p in presets() where p.brand == brand && !seen.contains(p.type) { seen.insert(p.type); order.append(p.type) }
        return order
    }
    static func presetItems(_ brand: String, _ type: String) -> [MaterialPreset] {
        presets().filter { $0.brand == brand && $0.type == type }
    }

    // Stampanti di default: Bambu con potenza media, usura oraria e setup indicativi.
    static func defaultPrinters() -> [PrinterProfile] {
        func p(_ n: String, _ w: Double, _ wear: Double, _ setup: Double = 0.15, _ spec: SlicingSpec? = nil) -> PrinterProfile {
            PrinterProfile(name: n, watts: w, wearPerHour: wear, setupCost: setup, slicing: spec)
        }
        func bbl(_ machine: String) -> SlicingSpec { SlicingSpec(engine: "bambu", vendor: "BBL", machine: machine) }
        // usura oraria stimata = prezzo macchina / vita utile in ore
        return [
            p("Bambu Lab H2C", 180, 0.12, 0.15, bbl("Bambu Lab H2C")),
            p("Bambu Lab H2D", 180, 0.14, 0.15, bbl("Bambu Lab H2D")),
            p("Bambu Lab H2D Pro", 200, 0.16, 0.15, bbl("Bambu Lab H2D Pro")),
            p("Bambu Lab H2S", 160, 0.11, 0.15, bbl("Bambu Lab H2S")),
            p("Bambu Lab X1C", 110, 0.10, 0.15, bbl("Bambu Lab X1 Carbon")),
            p("Bambu Lab P1S", 105, 0.06, 0.15, bbl("Bambu Lab P1S")),
            p("Bambu Lab A1", 80, 0.04, 0.15, bbl("Bambu Lab A1")),
            p("Snapmaker U1", 150, 0.10, 0.15,   // tool-changer multicolore; media PLA ~150 W (picco 1150 W)
              SlicingSpec(engine: "snapmaker", vendor: "Snapmaker", machine: "Snapmaker U1")),
            p("Elegoo Centauri Carbon", 110, 0.06, 0.15,
              SlicingSpec(engine: "elegoo", vendor: "Elegoo", machine: "Elegoo Centauri Carbon")),
            p("Elegoo Neptune 4 Pro", 95, 0.04, 0.15,
              SlicingSpec(engine: "elegoo", vendor: "Elegoo", machine: "Elegoo Neptune 4 Pro")),
            p("Altra", 120, 0.08),
        ]
    }
}
