import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Stato applicazione

@MainActor
final class AppModel: ObservableObject {
    @Published var files: [LoadedFile] = []
    @Published var watts: Double = 180
    @Published var kwh: Double = 0.209
    @Published var msrp: Double = 22.99
    @Published var section: Section = .overview
    @Published var busy: String? = nil

    enum Section: String, CaseIterable, Identifiable {
        case overview, files, colors, plates, setup
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: "Panoramica"; case .files: "File & Slicing"
            case .colors: "Colori & Bobine"; case .plates: "Ottimizza piatti"; case .setup: "Costi & Setup"
            }
        }
        var icon: String {
            switch self {
            case .overview: "square.grid.2x2"; case .files: "doc"; case .colors: "paintpalette"
            case .plates: "puzzlepiece"; case .setup: "gearshape"
            }
        }
    }

    let printers: [(String, Double)] = [
        ("Bambu Lab H2C", 180), ("Bambu Lab H2D", 180), ("Bambu Lab H2D Pro", 200),
        ("Bambu Lab H2S", 160), ("Bambu Lab X1C", 110), ("Bambu Lab P1S", 105),
        ("Bambu Lab A1", 80), ("Altra", 120)]

    // Derivati
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

    var tier: (price: Double, label: String) {
        let n = totalSpools
        if n >= 10 { return (msrp * 0.5, "sconto 50% (10+)") }
        if n >= 6 { return (msrp * 0.55, "sconto 45% (6+)") }
        if n >= 4 { return (msrp * 0.65, "sconto 35% (4+)") }
        return (msrp, "listino pieno")
    }
    var filamentCost: Double { Double(totalSpools) * tier.price }
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

    // Azioni
    func add(paths: [String]) {
        for p in paths where p.lowercased().hasSuffix(".3mf") {
            let name = (p as NSString).lastPathComponent
            if files.contains(where: { $0.path == p }) { continue }
            let st = Slicer.analyze(p)
            files.append(LoadedFile(name: name, path: p, state: st))
        }
    }
    func remove(_ f: LoadedFile) { files.removeAll { $0.id == f.id } }

    func slice(_ f: LoadedFile) {
        busy = "Slicing di \(f.name) con Bambu Studio…"
        let path = f.path
        Task.detached {
            let st = Slicer.slice(path)
            await MainActor.run { f.state = st; self.objectWillChange.send(); self.busy = nil }
        }
    }
}

// MARK: - Helpers formattazione

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
