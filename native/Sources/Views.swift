import SwiftUI
import UniformTypeIdentifiers

// MARK: - Entry point

@main
struct CostoStampaApp: App {
    @StateObject private var m = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(m)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// Sfondo "aurora" — è il contenuto sotto il vetro, come nei demo Apple.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            RadialGradient(colors: [Color(hex:"FFB082").opacity(0.35), .clear], center: .init(x:0.05,y:-0.1), startRadius: 0, endRadius: 700)
            RadialGradient(colors: [Color(hex:"78BEFF").opacity(0.35), .clear], center: .init(x:1.05,y:0.05), startRadius: 0, endRadius: 760)
            RadialGradient(colors: [Color(hex:"FFAAD2").opacity(0.3), .clear], center: .init(x:0.5,y:1.15), startRadius: 0, endRadius: 760)
        }.ignoresSafeArea()
    }
}

struct RootView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBackground()
            HStack(spacing: 0) {
                Sidebar()
                Detail().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let b = m.busy { BusyBar(text: b) }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url { Task { @MainActor in m.add(paths: [url.path]) } }
                }
            }
            return true
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Costo ")
                .font(.system(size: 21, design: .serif))
              + Text("Stampa").font(.system(size: 21, design: .serif)).foregroundColor(.accentColor)
              + Text(" 3D").font(.system(size: 21, design: .serif))
            Spacer().frame(height: 14)
            ForEach(AppModel.Section.allCases) { s in
                Button { m.section = s } label: {
                    HStack(spacing: 10) {
                        Image(systemName: s.icon).frame(width: 20)
                        Text(s.title).font(.system(size: 13.5, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .background {
                    if m.section == s {
                        RoundedRectangle(cornerRadius: 11).fill(.regularMaterial.opacity(0.9))
                            .glassEffect(.regular, in: .rect(cornerRadius: 11))
                    }
                }
            }
            Spacer()
            Text("Bambu Lab H2C\n\(Int(m.watts)) W · \(m.kwh, specifier: "%.3f") €/kWh")
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
        .padding(.top, 44).padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 216)
    }
}

// MARK: - Detail router

struct Detail: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(m.section.title).font(.system(size: 32, design: .serif))
                switch m.section {
                case .overview: OverviewView()
                case .files: FilesView()
                case .colors: ColorsView()
                case .plates: PlatesView()
                case .setup: SetupView()
                }
            }
            .padding(.horizontal, 30).padding(.top, 44).padding(.bottom, 40)
            .frame(maxWidth: 990, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Riquadro di vetro riutilizzabile
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

struct Stat: View {
    let k: String; let v: String; var d: String = ""
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(k.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).tracking(1)
                Text(v).font(.system(size: 30, design: .serif))
                Text(d).font(.system(size: 12, weight: .semibold)).foregroundStyle(.green).frame(height: 16)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var m: AppModel
    let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(m.loaded.isEmpty ? "Trascina i tuoi file .3mf per iniziare"
                 : "\(m.loaded.count) file · \(m.totalPlates) piatti · Bambu Lab H2C")
                .foregroundStyle(.secondary).font(.system(size: 13)).padding(.bottom, 14)

            GlassEffectContainer(spacing: 13) {
                LazyVGrid(columns: cols, spacing: 13) {
                    Stat(k: "Tempo di stampa", v: m.loaded.isEmpty ? "—" : "\(Int(m.totalSeconds/3600)) h",
                         d: m.loaded.isEmpty ? "" : "≈ \(Int(ceil(m.totalSeconds/86400))) giorni")
                    Stat(k: "Materiale", v: m.loaded.isEmpty ? "—" : String(format:"%.1f kg", m.totalGrams/1000),
                         d: m.colorRows.isEmpty ? "" : "\(m.colorRows.count) colori")
                    Stat(k: "Bobine", v: m.loaded.isEmpty ? "—" : "\(m.totalSpools)", d: "refill 1 kg")
                    Stat(k: "Filamento", v: m.loaded.isEmpty ? "—" : eur(m.filamentCost), d: m.loaded.isEmpty ? "" : m.tier.label)
                    Stat(k: "Corrente", v: m.loaded.isEmpty ? "—" : eur(m.energyCost), d: m.loaded.isEmpty ? "" : String(format:"%.1f kWh", m.kWh))
                    Stat(k: "Piatti", v: m.loaded.isEmpty ? "—" : "\(m.totalPlates)", d: "")
                }
            }
            if !m.loaded.isEmpty {
                HStack(alignment: .top, spacing: 13) {
                    GlassCard {
                        VStack {
                            Text("MATERIALE PER COLORE").font(.system(size:10.5,weight:.semibold)).foregroundStyle(.secondary).tracking(1).frame(maxWidth:.infinity,alignment:.leading)
                            DonutView(rows: m.colorRows, total: m.totalGrams).frame(height: 170)
                        }
                    }
                    GlassCard {
                        VStack {
                            Text("ORE PER FILE").font(.system(size:10.5,weight:.semibold)).foregroundStyle(.secondary).tracking(1).frame(maxWidth:.infinity,alignment:.leading)
                            SparkView(files: m.loaded).frame(height: 150)
                        }
                    }
                }.padding(.top, 13)
            }
        }
    }
}

