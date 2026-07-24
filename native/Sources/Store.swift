import Foundation

// MARK: - Modelli persistenti (materiali & stampanti) + parametri costo

struct Material: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: String        // "PLA Basic", "PLA Matte", "PETG", ...
    var colorHex: String    // "#RRGGBB"
    var costPerKg: Double    // € per kg (materiale consumato)
    var densityGcm3: Double  // densità (per volume→peso e viceversa)
    var stockKg: Double?     // scorta disponibile (opzionale)
}

struct PrinterProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var watts: Double            // potenza media in stampa
    var wearPerHour: Double      // ammortamento/usura € per ora di stampa
    var setupCost: Double        // costo fisso per avvio stampa (preparazione)
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
            return s
        }
        return StoreData(materials: defaultMaterials(), printers: defaultPrinters(), failurePct: 7, kwh: 0.209)
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

    // Stampanti di default: Bambu con potenza media, usura oraria e setup indicativi.
    static func defaultPrinters() -> [PrinterProfile] {
        func p(_ n: String, _ w: Double, _ wear: Double, _ setup: Double = 0.15) -> PrinterProfile {
            PrinterProfile(name: n, watts: w, wearPerHour: wear, setupCost: setup)
        }
        // usura oraria stimata = prezzo macchina / vita utile in ore
        return [
            p("Bambu Lab H2C", 180, 0.12), p("Bambu Lab H2D", 180, 0.14),
            p("Bambu Lab H2D Pro", 200, 0.16), p("Bambu Lab H2S", 160, 0.11),
            p("Bambu Lab X1C", 110, 0.10), p("Bambu Lab P1S", 105, 0.06),
            p("Bambu Lab A1", 80, 0.04),
            p("Snapmaker U1", 150, 0.10),   // tool-changer multicolore; media PLA ~150 W (picco 1150 W)
            p("Altra", 120, 0.08),
        ]
    }
}
