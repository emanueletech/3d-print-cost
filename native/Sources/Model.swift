import Foundation
import AppKit

// MARK: - Strutture dati

struct PlateInfo: Identifiable {
    let id = UUID()
    let index: Int
    let seconds: Double
    let grams: Double
    let colorGrams: [String: Double]   // "#HEX|PLA Type" -> grammi su questo piatto
    var colorKeys: [String] { Array(colorGrams.keys) }
}

struct ColorRow: Identifiable {
    let id = UUID()
    let hex: String
    let type: String
    let grams: Double
    var spools: Int { max(1, Int(ceil(grams / 1000.0))) }
    var name: String { FilamentDB.name(hex: hex, type: type) }
}

struct FileAnalysis {
    var plates: [PlateInfo]
    var seconds: Double
    var grams: Double
    var perColor: [String: Double]   // key -> grams
    var failed: [Int] = []           // piatti che non si sono potuti slicare
}

enum LoadState { case sliced(FileAnalysis), notSliced, error(String) }

final class LoadedFile: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    @Published var state: LoadState
    @Published var thumbs: [NSImage] = []      // anteprime dei piatti (dal 3mf)
    @Published var excluded: Set<Int> = []     // indici piatti esclusi dal calcolo
    @Published var toSlice: Set<Int> = []      // piatti spenti scelti per lo slicing incrementale
    init(name: String, path: String, state: LoadState) {
        self.name = name; self.path = path; self.state = state
    }
    var includedPlates: [PlateInfo] { (analysis?.plates ?? []).filter { !excluded.contains($0.index) } }
    var analysis: FileAnalysis? {
        if case let .sliced(a) = state { return a }; return nil
    }
}

// MARK: - Nomi bobine Bambu (palette ufficiale)

enum FilamentDB {
    static let basic: [String: String] = [
        "#FFFFFF":"Jade White","#000000":"Black","#C12E1F":"Red","#0A2989":"Blue","#8E9089":"Gray",
        "#00AE42":"Bambu Green","#3F8E43":"Mistletoe Green","#0086D6":"Cyan","#FEC600":"Sunflower Yellow",
        "#482960":"Indigo Purple","#6F5034":"Cocoa Brown","#F5547C":"Hot Pink","#FF9016":"Pumpkin Orange",
        "#E4BD68":"Gold","#5E43B7":"Purple","#0056B8":"Cobalt Blue","#F55A74":"Pink","#D3B7A7":"Beige"]
    static let matte: [String: String] = [
        "#FFFFFF":"Ivory White","#CBC6B8":"Bone White","#E8DBB7":"Desert Tan","#D3B7A7":"Latte Brown",
        "#AE835B":"Caramel","#B15533":"Terracotta","#7D6556":"Dark Brown","#4D3324":"Dark Chocolate",
        "#AE96D4":"Lilac Purple","#E8AFCF":"Sakura Pink","#F99963":"Mandarin Orange","#F7D959":"Lemon Yellow",
        "#950051":"Plum","#DE4343":"Scarlet Red","#BB3D43":"Dark Red","#68724D":"Dark Green","#61C680":"Grass Green",
        "#C2E189":"Apple Green","#A3D8E1":"Ice Blue","#56B7E6":"Sky Blue","#0078BF":"Marine Blue","#042F56":"Dark Blue",
        "#9B9EA0":"Ash Gray","#757575":"Nardo Gray","#000000":"Charcoal"]
    static func name(hex: String, type: String) -> String {
        let m = type.contains("Matte") ? matte : basic
        return m[hex.uppercased()] ?? hex
    }
}

// MARK: - Parsing 3mf + slicing

enum Slicer {
    static let bambu = "/Applications/BambuStudio.app/Contents/MacOS/BambuStudio"