struct DonutView: View {
    let rows: [ColorRow]; let total: Double
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width/2, y: size.height/2)
                    let r = min(size.width, size.height)/2 - 4
                    var start = -90.0
                    for row in rows {
                        let sweep = row.grams / max(total,1) * 360
                        var path = Path()
                        path.move(to: c)
                        path.addArc(center: c, radius: r, startAngle: .degrees(start), endAngle: .degrees(start+sweep), clockwise: false)
                        ctx.fill(path, with: .color(Color(hex: row.hex)))
                        start += sweep
                    }
                    // buco
                    let hole = CGRect(x: c.x - r*0.62, y: c.y - r*0.62, width: r*1.24, height: r*1.24)
                    ctx.blendMode = .destinationOut
                    ctx.fill(Path(ellipseIn: hole), with: .color(.black))
                }
                Text(String(format: "%.1f kg", total/1000)).font(.system(size: 20, design: .serif))
            }.frame(width: side, height: side).frame(maxWidth: .infinity)
        }
    }
}

struct SparkView: View {
    let files: [LoadedFile]
    var body: some View {
        let sorted = files.sorted { $0.analysis!.seconds > $1.analysis!.seconds }
        let maxS = sorted.first?.analysis!.seconds ?? 1
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(sorted) { f in
                VStack(spacing: 3) {
                    Text("\(Int(f.analysis!.seconds/3600))h").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(4, f.analysis!.seconds/maxS * 120))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .bottom)
    }
}

// MARK: - Files

struct FilesView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("3mf già slicati vengono letti al volo; quelli non slicati li slico con Bambu Studio (profilo H2C).")
                .foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            Button { pick() } label: {
                Text("Trascina qui i .3mf  ·  oppure clicca per sceglierli")
                    .frame(maxWidth: .infinity).padding(.vertical, 26)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 15).strokeBorder(.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6])).background(Color.blue.opacity(0.05).cornerRadius(15)))

            GlassCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("File").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Piatti").frame(width: 60, alignment: .trailing)
                        Text("Tempo").frame(width: 90, alignment: .trailing)
                        Text("Grammi").frame(width: 80, alignment: .trailing)
                        Text("Corrente").frame(width: 90, alignment: .trailing)
                        Text("").frame(width: 90)
                    }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1).padding(.vertical, 8)
                    if m.files.isEmpty {
                        Text("Nessun file caricato.").foregroundStyle(.secondary).font(.system(size: 13)).padding(18)
                    }
                    ForEach(m.files) { f in FileRow(f: f) }
                }
            }
        }
    }
    func pick() {
        let p = NSOpenPanel(); p.allowedContentTypes = [UTType("com.microsoft.3mf") ?? .data]
        p.allowsMultipleSelection = true; p.canChooseFiles = true
        if p.runModal() == .OK { m.add(paths: p.urls.map { $0.path }) }
    }
}

struct FileRow: View {
    @EnvironmentObject var m: AppModel
    @ObservedObject var f: LoadedFile
    var body: some View {
        HStack {
            Text(f.name).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            if let a = f.analysis {
                Text("\(a.plates.count)").frame(width: 60, alignment: .trailing)
                Text(hms(a.seconds)).frame(width: 90, alignment: .trailing)
                Text("\(Int(a.grams))").frame(width: 80, alignment: .trailing)
                Text(eur(a.seconds/3600*m.watts/1000*m.kwh)).frame(width: 90, alignment: .trailing)
                HStack(spacing: 8) {
                    Text("ok").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 2).background(Capsule().fill(.green.opacity(0.14)))
                    Button { m.remove(f) } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }.frame(width: 90, alignment: .trailing)
            } else {
                Text("—").frame(width: 60, alignment: .trailing); Text("—").frame(width: 90, alignment: .trailing)
                Text("—").frame(width: 80, alignment: .trailing); Text("—").frame(width: 90, alignment: .trailing)
                HStack(spacing: 8) {
                    Button("Slica") { m.slice(f) }.buttonStyle(.glassProminent).controlSize(.small)
                    Button { m.remove(f) } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }.frame(width: 90, alignment: .trailing)
            }
        }.font(.system(size: 13)).padding(.vertical, 8)
            .overlay(Divider(), alignment: .top)
    }
}

// MARK: - Colors

