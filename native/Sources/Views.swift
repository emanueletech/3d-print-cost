import SwiftUI
import UniformTypeIdentifiers

// MARK: - Entry point

@main
struct CostoStampaApp: App {
    @StateObject private var m = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(m).frame(minWidth: 1020, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// Sfondo aurora più saturo → dà contrasto al vetro sopra.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color(hex: "0f1420"))
            RadialGradient(colors: [Color(hex:"ff9a6c").opacity(0.55), .clear], center: .init(x:0.02,y:-0.12), startRadius: 0, endRadius: 720)
            RadialGradient(colors: [Color(hex:"4aa3ff").opacity(0.55), .clear], center: .init(x:1.08,y:0.0), startRadius: 0, endRadius: 780)
            RadialGradient(colors: [Color(hex:"ff77c2").opacity(0.4), .clear], center: .init(x:0.5,y:1.18), startRadius: 0, endRadius: 820)
            RadialGradient(colors: [Color(hex:"7c5cff").opacity(0.28), .clear], center: .init(x:0.35,y:0.6), startRadius: 0, endRadius: 640)
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
        .preferredColorScheme(.dark)
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
            Text(m.t("brand"))
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .padding(.horizontal, 6).padding(.bottom, 6)

            // selettore lingua
            HStack(spacing: 6) {
                ForEach(Lang.allCases) { l in
                    Button { m.lang = l } label: {
                        Text(l.flag).font(.system(size: 15))
                            .frame(width: 30, height: 26)
                            .background(RoundedRectangle(cornerRadius: 8).fill(m.lang == l ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(m.lang == l ? 0 : 0.12)))
                    }.buttonStyle(.plain).help(l.label)
                }
            }.padding(.horizontal, 6).padding(.bottom, 12)

            ForEach(AppModel.Section.allCases) { s in
                Button { m.section = s } label: {
                    HStack(spacing: 11) {
                        Image(systemName: s.icon).font(.system(size: 13)).frame(width: 20)
                            .foregroundStyle(m.section == s ? .white : .secondary)
                        Text(m.t(s.locKey)).font(.system(size: 13.5, weight: m.section == s ? .semibold : .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .foregroundStyle(m.section == s ? .white : .primary)
                    .background {
                        if m.section == s {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.28))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor.opacity(0.5)))
                        }
                    }
                }.buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(.yellow)
                Text("Bambu Lab H2C · \(Int(m.watts)) W · \(m.kwh, specifier: "%.3f") €/kWh")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 44).padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 224)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(width: 1), alignment: .trailing)
    }
}

// MARK: - Detail router

struct Detail: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(m.t(m.section.locKey)).font(.system(size: 30, weight: .bold, design: .serif))
                switch m.section {
                case .overview: OverviewView()
                case .files: FilesView()
                case .colors: ColorsView()
                case .plates: PlatesView()
                case .setup: SetupView()
                }
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 40)
            .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Card di vetro ben definita: materiale + bordo luminoso + ombra.
struct GlassCard<Content: View>: View {
    var pad: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(pad)
            .background(RoundedRectangle(cornerRadius: 18).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.14)))
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }
}