    static func resourcesDir() -> String {
        // resources accanto all'eseguibile (dentro il bundle) oppure in ../resources in dev
        let exe = Bundle.main.bundleURL
        let candidates = [
            exe.appendingPathComponent("Contents/Resources"),
            exe.deletingLastPathComponent().appendingPathComponent("resources"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("resources"),
        ]
        for c in candidates where FileManager.default.fileExists(atPath: c.appendingPathComponent("profiles").path) {
            return c.path
        }
        return candidates.first!.path
    }

    /// Log dell'ultimo slicing, per capire perché Bambu Studio fallisce.
    static let logPath = NSHomeDirectory() + "/Library/Logs/3DPrintCost-slicer.log"

    @discardableResult
    static func run(_ launch: String, _ args: [String], timeout: TimeInterval = 1800, errTo: FileHandle? = nil) -> (Int32, Data) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        // stderr mai su un Pipe non letto: si riempie (~64 KB) e blocca per sempre
        // Bambu Studio sui modelli complessi, dove --debug scrive moltissimo.
        // Su file invece il kernel scrive diretto: niente blocco, e l'errore resta leggibile.
        p.standardError = errTo ?? FileHandle.nullDevice
        do { try p.run() } catch { return (-1, Data()) }
        // guardia: oltre il timeout il processo viene terminato invece di attendere all'infinito
        let killer = DispatchWorkItem {
            if p.isRunning {
                errTo?.write("\n[timeout \(Int(timeout)) s: processo terminato]\n".data(using: .utf8)!)
                p.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        killer.cancel()
        return (p.terminationStatus, data)
    }

    static func unzipEntry(_ file: String, _ entry: String) -> String? {
        let (code, data) = run("/usr/bin/unzip", ["-p", file, entry])
        guard code == 0, !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }

    struct Project { var slotColors: [String]; var slotTypes: [String]; var slotKinds: [String]; var objSlot: [String: Int] }

    static func parseProject(_ file: String) -> Project {
        var colors: [String] = [], types: [String] = [], kinds: [String] = [], objSlot: [String: Int] = [:]
        if let ps = unzipEntry(file, "Metadata/project_settings.config"),
           let data = ps.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            colors = (obj["filament_colour"] as? [String] ?? []).map { $0.uppercased() }
            types = (obj["filament_settings_id"] as? [String] ?? []).map { $0.lowercased().contains("matte") ? "PLA Matte" : "PLA Basic" }
            // tipo materiale per slot (PLA/PETG/TPU…): guida la scelta dei profili (v1.2 M5)
            kinds = (obj["filament_type"] as? [String] ?? []).map { $0.uppercased() }
        }
        if let ms = unzipEntry(file, "Metadata/model_settings.config") {
            for m in matches("<object id=\"(\\d+)\">(.*?)</object>", ms) {
                let body = m[2]
                if let nm = matches("name\" value=\"([^\"]+)\"", body).first {
                    let ex = matches("extruder\" value=\"(\\d+)\"", body).first
                    objSlot[nm[1]] = Int(ex?[1] ?? "1") ?? 1
                }
            }
        }
        return Project(slotColors: colors, slotTypes: types, slotKinds: kinds, objSlot: objSlot)
    }

    static func analyze(_ file: String) -> LoadState {
        guard let xml = unzipEntry(file, "Metadata/slice_info.config") else { return .error("non3mf") }
        let proj = parseProject(file)
        var plates: [PlateInfo] = []
        var seconds = 0.0, grams = 0.0
        var perColor: [String: Double] = [:]
        for pm in matches("<plate>(.*?)</plate>", xml) {
            let b = pm[1]
            guard let pred = matches("key=\"prediction\" value=\"(\\d+)\"", b).first,
                  let secs = Double(pred[1]) else { continue }
            let objs = matches("object identify_id=\"\\d+\" name=\"([^\"]+)\"", b).map { $0[1] }
            let trueSlot = objs.first.flatMap { proj.objSlot[$0] } ?? 1
            var pg = 0.0; var plateColors: [String: Double] = [:]
            for f in matches("filament id=\"(\\d+)\"[^/]*?color=\"([^\"]+)\"[^/]*?used_g=\"([^\"]+)\"", b) {
                let slot = (Int(f[1]) == 1) ? trueSlot : (Int(f[1]) ?? 1)
                let hex = slot-1 < proj.slotColors.count ? proj.slotColors[slot-1] : f[2].uppercased()
                let type = slot-1 < proj.slotTypes.count ? proj.slotTypes[slot-1] : "PLA Basic"
                let g = Double(f[3]) ?? 0
                let key = hex + "|" + type
                perColor[key, default: 0] += g; pg += g; grams += g
                plateColors[key, default: 0] += g
            }
            seconds += secs
            // l'indice reale del piatto sta nel file: un export con il solo
            // piatto 5 deve restare "piatto 5", non diventare il piatto 1
            let idx = matches("key=\"index\" value=\"(\\d+)\"", b).first.flatMap { Int($0[1]) } ?? (plates.count + 1)
            plates.append(PlateInfo(index: idx, seconds: secs, grams: pg, colorGrams: plateColors))
        }
        if plates.isEmpty { return .notSliced }
        return .sliced(FileAnalysis(plates: plates, seconds: seconds, grams: grams, perColor: perColor))
    }

    /// Slicing con Bambu Studio CLI (profilo H2C), con fallback di riposizionamento
    /// sulla griglia e salvataggio piatto-per-piatto: un piatto guasto non fa più
    /// fallire l'intero file, viene solo segnalato in `FileAnalysis.failed`.
    /// `sel`: piatti richiesti (numerazione del progetto); vuoto = tutti.
    /// `nozzle`/`layer`: scelta ugello e altezza layer (i profili dedicati arrivano con la M2
    /// della v1.2; finché mancano si usano i profili H2C 0.4/0.20 in bundle).
    /// `progress`: chiamata prima di ogni piatto nei giri piatto-per-piatto (k, totale).
    static func slice(_ file: String, plates sel: [Int] = [], nozzle: Double = 0.4, layer: Double = 0.20,
                      spec: SlicingSpec? = nil, progress: ((Int, Int) -> Void)? = nil) -> LoadState {
        guard FileManager.default.fileExists(atPath: bambu) else { return .error("noBambu") }
        let res = resourcesDir()
        let prof = res + "/profiles"
        let tmp = NSTemporaryDirectory() + "slice-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let out = tmp + "/sliced.3mf"

        FileManager.default.createFile(atPath: logPath, contents: nil)
        let log = FileHandle(forWritingAtPath: logPath)
        defer { log?.closeFile() }
        func note(_ s: String) { log?.write((s + "\n").data(using: .utf8)!) }
        note(sel.isEmpty ? "=== \(file)" : "=== \(file) (piatti \(sel.map(String.init).joined(separator: ", ")))")

        let proj = parseProject(file)
        // profili della stampante selezionata (v1.2 M2): letti da Bambu Studio
        // e appiattiti; se qualcosa manca si resta sull'H2C in bundle
        var settings = "\(prof)/machine_H2C_04.json;\(prof)/process_020_H2C.json"
        var filBasic = prof + "/fil_PLA_Basic_H2C.json"
        var filMatte = prof + "/fil_PLA_Matte_H2C.json"
        var machineForRemap: String? = nil
        var resolved: ResolvedProfiles? = nil
        if let spec, spec.engine == "bambu",
           let r = resolveBambu(spec, nozzle: nozzle, layer: layer, tmp: tmp, note: note) {
            settings = "\(r.machine);\(r.process)"
            filBasic = r.filBasic; filMatte = r.filMatte
            machineForRemap = r.machine
            resolved = r
        }
        // un profilo filamento per slot: PLA Basic/Matte come sempre; PETG e TPU
        // dai profili Bambu quando risolti (v1.2 M5), altrimenti ripiego sul PLA
        var kindCache: [String: String?] = [:]
        func filForSlot(_ i: Int, _ t: String) -> String {
            let kind = i < proj.slotKinds.count ? proj.slotKinds[i] : "PLA"
            if let r = resolved, kind != "PLA" {
                if kindCache[kind] == nil { kindCache[kind] = bambuFilamentFor(kind, r, tmp: tmp) }
                if let p = kindCache[kind] ?? nil { return p }
            }
            return t.contains("Matte") ? filMatte : filBasic
        }
        let types = proj.slotTypes.isEmpty ? ["PLA Basic"] : proj.slotTypes
        let fil = types.enumerated().map { filForSlot($0.offset, $0.element) }.joined(separator: ";")

        func runSlice(_ src: String, plate: Int = 0, arrange: Bool = false) -> Bool {
            try? FileManager.default.removeItem(atPath: out)   // mai fidarsi dell'export del tentativo precedente
            let args = [
                "--load-settings", settings,
                "--load-filaments", fil]
                + (arrange ? ["--arrange", "1"] : [])
                + ["--slice", "\(plate)", "--debug", "1",
                   "--export-3mf", "sliced.3mf", "--outputdir", tmp, src]
            note("$ BambuStudio " + args.joined(separator: " "))
            let (code, outData) = run(bambu, args, errTo: log)
            if let s = String(data: outData, encoding: .utf8), !s.isEmpty { note("[stdout] " + String(s.suffix(20000))) }
            note("[exit] \(code)")
            return code == 0 && FileManager.default.fileExists(atPath: out)
        }

        // rimappato una sola volta, alla prima necessità ("" = tentato e fallito)
        var remapPath: String? = nil
        func remapped() -> String? {
            if let r = remapPath { return r.isEmpty ? nil : r }
            let dst = tmp + "/remapped.3mf"
            note("$ python3 remap.py (riposizionamento sulla griglia della stampante)")
            var args = [res + "/remap.py", file, dst]
            if let mfr = machineForRemap { args.append(mfr) }   // letto di destinazione reale
            let (c, _) = run("/usr/bin/python3", args, errTo: log)
            note("[exit] \(c)")
            remapPath = (c == 0 && FileManager.default.fileExists(atPath: dst)) ? dst : ""
            return remapPath!.isEmpty ? nil : remapPath
        }

        // estrae l'unico piatto dall'export e gli restituisce il numero del progetto
        func single(_ n: Int) -> PlateInfo? {
            guard case .sliced(let a) = analyze(out), let p = a.plates.first else { return nil }
            return PlateInfo(index: n, seconds: p.seconds, grams: p.grams, colorGrams: p.colorGrams)
        }
        func pack(_ plates: [PlateInfo], failed: [Int]) -> LoadState {
            var perColor: [String: Double] = [:]
            for p in plates { for (k, g) in p.colorGrams { perColor[k, default: 0] += g } }
            return .sliced(FileAnalysis(plates: plates.sorted { $0.index < $1.index },
                                        seconds: plates.reduce(0) { $0 + $1.seconds },
                                        grams: plates.reduce(0) { $0 + $1.grams },
                                        perColor: perColor, failed: failed))
        }
        // un piatto alla volta: prova l'originale, poi il rimappato
        func salvage(_ targets: [Int]) -> LoadState {
            var good: [PlateInfo] = []; var failed: [Int] = []
            for (k, n) in targets.enumerated() {
                if targets.count > 1 { progress?(k + 1, targets.count) }
                var done = runSlice(file, plate: n)
                if !done, let r = remapped() { done = runSlice(r, plate: n) }
                if done, let p = single(n) { good.append(p) } else { failed.append(n) }
            }
            note("[piatto per piatto] riusciti: \(good.map { String($0.index) }.joined(separator: ", ")) — falliti: \(failed.map(String.init).joined(separator: ", "))")
            guard !good.isEmpty else { return .error("sliceFail") }
            return pack(good, failed: failed)
        }

        let totalPlates = max(plateCount(file), 1)
        let targets = sel.isEmpty ? Array(1...totalPlates) : sel.filter { $0 >= 1 }.sorted()

        // sottoinsieme (o piatto singolo): direttamente piatto per piatto
        if targets.count < totalPlates || targets.count == 1 { return salvage(targets) }

        // tutto il file: originale → rimappato → riadattato (--arrange, come la GUI
        // al cambio stampante); se l'insieme fallisce, si salva piatto per piatto
        var ok = runSlice(file)
        if !ok, let r = remapped() { ok = runSlice(r) }
        if !ok { ok = runSlice(file, arrange: true) }
        if ok { return analyze(out) }
        return salvage(targets)
    }

    /// Numero di piatti dichiarati dal progetto (Metadata/model_settings.config).
    static func plateCount(_ file: String) -> Int {
        guard let ms = unzipEntry(file, "Metadata/model_settings.config") else { return 0 }
        return ms.components(separatedBy: "<plate>").count - 1
    }

    // MARK: - Profili per stampante (v1.2 M2): letti da Bambu Studio installato

    /// Radice dell'albero profili BBL dentro Bambu Studio, se installato.
    static func bambuVendorDir() -> String? {
        let root = (bambu as NSString).deletingLastPathComponent + "/../Resources/profiles/BBL"
        let norm = (root as NSString).standardizingPath
        return FileManager.default.fileExists(atPath: norm + "/machine") ? norm : nil
    }

    /// Appiattisce un preset seguendo la catena `inherits` nella stessa cartella;
    /// scrive il risultato in `tmp` e ne restituisce il percorso.
    static func flattenPreset(dir: String, name: String, into tmp: String, depth: Int = 0) -> String? {
        guard depth < 12,
              let data = FileManager.default.contents(atPath: "\(dir)/\(name).json"),
              var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let parent = obj["inherits"] as? String, !parent.isEmpty {
            guard let pPath = flattenPreset(dir: dir, name: parent, into: tmp, depth: depth + 1),
                  let pData = FileManager.default.contents(atPath: pPath),
                  var merged = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else { return nil }
            for (k, v) in obj { merged[k] = v }   // il figlio vince sul padre
            obj = merged
        }
        obj.removeValue(forKey: "inherits")
        let out = tmp + "/flat-" + name.replacingOccurrences(of: "/", with: "_") + ".json"
        guard let od = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        do { try od.write(to: URL(fileURLWithPath: out)) } catch { return nil }
        return out
    }

    struct ResolvedProfiles {
        var machine: String; var process: String; var filBasic: String; var filMatte: String
        var root: String; var code: String; var sfx: String
    }

    /// Profilo filamento per tipo materiale (PETG/TPU…), appiattito; nil se non esiste.
    static func bambuFilamentFor(_ kind: String, _ r: ResolvedProfiles, tmp: String) -> String? {
        let cands: [String]
        switch kind {
        case "PETG":
            cands = ["Bambu PETG HF @BBL \(r.code)\(r.sfx)", "Bambu PETG HF @BBL \(r.code)",
                     "Bambu PETG Basic @BBL \(r.code)\(r.sfx)", "Bambu PETG Basic @BBL \(r.code)",
                     "Bambu PETG HF @base", "Generic PETG @base", "Generic PETG"]
        case "TPU":
            cands = ["Bambu TPU 95A HF @BBL \(r.code)\(r.sfx)", "Bambu TPU 95A HF @BBL \(r.code)",
                     "Bambu TPU 95A @BBL \(r.code)\(r.sfx)", "Bambu TPU 95A @BBL \(r.code)",
                     "Bambu TPU 95A HF @base", "Generic TPU @base", "Generic TPU"]
        default: return nil
        }
        let dir = r.root + "/filament"
        guard let name = cands.first(where: { FileManager.default.fileExists(atPath: "\(dir)/\($0).json") }) else { return nil }
        return flattenPreset(dir: dir, name: name, into: tmp)
    }

    /// Trova e appiattisce macchina/processo/filamenti per la stampante scelta.
    /// nil = si resta sui profili H2C in bundle (Bambu Studio assente o profili non trovati).
    static func resolveBambu(_ spec: SlicingSpec, nozzle: Double, layer: Double,
                             tmp: String, note: (String) -> Void) -> ResolvedProfiles? {
        guard let root = bambuVendorDir() else {
            note("[profili] albero profili di Bambu Studio non trovato: uso H2C in bundle")
            return nil
        }
        let nz = String(format: "%.1f", nozzle)
        let ly = String(format: "%.2f", layer)
        let code = spec.code ?? "H2C"
        let sfx = nozzle == 0.4 ? "" : " \(nz) nozzle"   // i profili 0.4 non hanno suffisso
        func firstExisting(_ sub: String, _ names: [String]) -> String? {
            names.first { FileManager.default.fileExists(atPath: "\(root)/\(sub)/\($0).json") }
        }
        // il processo va cercato tra quelli del SUO ugello: un processo 0.4 con una
        // macchina 0.8 fa bocciare il CLI ("process not compatible with printer").
        // Alla pari di layer si preferisce la famiglia Standard; se il layer chiesto
        // non esiste (es. 0.48 Standard), si prende il più vicino dello stesso ugello.
        func bestProcess() -> String? {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: "\(root)/process") else { return nil }
            let end = "@BBL \(code)\(sfx).json"
            let cands = names.filter { $0.hasSuffix(end) }
            guard !cands.isEmpty else { return nil }
            func layerOf(_ n: String) -> Double? {
                guard let r = n.range(of: "mm ") else { return nil }
                return Double(n[n.startIndex..<r.lowerBound])
            }
            let exact = cands.filter { $0.hasPrefix("\(ly)mm ") }
            if let s = exact.first(where: { $0.contains("Standard") }) ?? exact.first {
                return String(s.dropLast(5))
            }
            let scored = cands.compactMap { n in layerOf(n).map { (n, abs($0 - layer)) } }
                .sorted {
                    if $0.1 != $1.1 { return $0.1 < $1.1 }
                    return $0.0.contains("Standard") && !$1.0.contains("Standard")
                }
            return scored.first.map { String($0.0.dropLast(5)) }
        }
        guard let mach = firstExisting("machine", ["\(spec.machine) \(nz) nozzle"]),
              let proc = bestProcess(),
              let filB = firstExisting("filament", ["Bambu PLA Basic @BBL \(code)\(sfx)",
                                                    "Bambu PLA Basic @BBL \(code)",
                                                    "Bambu PLA Basic @base"]),
              let filM = firstExisting("filament", ["Bambu PLA Matte @BBL \(code)\(sfx)",
                                                    "Bambu PLA Matte @BBL \(code)",
                                                    "Bambu PLA Matte @base"]) else {
            note("[profili] profili per \(spec.machine) (ugello \(nz), layer \(ly)) non trovati: uso H2C in bundle")
            return nil
        }
        guard let mp = flattenPreset(dir: root + "/machine", name: mach, into: tmp),
              let pp = flattenPreset(dir: root + "/process", name: proc, into: tmp),
              let fb = flattenPreset(dir: root + "/filament", name: filB, into: tmp),
              let fm = flattenPreset(dir: root + "/filament", name: filM, into: tmp) else {
            note("[profili] appiattimento fallito: uso H2C in bundle")
            return nil
        }
        // stessa cura del profilo in bundle: la ooze prevention del progetto
        // non deve far bocciare la validazione con la prime tower attiva
        if let d = FileManager.default.contents(atPath: pp),
           var obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            obj["ooze_prevention"] = "0"
            if let od = try? JSONSerialization.data(withJSONObject: obj) { try? od.write(to: URL(fileURLWithPath: pp)) }
        }
        note("[profili] \(mach) · \(proc) · \(filB)")
        return ResolvedProfiles(machine: mp, process: pp, filBasic: fb, filMatte: fm,
                                root: root, code: code, sfx: sfx)
    }

    /// Slicing di un file mesh singolo (STL/OBJ/STEP) col profilo H2C, mono-materiale PLA Basic.
    static func sliceRaw(_ file: String) -> LoadState {
        guard FileManager.default.fileExists(atPath: bambu) else { return .error("noBambu") }
        let res = resourcesDir(); let prof = res + "/profiles"
        let tmp = NSTemporaryDirectory() + "sliceraw-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let log = FileHandle(forWritingAtPath: logPath)
        defer { log?.closeFile() }
        log?.write("=== \(file)\n".data(using: .utf8)!)
        let (code, _) = run(bambu, [
            "--load-settings", "\(prof)/machine_H2C_04.json;\(prof)/process_020_H2C.json",
            "--load-filaments", "\(prof)/fil_PLA_Basic_H2C.json",
            "--arrange", "1", "--slice", "0", "--debug", "1",
            "--export-3mf", "sliced.3mf", "--outputdir", tmp, file], errTo: log)
        log?.write("[exit] \(code)\n".data(using: .utf8)!)
        guard code == 0, FileManager.default.fileExists(atPath: tmp + "/sliced.3mf") else { return .error("sliceFail") }
        return analyze(tmp + "/sliced.3mf")
    }

    /// Anteprime dei piatti dentro un 3mf (Metadata/plate_N.png), ordinate per piatto.
    static func thumbnails(_ file: String) -> [NSImage] {
        let (code, out) = run("/usr/bin/unzip", ["-Z1", file])
        guard code == 0, let list = String(data: out, encoding: .utf8) else { return [] }
        let names = list.split(separator: "\n").map(String.init)
            .filter { $0.range(of: #"^Metadata/plate_\d+\.png$"#, options: .regularExpression) != nil }
            .sorted { a, b in
                func n(_ s: String) -> Int { Int(s.replacingOccurrences(of: "Metadata/plate_", with: "").replacingOccurrences(of: ".png", with: "")) ?? 0 }
                return n(a) < n(b)
            }
        var imgs: [NSImage] = []
        for entry in names {
            let (c, data) = run("/usr/bin/unzip", ["-p", file, entry])
            if c == 0, !data.isEmpty, let img = NSImage(data: data) { imgs.append(img) }
        }
        return imgs
    }

    /// Converte STEP→STL con Bambu Studio (che importa lo STEP), restituisce il path STL.
    static func stepToSTL(_ file: String) -> String? {
        guard FileManager.default.fileExists(atPath: bambu) else { return nil }
        let outdir = NSTemporaryDirectory() + "step-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: outdir, withIntermediateDirectories: true)
        let (code, _) = run(bambu, ["--export-stls", outdir, file])
        guard code == 0 else { return nil }
        let stls = (try? FileManager.default.contentsOfDirectory(atPath: outdir))?.filter { $0.hasSuffix(".stl") } ?? []
        return stls.first.map { outdir + "/" + $0 }
    }
}