struct ColorsView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prezzo per bobina con gli sconti quantità dello store Bambu (−35% da 4, −45% da 6, −50% da 10).")
                .foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            GlassCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("Bobina").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Grammi").frame(width: 80, alignment: .trailing)
                        Text("Bobine").frame(width: 70, alignment: .trailing)
                        Text("€/cad").frame(width: 80, alignment: .trailing)
                        Text("Totale").frame(width: 90, alignment: .trailing)
                    }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1).padding(.vertical, 8)
                    if m.colorRows.isEmpty {
                        Text("Carica dei file per vedere i colori.").foregroundStyle(.secondary).font(.system(size:13)).padding(18)
                    }
                    ForEach(m.colorRows) { r in
                        HStack {
                            HStack(spacing: 9) {
                                RoundedRectangle(cornerRadius: 4).fill(Color(hex: r.hex)).frame(width: 14, height: 14)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.18)))
                                Text("\(r.type) \(r.name)")
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(r.grams))").frame(width: 80, alignment: .trailing)
                            Text("\(r.spools)").frame(width: 70, alignment: .trailing)
                            Text(eur(m.tier.price)).frame(width: 80, alignment: .trailing)
                            Text(eur(Double(r.spools)*m.tier.price)).frame(width: 90, alignment: .trailing)
                        }.font(.system(size: 13)).padding(.vertical, 8).overlay(Divider(), alignment: .top)
                    }
                    if !m.colorRows.isEmpty {
                        HStack {
                            Text("Totale").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(m.totalGrams))").fontWeight(.bold).frame(width: 80, alignment: .trailing)
                            Text("\(m.totalSpools)").fontWeight(.bold).frame(width: 70, alignment: .trailing)
                            Text("").frame(width: 80)
                            Text(eur(m.filamentCost)).fontWeight(.bold).frame(width: 90, alignment: .trailing)
                        }.font(.system(size: 13)).padding(.vertical, 10).overlay(Divider(), alignment: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Plates

struct PlatesView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Piatti leggeri dello stesso colore accorpabili su un piatto H2C: meno riscaldamenti e cambi manuali.")
                .foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    if m.mergeAdvice.isEmpty {
                        Text("Carica dei file per i consigli.").foregroundStyle(.secondary).font(.system(size:13)).padding(18).frame(maxWidth:.infinity)
                    }
                    ForEach(m.mergeAdvice) { a in
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                ForEach(a.colors, id: \.self) { k in
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: String(k.split(separator:"|").first ?? ""))).frame(width: 10, height: 10)
                                }
                                Text(a.file).font(.system(size: 11.5, weight: .semibold))
                            }.padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(.regularMaterial))
                            Text("piatti \(a.from.map(String.init).joined(separator: ", "))").font(.system(size: 11.5, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(.regularMaterial))
                            Text("→").foregroundStyle(.secondary)
                            Text("\(a.to) H2C").font(.system(size: 11.5, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(.regularMaterial))
                            Spacer()
                            Text("−\(a.saved) min").font(.system(size: 12, weight: .bold)).foregroundStyle(.green)
                        }.padding(.vertical, 10).overlay(Divider(), alignment: .top)
                    }
                    if !m.mergeAdvice.isEmpty {
                        let tot = Double(m.mergeAdvice.reduce(0){$0+$1.saved})/60
                        Text("Regola d'oro: accorpa solo pezzi dello stesso colore. Risparmio stimato: \(String(format:"%.1f", tot)) ore")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

// MARK: - Setup

struct SetupView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("I valori si applicano subito a tutti i calcoli.").foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            HStack(alignment: .top, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Field(label: "Stampante (precompila i watt)") {
                            Picker("", selection: Binding(
                                get: { m.printers.firstIndex { $0.1 == m.watts } ?? 0 },
                                set: { m.watts = m.printers[$0].1 })) {
                                ForEach(0..<m.printers.count, id: \.self) { i in Text("\(m.printers[i].0) · \(Int(m.printers[i].1)) W").tag(i) }
                            }.labelsHidden()
                        }
                        Field(label: "Potenza media in stampa (W)") { TextField("", value: $m.watts, format: .number).textFieldStyle(.roundedBorder) }
                        Field(label: "Energia — €/kWh (bolletta)") { TextField("", value: $m.kwh, format: .number).textFieldStyle(.roundedBorder) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Field(label: "Listino bobina 1 kg (€)") { TextField("", value: $m.msrp, format: .number).textFieldStyle(.roundedBorder) }
                        Field(label: "Sconti quantità store") {
                            Text("−35% da 4 · −45% da 6 · −50% da 10 (auto sul totale bobine)")
                                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct Field<Content: View>: View {
    let label: String; @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).tracking(1)
            content
        }
    }
}

struct BusyBar: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) { ProgressView().controlSize(.small); Text(text).font(.system(size: 13)) }
            .padding(.horizontal, 20).padding(.vertical, 11)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 26)
    }
}