struct StatCard: View {
    let icon: String; let tint: Color; let k: String; let v: String; var d: String = ""
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(tint.opacity(0.16)))
                    Spacer()
                }
                Text(k.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                Text(v).font(.system(size: 28, weight: .bold, design: .rounded))
                if !d.isEmpty { Text(d).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(tint) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var m: AppModel
    let cols = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(m.loaded.isEmpty ? m.t("dropStart")
                 : "\(m.loaded.count) \(m.t("files")) · \(m.totalPlates) \(m.t("kPlates").lowercased()) · Bambu Lab H2C")
                .foregroundStyle(.secondary).font(.system(size: 13)).padding(.bottom, 16)

            LazyVGrid(columns: cols, spacing: 13) {
                StatCard(icon: "clock.fill", tint: .blue, k: m.t("kTime"),
                    v: m.loaded.isEmpty ? "—" : "\(Int(m.totalSeconds/3600)) h",
                    d: m.loaded.isEmpty ? "" : "≈ \(Int(ceil(m.totalSeconds/86400))) \(m.t("days"))")
                StatCard(icon: "cube.fill", tint: .purple, k: m.t("kMat"),
                    v: m.loaded.isEmpty ? "—" : String(format:"%.1f kg", m.totalGrams/1000),
                    d: m.colorRows.isEmpty ? "" : "\(m.colorRows.count) \(m.t("colors"))")
                StatCard(icon: "cylinder.fill", tint: .teal, k: m.t("kSpools"),
                    v: m.loaded.isEmpty ? "—" : "\(m.totalSpools)", d: m.t("refills"))
                StatCard(icon: "eurosign.circle.fill", tint: .green, k: m.t("kFil"),
                    v: m.loaded.isEmpty ? "—" : eur(m.filamentCost), d: m.loaded.isEmpty ? "" : m.unitPrice.label)
                StatCard(icon: "bolt.fill", tint: .orange, k: m.t("kEnergy"),
                    v: m.loaded.isEmpty ? "—" : eur(m.energyCost), d: m.loaded.isEmpty ? "" : String(format:"%.1f kWh", m.kWh))
                StatCard(icon: "square.grid.3x3.fill", tint: .pink, k: m.t("kPlates"),
                    v: m.loaded.isEmpty ? "—" : "\(m.totalPlates)", d: "")
            }

            if !m.loaded.isEmpty {
                HStack(alignment: .top, spacing: 13) {
                    GlassCard {
                        VStack(alignment: .leading) {
                            Label(m.t("kByColor"), systemImage: "chart.pie.fill").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                            DonutView(rows: m.colorRows, total: m.totalGrams).frame(height: 180)
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading) {
                            Label(m.t("kHours"), systemImage: "chart.bar.fill").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                            SparkView(files: m.loaded).frame(height: 160)
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
                        var path = Path(); path.move(to: c)
                        path.addArc(center: c, radius: r, startAngle: .degrees(start), endAngle: .degrees(start+sweep), clockwise: false)
                        ctx.fill(path, with: .color(Color(hex: row.hex)))
                        start += sweep
                    }
                    let hole = CGRect(x: c.x - r*0.6, y: c.y - r*0.6, width: r*1.2, height: r*1.2)
                    ctx.blendMode = .destinationOut
                    ctx.fill(Path(ellipseIn: hole), with: .color(.black))
                }
                Text(String(format: "%.1f kg", total/1000)).font(.system(size: 20, weight: .bold, design: .rounded))
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
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
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
            Text(m.t("sFiles")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            Button { pick() } label: {
                HStack(spacing: 10) { Image(systemName: "square.and.arrow.down.on.square"); Text(m.t("dropHere")) }
                    .frame(maxWidth: .infinity).padding(.vertical, 26).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 15).strokeBorder(.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6])).background(Color.blue.opacity(0.08).cornerRadius(15)))

            GlassCard(pad: 6) {
                VStack(spacing: 0) {
                    header([("thFile", nil), ("thPlates", 60), ("thTime", 90), ("thGrams", 80), ("thEnergy", 90), (nil, 92)])
                    if m.files.isEmpty {
                        Text(m.t("noFiles")).foregroundStyle(.secondary).font(.system(size: 13)).padding(18)
                    }
                    ForEach(m.files) { f in FileRow(f: f) }
                }
            }
        }
    }
    @ViewBuilder func header(_ cols: [(String?, CGFloat?)]) -> some View {
        HStack {
            ForEach(Array(cols.enumerated()), id: \.offset) { _, c in
                let t = c.0.map { m.t($0) } ?? ""
                if let w = c.1 { Text(t).frame(width: w, alignment: .trailing) }
                else { Text(t).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8).padding(.horizontal, 10).padding(.vertical, 9)
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
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 13))
                    Button { m.remove(f) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }.frame(width: 92, alignment: .trailing)
            } else {
                ForEach([60.0,90,80,90], id: \.self) { w in Text("—").frame(width: w, alignment: .trailing) }
                HStack(spacing: 8) {
                    Button(m.t("slice")) { m.slice(f) }.buttonStyle(.borderedProminent).controlSize(.small)
                    Button { m.remove(f) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }.frame(width: 92, alignment: .trailing)
            }
        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 9)
            .overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }
}

// MARK: - Colors

struct ColorsView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sColors")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            SourcePicker()
            GlassCard(pad: 6) {
                VStack(spacing: 0) {
                    HStack {
                        Text(m.t("thSpool")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(m.t("thGrams")).frame(width: 80, alignment: .trailing)
                        Text(m.t("thQty")).frame(width: 70, alignment: .trailing)
                        Text(m.t("thUnit")).frame(width: 80, alignment: .trailing)
                        Text(m.t("thTot")).frame(width: 90, alignment: .trailing)
                    }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8).padding(.horizontal, 10).padding(.vertical, 9)
                    if m.colorRows.isEmpty {
                        Text(m.t("noColors")).foregroundStyle(.secondary).font(.system(size:13)).padding(18)
                    }
                    ForEach(m.colorRows) { r in
                        HStack {
                            HStack(spacing: 9) {
                                RoundedRectangle(cornerRadius: 4).fill(Color(hex: r.hex)).frame(width: 15, height: 15)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.25)))
                                Text("\(r.type) \(r.name)")
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(r.grams))").frame(width: 80, alignment: .trailing)
                            Text("\(r.spools)").frame(width: 70, alignment: .trailing)
                            Text(eur(m.unitPrice.price)).frame(width: 80, alignment: .trailing)
                            Text(eur(Double(r.spools)*m.unitPrice.price)).frame(width: 90, alignment: .trailing).fontWeight(.semibold)
                        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 9).overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                    }
                    if !m.colorRows.isEmpty {
                        HStack {
                            Text(m.t("total")).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(m.totalGrams))").fontWeight(.bold).frame(width: 80, alignment: .trailing)
                            Text("\(m.totalSpools)").fontWeight(.bold).frame(width: 70, alignment: .trailing)
                            Text("").frame(width: 80)
                            Text(eur(m.filamentCost)).fontWeight(.bold).foregroundStyle(.green).frame(width: 90, alignment: .trailing)
                        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 11).overlay(Rectangle().fill(.white.opacity(0.12)).frame(height: 1), alignment: .top)
                    }
                }
            }
        }
    }
}

// selettore filamento (refill / bobina / altra marca) usato in Colori e Setup
struct SourcePicker: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: $m.source) {
                    Text(m.t("srcRefill")).tag(AppModel.FilamentSource.bambuRefill)
                    Text(m.t("srcSpool")).tag(AppModel.FilamentSource.bambuSpool)
                    Text(m.t("srcOther")).tag(AppModel.FilamentSource.other)
                }.pickerStyle(.segmented).labelsHidden()

                switch m.source {
                case .bambuRefill:
                    priceField(m.t("fMsrp"), $m.msrp); note(m.t("tierNote"))
                case .bambuSpool:
                    priceField(m.t("fSpoolPrice"), $m.spoolPrice); note(m.t("tierNote"))
                case .other:
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(m.t("fOtherBrand").uppercased()).font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary).tracking(0.8)
                            TextField("", text: $m.otherBrand).textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(m.t("fOtherPrice").uppercased()).font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary).tracking(0.8)
                            TextField("", value: $m.otherPrice, format: .number).textFieldStyle(.roundedBorder).frame(width: 140)
                        }
                    }
                    note(m.t("otherNote"))
                }
            }
        }
    }
    @ViewBuilder func priceField(_ label: String, _ b: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary).tracking(0.8)
            TextField("", value: b, format: .number).textFieldStyle(.roundedBorder).frame(width: 160)
        }
    }
    @ViewBuilder func note(_ s: String) -> some View {
        Text(s).font(.system(size: 12)).foregroundStyle(.secondary)
    }
}

// MARK: - Plates

struct PlatesView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sPlates")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            GlassCard(pad: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    if m.mergeAdvice.isEmpty {
                        Text(m.t("noPlates")).foregroundStyle(.secondary).font(.system(size:13)).padding(18).frame(maxWidth:.infinity)
                    }
                    ForEach(m.mergeAdvice) { a in
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                ForEach(a.colors, id: \.self) { k in
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: String(k.split(separator:"|").first ?? ""))).frame(width: 11, height: 11)
                                }
                                Text(a.file).font(.system(size: 11.5, weight: .semibold))
                            }.padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(.white.opacity(0.1)))
                            Text("\(m.t("thPlates")) \(a.from.map(String.init).joined(separator: ", "))").font(.system(size: 11.5, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(.white.opacity(0.1)))
                            Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.secondary)
                            Text("\(a.to) H2C").font(.system(size: 11.5, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(.green.opacity(0.18)))
                            Spacer()
                            Text("−\(a.saved) min").font(.system(size: 12, weight: .bold)).foregroundStyle(.green)
                        }.padding(.horizontal, 8).padding(.vertical, 10).overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                    }
                    if !m.mergeAdvice.isEmpty {
                        let tot = Double(m.mergeAdvice.reduce(0){$0+$1.saved})/60
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 11)).foregroundStyle(.yellow)
                            Text("\(m.t("rule")) \(String(format:"%.1f", tot)) \(m.t("hours"))").font(.system(size: 12)).foregroundStyle(.secondary)
                        }.padding(.horizontal, 8).padding(.vertical, 11)
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
            Text(m.t("sSetup")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            HStack(alignment: .top, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Field(m.t("fPrinter")) {
                            Picker("", selection: Binding(
                                get: { m.printers.firstIndex { $0.1 == m.watts } ?? 0 },
                                set: { m.watts = m.printers[$0].1 })) {
                                ForEach(0..<m.printers.count, id: \.self) { i in Text("\(m.printers[i].0) · \(Int(m.printers[i].1)) W").tag(i) }
                            }.labelsHidden()
                        }
                        Field(m.t("fWatts")) { TextField("", value: $m.watts, format: .number).textFieldStyle(.roundedBorder) }
                        Field(m.t("fKwh")) { TextField("", value: $m.kwh, format: .number).textFieldStyle(.roundedBorder) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: 14) {
                    Label(m.t("fSource"), systemImage: "cylinder.split.1x2.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    SourcePicker()
                }
            }
        }
    }
    @ViewBuilder func Field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
            content()
        }
    }
}

struct BusyBar: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) { ProgressView().controlSize(.small); Text(text).font(.system(size: 13)) }
            .padding(.horizontal, 20).padding(.vertical, 11)
            .background(Capsule().fill(.regularMaterial)).overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
            .padding(.bottom, 26)
    }
}
