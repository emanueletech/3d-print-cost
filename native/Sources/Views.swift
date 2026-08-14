import SwiftUI
import UniformTypeIdentifiers

// MARK: - Entry point

@main
struct CostoStampaApp: App {
    @StateObject private var m = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(m).frame(minWidth: 1020, minHeight: 680)
                .onOpenURL { m.handleURL($0) }     // ritorno dal bot Telegram → sblocco
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
            if let n = m.notice { NoticeBar(text: n).padding(.bottom, m.busy != nil ? 58 : 0) }
            if let u = m.updateTag { UpdateBar(tag: u).frame(maxHeight: .infinity, alignment: .top).padding(.top, 16) }
            if !m.unlocked { GateView() }        // schermata di sblocco all'avvio
        }
        .preferredColorScheme(.dark)
        // tabella del confronto stampanti (v1.3)
        .sheet(item: $m.compareData) { d in CompareSheet(d: d).environmentObject(m) }
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

// MARK: - Schermata di sblocco (follow-gate)

struct GateView: View {
    @EnvironmentObject var m: AppModel
    @State private var code = ""
    @State private var codeWrong = false
    var body: some View {
        ZStack {
            AuroraBackground()
            Rectangle().fill(.black.opacity(0.35)).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.open.fill").font(.system(size: 28)).foregroundStyle(.white)
                    .frame(width: 62, height: 62).background(Circle().fill(Color.accentColor.opacity(0.9)))
                    .shadow(color: .accentColor.opacity(0.5), radius: 16)
                Text(m.t("gateTitle")).font(.system(size: 30, weight: .bold, design: .serif))
                Text(m.t("gateBody")).font(.system(size: 14)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 430).fixedSize(horizontal: false, vertical: true)

                // 1) prima il follow: apre il profilo e abilita il passaggio Telegram
                HStack(spacing: 14) {
                    follow("camera.fill", "Instagram", .pink, Author.instagram)
                    follow("cube.fill", "MakerWorld", .orange, Author.makerworld)
                    follow("play.rectangle.fill", "YouTube", .red, Author.youtube)
                }

                Divider().frame(width: 300).padding(.vertical, 2)

                // 2) poi la verifica via Telegram — attiva solo dopo il follow
                Group {
                    Button { m.openSocial(Author.telegramBot) } label: {
                        HStack(spacing: 8) { Image(systemName: "paperplane.fill"); Text(m.t("gateTelegram")).fontWeight(.semibold) }
                            .frame(maxWidth: 300).padding(.vertical, 4)
                    }.buttonStyle(.borderedProminent).controlSize(.large).tint(Color(hex: "229ED9"))
                    Text(m.t(m.followClicked ? "gateTgHint" : "gateLocked")).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 430)

                    // token incollato a mano, per quando il deep-link non si apre
                    VStack(spacing: 6) {
                        Text(m.t("gateCodeMobile")).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            // accoglie il token firmato incollato (~140 caratteri), non più un codice a 6 cifre
                            TextField(m.t("gateCodePlaceholder"), text: $code)
                                .textFieldStyle(.plain).font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .multilineTextAlignment(.center).frame(width: 280)
                                .padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.12)))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(codeWrong ? Color.red : .white.opacity(0.2)))
                                .onSubmit(submitCode)
                            Button(m.t("gateUnlock")) { submitCode() }.buttonStyle(.borderedProminent).controlSize(.regular)
                        }
                        if codeWrong { Text(m.t("gateCodeWrong")).font(.system(size: 11)).foregroundStyle(.red) }
                    }
                }
                .disabled(!m.followClicked)
                .opacity(m.followClicked ? 1 : 0.55)

                HStack(spacing: 7) {
                    Image(systemName: "info.circle").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Text(m.t("affiliate")).font(.system(size: 10.5)).foregroundStyle(.tertiary)
                }.padding(.top, 4)
            }
            .padding(38)
            .background(RoundedRectangle(cornerRadius: 24).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.4), radius: 30, y: 16)
            .frame(maxWidth: 540)
        }
        .preferredColorScheme(.dark)
    }
    func submitCode() { withAnimation { codeWrong = !m.tryUnlockCode(code) } }
    @ViewBuilder func follow(_ icon: String, _ name: String, _ tint: Color, _ url: String) -> some View {
        Button { m.followTapped(url) } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 17)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(tint))
                Text(name).font(.system(size: 10.5, weight: .medium))
            }
        }.buttonStyle(.plain)
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

            // gruppo Progetto
            navGroup(m.t("grpProject"), [.overview, .files, .orient, .colors, .plates, .history, .quote])
            Spacer().frame(height: 14)
            // gruppo Impostazioni (separato, stile iOS)
            navGroup(m.t("grpSettings"), [.materials, .printers, .setup])
            Spacer()
            // crediti autore + social
            VStack(alignment: .leading, spacing: 7) {
                Text(m.t("followFree")).font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text("\(m.t("madeBy")) \(Author.name)").font(.system(size: 10.5, weight: .semibold))
                    Spacer()
                    socialBtn("camera.fill", Author.instagram, "Instagram")
                    socialBtn("paperplane.fill", Author.telegram, "Telegram")
                    socialBtn("cube.fill", Author.makerworld, "MakerWorld")
                }
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08)))
        }
        .padding(.top, 44).padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 224)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(width: 1), alignment: .trailing)
    }

    @ViewBuilder func socialBtn(_ icon: String, _ url: String, _ help: String) -> some View {
        Button { m.openSocial(url) } label: {
            Image(systemName: icon).font(.system(size: 12)).frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.1)))
        }.buttonStyle(.plain).foregroundStyle(.secondary).help(help)
    }

    @ViewBuilder func navGroup(_ title: String, _ items: [AppModel.Section]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.bottom, 4)
            ForEach(items) { s in
                Button { m.section = s } label: {
                    HStack(spacing: 11) {
                        Image(systemName: s.icon).font(.system(size: 13)).frame(width: 20)
                            .foregroundStyle(m.section == s ? .white : .secondary)
                        Text(m.t(s.locKey)).font(.system(size: 13.5, weight: m.section == s ? .semibold : .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
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
        }
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
                case .orient: OrientView()
                case .colors: ColorsView()
                case .materials: MaterialsView()
                case .printers: PrintersView()
                case .plates: PlatesView()
                case .history: HistoryView()
                case .quote: QuoteView()
                case .setup: SetupView()
                }
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 40)
            .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Etichetta immediata al passaggio del mouse: i tooltip di sistema (.help)
/// compaiono dopo circa un secondo e i pulsanti-icona restavano muti.
struct HoverHint: ViewModifier {
    let text: String
    @State private var over = false
    func body(content: Content) -> some View {
        content
            .onHover { over = $0 }
            .overlay(alignment: .topTrailing) {
                if over {
                    Text(text)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.88)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.16)))
                        .fixedSize()
                        .offset(y: -27)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.12), value: over)
    }
}
extension View {
    func hoverHint(_ text: String) -> some View { modifier(HoverHint(text: text)) }
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

struct StatRow: Identifiable { let id = UUID(); let hex: String; let name: String; let value: String }

/// Grammi esatti: sotto il chilo in g, sopra in kg con precisione al grammo.
func gramsLabel(_ g: Double) -> String {
    g < 1000 ? String(format: "%.0f g", g) : String(format: "%.3f kg", g / 1000)
}

/// Tempo compatto per i badge dei piatti: "45m", "3h20", "12h".
func shortTime(_ secs: Double) -> String {
    if secs < 3600 { return "\(max(1, Int((secs / 60).rounded())))m" }
    let h = Int(secs) / 3600
    let m = Int(((secs.truncatingRemainder(dividingBy: 3600)) / 60).rounded())
    return (h >= 10 || m == 0) ? "\(h)h" : String(format: "%dh%02d", h, m)
}

struct StatCard: View {
    @EnvironmentObject var m: AppModel
    let icon: String; let tint: Color; let k: String; let v: String; var d: String = ""
    var goto: AppModel.Section? = nil
    var rows: [StatRow] = []          // dettaglio per colore, mostrato in un popover
    @State private var showDetail = false
    var body: some View {
        let card = GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(tint.opacity(0.16)))
                    Spacer()
                    if goto != nil || !rows.isEmpty { Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary) }
                }
                Text(k.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                Text(v).font(.system(size: 28, weight: .bold, design: .rounded))
                if !d.isEmpty { Text(d).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(tint) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        if !rows.isEmpty {
            Button { showDetail = true } label: { card }.buttonStyle(.plain).pointerStyle(.link)
                .popover(isPresented: $showDetail, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(k.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                        ForEach(rows) { r in
                            HStack(spacing: 9) {
                                Circle().fill(Color(hex: r.hex)).frame(width: 11, height: 11)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                                Text(r.name).font(.system(size: 12.5)).lineLimit(1)
                                Spacer(minLength: 26)
                                Text(r.value).font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                            }
                        }
                        if let g = goto {
                            Divider()
                            Button { showDetail = false; m.section = g } label: {
                                HStack(spacing: 4) { Text(m.t("openSection")); Image(systemName: "chevron.right") }
                                    .font(.system(size: 11.5, weight: .semibold))
                            }.buttonStyle(.plain).foregroundStyle(.secondary).pointerStyle(.link)
                        }
                    }.padding(15).frame(minWidth: 250)
                }
        } else if let g = goto {
            Button { m.section = g } label: { card }.buttonStyle(.plain).pointerStyle(.link)
        } else { card }
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
                    d: m.loaded.isEmpty ? "" : "≈ \(Int(ceil(m.totalSeconds/86400))) \(m.t("days"))",
                    goto: m.loaded.isEmpty ? nil : .plates)
                StatCard(icon: "cube.fill", tint: .purple, k: m.t("kMat"),
                    v: m.loaded.isEmpty ? "—" : String(format:"%.1f kg", m.totalGrams/1000),
                    d: m.colorRows.isEmpty ? "" : "\(m.colorRows.count) \(m.t("colors"))",
                    goto: m.loaded.isEmpty ? nil : .colors,
                    rows: m.colorRows.map { StatRow(hex: $0.hex, name: $0.name, value: gramsLabel($0.grams)) })
                StatCard(icon: "eurosign.circle.fill", tint: .green, k: m.t("matReal"),
                    v: m.loaded.isEmpty ? "—" : eur(m.cost.material), d: m.loaded.isEmpty ? "" : m.t("matUsed"),
                    goto: m.loaded.isEmpty ? nil : .materials,
                    rows: m.colorRows.map { r in
                        let perKg = m.material(forHex: r.hex, type: r.type)?.effectiveCostPerKg ?? m.fallbackCostPerKg
                        return StatRow(hex: r.hex, name: r.name, value: eur(r.grams / 1000 * perKg))
                    })
                StatCard(icon: "cylinder.fill", tint: .teal, k: m.t("kSpools"),
                    v: m.loaded.isEmpty ? "—" : "\(m.totalSpools)", d: m.loaded.isEmpty ? "" : "\(eur(m.filamentCost)) · \(m.t("ifBuy"))",
                    goto: m.loaded.isEmpty ? nil : .colors)
                StatCard(icon: "bolt.fill", tint: .orange, k: m.t("kEnergy"),
                    v: m.loaded.isEmpty ? "—" : eur(m.energyCost), d: m.loaded.isEmpty ? "" : String(format:"%.1f kWh", m.kWh),
                    goto: m.loaded.isEmpty ? nil : .setup)
                StatCard(icon: "square.grid.3x3.fill", tint: .pink, k: m.t("kPlates"),
                    v: m.loaded.isEmpty ? "—" : "\(m.totalPlates)", d: m.loaded.isEmpty ? "" : m.t("nFiles"),
                    goto: m.loaded.isEmpty ? nil : .files)
            }

            if !m.loaded.isEmpty {
                HStack(alignment: .top, spacing: 13) {
                    Button { m.section = .colors } label: {
                        GlassCard {
                            VStack(alignment: .leading) {
                                Label(m.t("kByColor"), systemImage: "chart.pie.fill").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                                DonutView(rows: m.colorRows, total: m.totalGrams).frame(height: 180)
                            }
                        }
                    }.buttonStyle(.plain).pointerStyle(.link)
                    Button { m.section = .files } label: {
                        GlassCard {
                            VStack(alignment: .leading) {
                                Label(m.t("kHours"), systemImage: "chart.bar.fill").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                                SparkView(files: m.loaded).frame(height: 160)
                            }
                        }
                    }.buttonStyle(.plain).pointerStyle(.link)
                }.padding(.top, 13)

                Button { m.section = .setup } label: { RealCostCard() }.buttonStyle(.plain).pointerStyle(.link)
                    .padding(.top, 13)
            }
        }
    }
}

// Scomposizione del costo reale della stampa (vista maker)
struct RealCostCard: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let c = m.cost
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(m.t("realCost"), systemImage: "eurosign.circle.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 8) {
                        row("cMaterial", c.material, .purple)
                        row("cEnergy", c.energy, .orange)
                        row("cWear", c.wear, .blue)
                        row("cSetup", c.setup, .teal)
                        row("cFailure", c.failure, .red)
                    }.frame(maxWidth: .infinity)
                    // colonna totale + upfront
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(m.t("cTotal").uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                        Text(eur(c.total)).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.green)
                        Divider().frame(width: 140).padding(.vertical, 4)
                        Text(m.t("cUpfront").uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5).multilineTextAlignment(.trailing)
                        Text(eur(c.spools)).font(.system(size: 18, weight: .semibold, design: .rounded))
                    }.frame(width: 200, alignment: .trailing)
                }
            }
        }
    }
    @ViewBuilder func row(_ key: String, _ v: Double, _ tint: Color) -> some View {
        let c = m.cost
        HStack {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(m.t(key)).font(.system(size: 13))
            Spacer()
            // barra proporzionale al totale base
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 3).fill(tint.opacity(0.25))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: g.size.width * min(1, v / max(c.total, 0.01)))
                    }
            }.frame(height: 6).frame(maxWidth: 120)
            Text(eur(v)).font(.system(size: 13, weight: .medium)).frame(width: 70, alignment: .trailing)
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
        let secs: [(LoadedFile, Double)] = files.map { ($0, $0.includedPlates.reduce(0) { $0 + $1.seconds }) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        let maxS = secs.first?.1 ?? 1
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(secs, id: \.0.id) { f, s in
                VStack(spacing: 3) {
                    Text("\(Int(s/3600))h").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(4, s/maxS * 120))
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
            // testo e comandi seguono la stampante selezionata (v1.2)
            let spec = m.selectedPrinter?.slicing
            let isBambu = spec == nil || spec!.engine == "bambu"
            if isBambu {
                Text(String(format: m.t("sFilesBambu"),
                            String(format: "%.1f", m.nozzle), String(format: "%.2f", m.layerHeight)))
                    .foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
                HStack(spacing: 16) {
                    Picker(m.t("lblNozzle"), selection: $m.nozzle) {
                        ForEach([0.2, 0.4, 0.6, 0.8], id: \.self) { Text(String(format: "%.1f mm", $0)).tag($0) }
                    }.pickerStyle(.menu).fixedSize()
                    Picker(m.t("lblLayer"), selection: $m.layerHeight) {
                        ForEach(Self.layerChoices(m.nozzle), id: \.self) { Text(String(format: "%.2f mm", $0)).tag($0) }
                    }.pickerStyle(.menu).fixedSize()
                    Spacer()
                }
                .onChange(of: m.nozzle) { _, nz in
                    if !Self.layerChoices(nz).contains(m.layerHeight) { m.layerHeight = Self.defaultLayer(nz) }
                }
            } else {
                Text(String(format: m.t("sFilesExport"),
                            m.selectedPrinter?.name ?? "—", m.slicerAppName(spec!.engine)))
                    .foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            }
            Button { pick() } label: {
                HStack(spacing: 10) { Image(systemName: "square.and.arrow.down.on.square"); Text(m.t("dropHere")) }
                    .frame(maxWidth: .infinity).padding(.vertical, 26).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 15).strokeBorder(.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6])).background(Color.blue.opacity(0.08).cornerRadius(15)))

            if m.files.isEmpty {
                GlassCard { Text(m.t("noFiles")).foregroundStyle(.secondary).font(.system(size: 13)).padding(18).frame(maxWidth: .infinity) }
            } else {
                VStack(spacing: 11) { ForEach(m.files) { f in FileCard(f: f) } }
            }
        }
    }
    func pick() {
        let p = NSOpenPanel(); p.allowedContentTypes = [UTType("com.microsoft.3mf") ?? .data]
        p.allowsMultipleSelection = true; p.canChooseFiles = true
        if p.runModal() == .OK { m.add(paths: p.urls.map { $0.path }) }
    }
    /// altezze layer sensate per ugello (passo tipico della famiglia Orca)
    static func layerChoices(_ nozzle: Double) -> [Double] {
        switch nozzle {
        case 0.2: return [0.06, 0.08, 0.10, 0.12, 0.14]
        case 0.6: return [0.18, 0.24, 0.30, 0.36, 0.42]
        case 0.8: return [0.24, 0.32, 0.40, 0.48, 0.56]
        default:  return [0.08, 0.12, 0.16, 0.20, 0.24, 0.28]
        }
    }
    static func defaultLayer(_ nozzle: Double) -> Double {
        switch nozzle {
        case 0.2: return 0.10
        case 0.6: return 0.30
        case 0.8: return 0.40
        default:  return 0.20
        }
    }
}

struct FileCard: View {
    @EnvironmentObject var m: AppModel
    @ObservedObject var f: LoadedFile
    @State private var showCompare = false
    var body: some View {
        GlassCard(pad: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill").foregroundStyle(.secondary).font(.system(size: 13))
                    Text(f.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                    Spacer()
                    if f.analysis != nil {
                        let inc = f.includedPlates
                        let secs = inc.reduce(0) { $0 + $1.seconds }
                        let g = inc.reduce(0) { $0 + $1.grams }
                        stat("\(inc.count)/\(f.analysis!.plates.count)", m.t("thPlates"))
                        stat(hms(secs), m.t("thTime"))
                        stat("\(Int(g)) g", m.t("thGrams"))
                        stat(eur(secs/3600*m.watts/1000*m.kwh), m.t("thEnergy"))
                        // giro incrementale: piatti spenti selezionati e pronti da slicare
                        if !f.toSlice.isEmpty {
                            Button("\(m.t("slice")) (\(f.toSlice.count))") { m.slice(f) }
                                .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
                        }
                        // registro costi: salva i numeri di questo file com'è adesso (v1.3)
                        Button { m.logEntry(name: f.name.replacingOccurrences(of: ".3mf", with: ""),
                                            plates: f.includedPlates) } label: {
                            Image(systemName: "tray.and.arrow.down")
                        }.buttonStyle(.plain).foregroundStyle(.secondary)
                            .help(m.t("histSave")).hoverHint(m.t("histSave"))
                        // confronto con un'altra stampante Bambu (v1.3)
                        if !m.compareTargets.isEmpty {
                            Button { showCompare = true } label: { Image(systemName: "arrow.left.arrow.right") }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                                .help(m.t("cmpTip")).hoverHint(m.t("cmpTip"))
                                .popover(isPresented: $showCompare, arrowEdge: .bottom) {
                                    ComparePicker(f: f) { showCompare = false }.environmentObject(m)
                                }
                        }
                        // rislica da capo col setup attuale (stampante/ugello/layer)
                        Button { m.slice(f, fresh: true) } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .help(m.t("reslice")).hoverHint(m.t("reslice"))
                    } else {
                        if case .error(let e) = f.state {
                            Label(m.t(e == "noBambu" ? "noBambuShort" : "sliceFailed"), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.orange)
                                .lineLimit(2).frame(maxWidth: 300, alignment: .trailing)
                        }
                        // stampante con slicer proprio (U1/Elegoo): la via maestra è
                        // slicare lì ed esportare — se l'app c'è, la apriamo noi
                        if let spec = m.selectedPrinter?.slicing, spec.engine != "bambu",
                           m.slicerAppPath(spec.engine) != nil {
                            Button(String(format: m.t("openIn"), m.slicerAppName(spec.engine))) { m.openInSlicer(f) }
                                .buttonStyle(.borderedProminent).controlSize(.small)
                            Button(m.t("slice")) { m.slice(f) }.buttonStyle(.bordered).controlSize(.small)
                        } else {
                            Button(m.t("slice")) { m.slice(f) }.buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
                    Button { m.remove(f) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
                // striscia anteprime piatti — cliccabili per includere/escludere
                if !f.thumbs.isEmpty {
                    // nei file già slicati contano solo i piatti con dati: le altre
                    // anteprime (es. export di un piatto solo) restano spente
                    let dataIdx: Set<Int>? = f.analysis.map { Set($0.plates.map(\.index)) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(f.thumbs.enumerated()), id: \.offset) { i, img in
                                if let d = dataIdx, !d.contains(i+1) {
                                    // piatto senza dati: spento ma cliccabile, per slicarlo in un secondo momento
                                    let pick = f.toSlice.contains(i+1)
                                    Button { m.togglePick(f, i+1) } label: {
                                        ZStack(alignment: .topTrailing) {
                                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                                .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 9))
                                                .saturation(pick ? 0.6 : 0).opacity(pick ? 0.85 : 0.25)
                                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(
                                                    pick ? Color.orange.opacity(0.9) : .white.opacity(0.1),
                                                    style: StrokeStyle(lineWidth: pick ? 2 : 1, dash: pick ? [] : [4])))
                                            Image(systemName: pick ? "checkmark.circle.fill" : "plus.circle")
                                                .font(.system(size: 14)).foregroundStyle(pick ? Color.orange : .white.opacity(0.5))
                                                .background(Circle().fill(.black.opacity(0.4))).padding(3)
                                            Text("\(i+1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                                                .padding(.horizontal, 5).padding(.vertical, 1)
                                                .background(Capsule().fill(.black.opacity(0.45)))
                                                .padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                        }.frame(width: 64, height: 64)
                                    }.buttonStyle(.plain)
                                } else {
                                let on = !f.excluded.contains(i+1)
                                Button { m.togglePlate(f, i+1) } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                            .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 9))
                                            .background(RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.15)))
                                            .saturation(on ? 1 : 0).opacity(on ? 1 : 0.4)
                                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(on ? Color.accentColor.opacity(0.9) : .white.opacity(0.12), lineWidth: on ? 2 : 1))
                                        // sui piatti con dati la spunta lascia il posto al tempo di stampa del piatto
                                        if let a = f.analysis, let p = a.plates.first(where: { $0.index == i+1 }) {
                                            Text(shortTime(p.seconds))
                                                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                                                .foregroundStyle(on ? Color.accentColor : .white.opacity(0.5))
                                                .padding(.horizontal, 5).padding(.vertical, 1)
                                                .background(Capsule().fill(.black.opacity(0.6))).padding(3)
                                        } else {
                                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 14)).foregroundStyle(on ? Color.accentColor : .white.opacity(0.7))
                                                .background(Circle().fill(.black.opacity(0.4))).padding(3)
                                        }
                                        Text("\(i+1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(Capsule().fill(.black.opacity(0.55)))
                                            .padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    }.frame(width: 64, height: 64)
                                }.buttonStyle(.plain)
                                }
                            }
                        }.padding(.top, 1)
                    }
                    let hasMore = f.analysis != nil && f.thumbs.count > (f.analysis?.plates.count ?? 0)
                    HStack(spacing: 6) {
                        Text(m.t(hasMore ? "plateMoreHint" : "plateHint")).font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Button(m.t("selAll")) { m.selectAllPlates(f) }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).pointerStyle(.link)
                        Text("·").font(.system(size: 11)).foregroundStyle(.tertiary)
                        Button(m.t("selNone")) { m.selectNoPlates(f) }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).pointerStyle(.link)
                    }
                }
            }
        }
    }
    @ViewBuilder func stat(_ v: String, _ k: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(v).font(.system(size: 13, weight: .semibold)).monospacedDigit()
            Text(k.uppercased()).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
        }.frame(minWidth: 56, alignment: .trailing)
    }
}

// MARK: - Confronto stampanti (v1.3)

/// popover di scelta: con quale altra stampante Bambu confrontare il file
struct ComparePicker: View {
    @EnvironmentObject var m: AppModel
    let f: LoadedFile
    var dismiss: () -> Void
    @State private var targetID: UUID? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(m.t("cmpTitle"), systemImage: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold))
            Text(String(format: m.t("cmpHint"), m.selectedPrinter?.name ?? "—"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).frame(width: 260, alignment: .leading)
            Picker(m.t("cmpWith"), selection: $targetID) {
                ForEach(m.compareTargets) { p in Text(p.name).tag(Optional(p.id)) }
            }.pickerStyle(.menu)
            HStack {
                Spacer()
                Button(m.t("cmpRun")) {
                    if let id = targetID ?? m.compareTargets.first?.id,
                       let p = m.printersDB.first(where: { $0.id == id }) {
                        dismiss()
                        m.compare(f, with: p)
                    }
                }.buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(16)
        .onAppear { if targetID == nil { targetID = m.compareTargets.first?.id } }
    }
}

/// tabella comparativa: stessi piatti, due stampanti
struct CompareSheet: View {
    @EnvironmentObject var m: AppModel
    let d: AppModel.CompareData
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                Text("\(m.t("cmpTitle")) — \(d.file)").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Spacer()
                Button { m.compareData = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            let delta = d.a.cost.total - d.b.cost.total
            let even = abs(delta) < 0.005
            Grid(alignment: .trailing, horizontalSpacing: 22, verticalSpacing: 7) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(d.a.printer).font(.system(size: 12.5, weight: .semibold))
                        Text(m.t("cmpCur").uppercased()).font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(.secondary).tracking(0.5)
                    }
                    Text(d.b.printer).font(.system(size: 12.5, weight: .semibold))
                }
                Divider()
                row(m.t("thTime"), hms(d.a.seconds), hms(d.b.seconds))
                row(m.t("thGrams"), "\(Int(d.a.grams)) g", "\(Int(d.b.grams)) g")
                row(m.t("kEnergy"), String(format: "%.2f kWh", d.a.kWh), String(format: "%.2f kWh", d.b.kWh))
                row(m.t("cMaterial"), eur(d.a.cost.material), eur(d.b.cost.material))
                row(m.t("cEnergy"), eur(d.a.cost.energy), eur(d.b.cost.energy))
                row(m.t("cWear"), eur(d.a.cost.wear), eur(d.b.cost.wear))
                row(m.t("cSetup"), eur(d.a.cost.setup), eur(d.b.cost.setup))
                row(m.t("cFailure"), eur(d.a.cost.failure), eur(d.b.cost.failure))
                Divider()
                row(m.t("cTotal"), eur(d.a.cost.total), eur(d.b.cost.total), bold: true,
                    aWin: !even && delta < 0, bWin: !even && delta > 0)
            }
            // frase finale: chi fa risparmiare e quanto (percentuale sul totale più caro)
            if even {
                Text(m.t("cmpEqual")).font(.system(size: 12.5))
            } else {
                let winner = delta > 0 ? d.b.printer : d.a.printer
                let pct = abs(delta) / max(d.a.cost.total, d.b.cost.total) * 100
                Text(String(format: m.t("cmpSaves"), winner, eur(abs(delta)), String(format: "%.0f", pct)))
                    .font(.system(size: 12.5))
            }
            if !d.bFailed.isEmpty {
                Label(String(format: m.t("cmpFailed"), d.b.printer,
                             d.bFailed.map(String.init).joined(separator: ", ")),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20).frame(width: 540)
        .preferredColorScheme(.dark)
    }
    @ViewBuilder func row(_ k: String, _ a: String, _ b: String,
                          bold: Bool = false, aWin: Bool = false, bWin: Bool = false) -> some View {
        GridRow {
            Text(k).foregroundStyle(.secondary).gridColumnAlignment(.leading)
            Text(a).fontWeight(bold ? .bold : .regular).foregroundStyle(aWin ? Color.green : Color.primary)
            Text(b).fontWeight(bold ? .bold : .regular).foregroundStyle(bWin ? Color.green : Color.primary)
        }
        .font(.system(size: 13)).monospacedDigit()
    }
}

// MARK: - Storico & registro costi (v1.3)

struct HistoryView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sHistory")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            HStack(spacing: 10) {
                Button("💾 \(m.t("histSaveProj"))") { m.logProject() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(m.loaded.isEmpty)
                Button("⇩ \(m.t("histExport"))") { exportCSV() }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(m.history.isEmpty)
                Spacer()
            }
            if m.history.isEmpty {
                GlassCard { Text(m.t("histEmpty")).foregroundStyle(.secondary).font(.system(size: 13)).padding(18).frame(maxWidth: .infinity) }
            } else {
                monthsCard
                entriesCard
            }
        }
    }

    /// totali per mese (chiave AAAA-MM, dal più recente)
    var months: [(key: String, n: Int, seconds: Double, grams: Double, total: Double)] {
        let keyFmt = DateFormatter(); keyFmt.dateFormat = "yyyy-MM"
        var acc: [String: (n: Int, seconds: Double, grams: Double, total: Double)] = [:]
        for e in m.history {
            let k = keyFmt.string(from: e.date)
            var v = acc[k] ?? (0, 0, 0, 0)
            v.n += 1; v.seconds += e.seconds; v.grams += e.grams; v.total += e.total
            acc[k] = v
        }
        return acc.map { (key: $0.key, n: $0.value.n, seconds: $0.value.seconds, grams: $0.value.grams, total: $0.value.total) }
            .sorted { $0.key > $1.key }
    }
    func monthLabel(_ key: String) -> String {
        let inFmt = DateFormatter(); inFmt.dateFormat = "yyyy-MM"
        let outFmt = DateFormatter(); outFmt.locale = Locale(identifier: m.lang.localeId); outFmt.dateFormat = "LLLL yyyy"
        guard let d = inFmt.date(from: key) else { return key }
        return outFmt.string(from: d).capitalized
    }
    func dayLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: m.lang.localeId)
        f.dateStyle = .short; f.timeStyle = .none
        return f.string(from: d)
    }

    var monthsCard: some View {
        GlassCard(pad: 6) {
            VStack(spacing: 0) {
                HStack {
                    Text(m.t("hMonth")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(m.t("hPrints")).frame(width: 70, alignment: .trailing)
                    Text(m.t("hHours")).frame(width: 80, alignment: .trailing)
                    Text("kg").frame(width: 80, alignment: .trailing)
                    Text(m.t("cTotal")).frame(width: 100, alignment: .trailing)
                }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                ForEach(months, id: \.key) { mo in
                    HStack {
                        Text(monthLabel(mo.key)).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(mo.n)").frame(width: 70, alignment: .trailing)
                        Text(String(format: "%.1f h", mo.seconds / 3600)).frame(width: 80, alignment: .trailing)
                        Text(String(format: "%.2f", mo.grams / 1000)).frame(width: 80, alignment: .trailing)
                        Text(eur(mo.total)).fontWeight(.semibold).foregroundStyle(.green).frame(width: 100, alignment: .trailing)
                    }.font(.system(size: 13)).monospacedDigit().padding(.horizontal, 10).padding(.vertical, 9)
                        .overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                }
            }
        }
    }

    var entriesCard: some View {
        GlassCard(pad: 6) {
            VStack(spacing: 0) {
                HStack {
                    Text(m.t("thDate")).frame(width: 82, alignment: .leading)
                    Text(m.t("thFile")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(m.t("pName")).frame(width: 140, alignment: .leading)
                    Text(m.t("thPlates")).frame(width: 50, alignment: .trailing)
                    Text(m.t("thTime")).frame(width: 70, alignment: .trailing)
                    Text(m.t("thGrams")).frame(width: 70, alignment: .trailing)
                    Text(m.t("cTotal")).frame(width: 90, alignment: .trailing)
                    Text("").frame(width: 24)
                }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                ForEach(m.history) { e in
                    HStack {
                        Text(dayLabel(e.date)).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
                        Text(e.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(e.printer).foregroundStyle(.secondary).lineLimit(1).frame(width: 140, alignment: .leading)
                        Text("\(e.plates)").frame(width: 50, alignment: .trailing)
                        Text(hms(e.seconds)).frame(width: 70, alignment: .trailing)
                        Text("\(Int(e.grams.rounded()))").frame(width: 70, alignment: .trailing)
                        Text(eur(e.total)).fontWeight(.semibold).frame(width: 90, alignment: .trailing)
                        Button { m.history.removeAll { $0.id == e.id } } label: {
                            Image(systemName: "xmark.circle.fill")
                        }.buttonStyle(.plain).foregroundStyle(.secondary).frame(width: 24)
                    }.font(.system(size: 13)).monospacedDigit().padding(.horizontal, 10).padding(.vertical, 9)
                        .overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                }
            }
        }
    }

    /// salvataggio CSV con NSSavePanel (BOM incluso: Excel riconosce l'UTF-8)
    func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "storico-stampe.csv"
        if let csvType = UTType(filenameExtension: "csv") { panel.allowedContentTypes = [csvType] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = "\u{FEFF}" + m.historyCSV()
        if (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil {
            m.flash("histExported")
        }
    }
}

// MARK: - Preventivo per clienti (v1.3)

/// decodifica il logo salvato come data URL ("data:image/png;base64,…")
func logoNSImage(_ s: String?) -> NSImage? {
    guard let s, s.hasPrefix("data:"), let comma = s.firstIndex(of: ","),
          let d = Data(base64Encoded: String(s[s.index(after: comma)...])) else { return nil }
    return NSImage(data: d)
}

struct QuoteView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sQuote")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            HStack(alignment: .top, spacing: 16) {
                form.frame(width: 320)
                if m.loaded.isEmpty {
                    GlassCard { Text(m.t("qEmpty")).foregroundStyle(.secondary).font(.system(size: 13)).padding(18).frame(maxWidth: .infinity) }
                } else {
                    // anteprima 1:1 del PDF accanto al modulo
                    QuotePaper(m: m)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.45), radius: 22, y: 9)
                }
            }
        }
    }

    var form: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.t("qLogo").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
                    HStack(spacing: 8) {
                        if let img = logoNSImage(m.quote.logo) {
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                                .frame(height: 30)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                            Button { m.quote.logo = nil } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).foregroundStyle(.secondary).help(m.t("qLogoDel"))
                        } else {
                            Button(m.t("qLogoPick")) { pickLogo() }.controlSize(.small)
                        }
                    }
                }
                field(m.t("qBiz"), $m.quote.biz)
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.t("qContact").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
                    TextEditor(text: $m.quote.contact)
                        .font(.system(size: 12.5)).frame(height: 48)
                        .scrollContentBackground(.hidden)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
                }
                field(m.t("qClient"), $m.quoteClient)
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.t("qMargin").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
                    Picker("", selection: $m.quote.mode) {
                        Text(m.t("qModePct")).tag("pct")
                        Text(m.t("qModeFlat")).tag("flat")
                    }.pickerStyle(.segmented).labelsHidden()
                    HStack(spacing: 6) {
                        if m.quote.mode == "flat" {
                            TextField("", value: $m.quote.flat, format: .number).frame(width: 80)
                            Text("€").foregroundStyle(.secondary)
                        } else {
                            TextField("", value: $m.quote.pct, format: .number).frame(width: 80)
                            Text("%").foregroundStyle(.secondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.t("qValidity").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
                    TextField("", value: $m.quote.validity, format: .number).frame(width: 80)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.t("qNotes").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
                    TextEditor(text: $m.quote.notes)
                        .font(.system(size: 12.5)).frame(height: 64)
                        .scrollContentBackground(.hidden)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
                }
                Toggle(m.t("qDetail"), isOn: $m.quote.detail).font(.system(size: 12))
                Button("🧾 \(m.t("qExport"))") { exportPDF() }
                    .buttonStyle(.borderedProminent)
                    .disabled(m.loaded.isEmpty)
            }
        }
    }

    @ViewBuilder func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }

    /// logo del preventivo: l'immagine diventa un data URL nello store,
    /// così il documento resta autonomo anche se il file originale sparisce
    func pickLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .webP]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        guard data.count <= 2 * 1024 * 1024 else { m.flash("qLogoBig"); return }
        let mime = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"][url.pathExtension.lowercased()] ?? "image/png"
        m.quote.logo = "data:\(mime);base64,\(data.base64EncodedString())"
    }

    /// PDF A4 dal medesimo QuotePaper dell'anteprima (ImageRenderer → CGContext PDF)
    @MainActor func exportPDF() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(m.t("qTitle").lowercased()).pdf"
        if let t = UTType(filenameExtension: "pdf") { panel.allowedContentTypes = [t] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let renderer = ImageRenderer(content: QuotePaper(m: m))
        renderer.proposedSize = ProposedViewSize(width: 595, height: nil)
        var done = false
        renderer.render { size, draw in
            var box = CGRect(x: 0, y: 0, width: 595, height: max(842, size.height))
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            ctx.translateBy(x: 0, y: box.height - size.height)   // contenuto in alto
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            done = true
        }
        if done { m.flash("qExported") }
    }
}

/// Il foglio del preventivo: carta bianca, stessa resa a schermo e nel PDF.
struct QuotePaper: View {
    let m: AppModel
    var body: some View {
        let ink = Color(red: 0.13, green: 0.14, blue: 0.17)
        let dim = Color(red: 0.42, green: 0.44, blue: 0.51)
        let n = m.quoteNumbers
        let q = m.quote
        let until = Date().addingTimeInterval(Double(max(1, q.validity)) * 86400)
        let names = m.loaded.map { $0.name.replacingOccurrences(of: ".3mf", with: "") }.joined(separator: ", ")

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                if let img = logoNSImage(q.logo) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        .frame(height: 52).frame(maxWidth: 150, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(q.biz.isEmpty ? m.t("qBizPlaceholder") : q.biz)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                    if !q.contact.isEmpty {
                        Text(q.contact).font(.system(size: 10)).foregroundStyle(dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Text(m.t("qTitle").uppercased()).font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundStyle(dim)
            }
            Rectangle().fill(ink).frame(height: 2).padding(.top, 14)
            Text("\(m.t("thDate")): \(dateStr(Date())) · \(String(format: m.t("qValidUntil"), dateStr(until)))\(m.quoteClient.isEmpty ? "" : " · \(m.t("qFor")): \(m.quoteClient)")")
                .font(.system(size: 10)).foregroundStyle(dim).padding(.vertical, 10)

            VStack(spacing: 0) {
                specRow(m.t("qProject"), names.isEmpty ? "—" : names, dim: dim)
                specRow(m.t("thPlates"), "\(m.totalPlates)", dim: dim)
                specRow(m.t("kTime"), hms(m.totalSeconds), dim: dim)
                specRow(m.t("kMat"), "\(Int(m.totalGrams)) g", dim: dim)
            }.padding(.bottom, 16)

            if q.detail {
                costLine(m.t("qProduction"), eur(n.cost))
                costLine(m.t("qMarginLine"), eur(n.margin))
            }
            Rectangle().fill(ink).frame(height: 2).padding(.top, 10)
            HStack(alignment: .firstTextBaseline) {
                Text(m.t("qTotal")).font(.system(size: 15, weight: .bold))
                Spacer()
                Text(eur(n.final)).font(.system(size: 22, weight: .bold)).monospacedDigit()
            }.padding(.top, 10)

            if !q.notes.isEmpty {
                Text(q.notes).font(.system(size: 10)).foregroundStyle(dim)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 18)
            }
            Text("COSTO STAMPA 3D").font(.system(size: 8, weight: .semibold)).tracking(1.5)
                .foregroundStyle(dim.opacity(0.55)).padding(.top, 24)
        }
        .padding(38)
        .frame(width: 595, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(ink)
        .environment(\.colorScheme, .light)
    }
    func dateStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: m.lang.localeId)
        f.dateStyle = .long; f.timeStyle = .none
        return f.string(from: d)
    }
    @ViewBuilder func specRow(_ k: String, _ v: String, dim: Color) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(dim).frame(width: 190, alignment: .leading)
            Text(v).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 11.5)).padding(.vertical, 6)
        .overlay(Rectangle().fill(Color(red: 0.9, green: 0.91, blue: 0.93)).frame(height: 1), alignment: .bottom)
    }
    @ViewBuilder func costLine(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
            Spacer()
            Text(v).fontWeight(.semibold).monospacedDigit()
        }.font(.system(size: 12)).padding(.vertical, 5)
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
                        Text(m.t("thUsed")).frame(width: 86, alignment: .trailing)
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
                            Text(eur(r.grams / 1000 * (m.material(forHex: r.hex, type: r.type)?.effectiveCostPerKg ?? m.fallbackCostPerKg)))
                                .foregroundStyle(.secondary).frame(width: 86, alignment: .trailing)
                            Text("\(r.spools)").frame(width: 70, alignment: .trailing)
                            Text(eur(m.unitPrice.price)).frame(width: 80, alignment: .trailing)
                            Text(eur(Double(r.spools)*m.unitPrice.price)).frame(width: 90, alignment: .trailing).fontWeight(.semibold)
                        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 9).overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                    }
                    if !m.colorRows.isEmpty {
                        HStack {
                            Text(m.t("total")).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(m.totalGrams))").fontWeight(.bold).frame(width: 80, alignment: .trailing)
                            Text(eur(m.cost.material)).fontWeight(.bold).frame(width: 86, alignment: .trailing)
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
                            Picker("", selection: $m.selPrinterID) {
                                ForEach(m.printersDB) { p in
                                    Text("\(p.name) · \(Int(p.watts)) W").tag(Optional(p.id))
                                }
                            }.labelsHidden()
                        }
                        Field(m.t("fKwh")) { TextField("", value: $m.kwh, format: .number).textFieldStyle(.roundedBorder) }
                        Field(m.t("fFailure")) {
                            HStack { Slider(value: $m.failurePct, in: 0...30, step: 1); Text("\(Int(m.failurePct)) %").frame(width: 44) }
                        }
                        Text(m.t("failureNote")).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        Divider().padding(.vertical, 2)
                        HStack(spacing: 12) {
                            Field(m.t("fCurrency")) {
                                Picker("", selection: $m.currency) {
                                    ForEach(Currency.allCases) { c in Text("\(c.symbol) \(c.code)").tag(c) }
                                }.labelsHidden().frame(width: 120)
                            }
                            Field(m.t("fRate")) {
                                HStack(spacing: 6) {
                                    TextField("", value: $m.eurRate, format: .number).textFieldStyle(.roundedBorder).frame(width: 90)
                                    Text(m.currency.symbol).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Text(m.t("currencyNote")).font(.system(size: 11)).foregroundStyle(.secondary)
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

struct UpdateBar: View {
    @EnvironmentObject var m: AppModel
    let tag: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue)
            Text(String(format: m.t("updateAvail"), tag)).font(.system(size: 13, weight: .medium))
            Button(m.t("updateGet")) {
                if let u = URL(string: "https://github.com/emanueletech/3d-print-cost/releases/latest") { NSWorkspace.shared.open(u) }
            }
                .buttonStyle(.borderedProminent).controlSize(.small)
            Button { m.updateTag = nil } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Capsule().fill(.regularMaterial)).overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
    }
}

struct NoticeBar: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.system(size: 13))
        }
        .padding(.horizontal, 20).padding(.vertical, 11)
        .background(Capsule().fill(.regularMaterial)).overlay(Capsule().strokeBorder(.orange.opacity(0.4)))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
        .padding(.bottom, 26)
        .frame(maxWidth: 640)
    }
}

// MARK: - Materiali (database editabile)

struct MaterialsView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sMaterials")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            // colori davvero usati nei file caricati: sotto mano, sopra il database
            if !m.colorRows.isEmpty {
                GlassCard(pad: 12) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(m.t("usedColors"), systemImage: "paintpalette.fill")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(m.colorRows) { r in
                                    let mat = m.material(forHex: r.hex, type: r.type)
                                    HStack(spacing: 7) {
                                        Circle().fill(Color(hex: r.hex)).frame(width: 11, height: 11)
                                            .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                                        Text("\(r.type) \(r.name)").font(.system(size: 12, weight: .medium))
                                        Text(gramsLabel(r.grams)).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                                        Text((mat != nil ? eur(mat!.effectiveCostPerKg) : "≈ " + eur(m.fallbackCostPerKg)) + "/kg")
                                            .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                                            .foregroundStyle(mat != nil ? Color.green : Color.orange)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(.white.opacity(0.06)))
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                                }
                            }
                        }
                    }
                }
            }
            HStack {
                Menu {
                    Button(m.t("blankMaterial")) { m.materials.insert(Material(name: "Nuovo", type: "PLA Basic", colorHex: "#8E9089", costPerKg: 22.99, densityGcm3: 1.24), at: 0) }
                    Divider()
                    ForEach(Store.presetBrandOrder, id: \.self) { brand in
                        Menu(brand) {
                            ForEach(Store.presetTypes(brand), id: \.self) { type in
                                Menu(type) {
                                    ForEach(Store.presetItems(brand, type)) { p in
                                        Button("\(p.colorName)  ·  \(String(format: "%.2f", p.costPerKg)) €/kg") { m.materials.insert(p.make(), at: 0) }
                                    }
                                }
                            }
                        }
                    }
                } label: { Label(m.t("addMaterial"), systemImage: "plus") }
                    .menuStyle(.borderedButton).controlSize(.small).fixedSize()
                Button { m.materials = Store.defaultMaterials() } label: { Label(m.t("resetDefaults"), systemImage: "arrow.counterclockwise") }.buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Menu {
                    Button("Bambu Lab Store") { openURL("https://eu.store.bambulab.com/collections/pla") }
                    Button("eSun · Amazon") { openURL(m.amazonURL("eSun PLA PETG filamento 1kg")) }
                    Button("Amazon · filamenti") { openURL(m.amazonURL("filamento stampa 3d 1kg")) }
                } label: { Label(m.t("checkOffers"), systemImage: "tag") }
                    .menuStyle(.borderedButton).controlSize(.small).fixedSize()
            }
            GlassCard(pad: 6) {
                VStack(spacing: 0) {
                    HStack {
                        Text(m.t("mColor")).frame(width: 40, alignment: .leading)
                        Text(m.t("mName")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(m.t("mType")).frame(width: 96, alignment: .leading)
                        Text(m.t("mCost")).frame(width: 66, alignment: .trailing)
                        Text(m.t("mSale")).frame(width: 84, alignment: .trailing)
                        Text(m.t("mDensity")).frame(width: 86, alignment: .trailing)
                        Text(m.t("mStock")).frame(width: 58, alignment: .trailing)
                        Text("").frame(width: 26)
                    }.font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.4).padding(.horizontal, 10).padding(.vertical, 9)
                    ForEach($m.materials) { $mat in
                        HStack {
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: mat.colorHex) },
                                set: { mat.colorHex = $0.hex6 }), supportsOpacity: false).labelsHidden().frame(width: 40, alignment: .leading)
                            TextField("", text: $mat.name).textFieldStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                            TextField("", text: $mat.type).textFieldStyle(.plain).frame(width: 96, alignment: .leading)
                            TextField("", value: $mat.costPerKg, format: .number).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 66)
                            // offerta €/kg + badge
                            HStack(spacing: 4) {
                                if mat.onSale { Text(m.t("onSaleBadge")).font(.system(size: 8, weight: .bold)).foregroundStyle(.green).padding(.horizontal, 4).padding(.vertical, 1).background(Capsule().fill(.green.opacity(0.16))) }
                                TextField("—", value: Binding(get: { mat.salePrice ?? 0 }, set: { mat.salePrice = $0 > 0 ? $0 : nil }), format: .number)
                                    .textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 48)
                                    .foregroundStyle(mat.onSale ? .green : .primary)
                            }.frame(width: 84, alignment: .trailing)
                            TextField("", value: $mat.densityGcm3, format: .number).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 86)
                            TextField("", value: Binding(get: { mat.stockKg ?? 0 }, set: { mat.stockKg = $0 }), format: .number).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 58)
                            Button { openURL(m.amazonURL("\(mat.type) \(mat.name) filamento 1kg")) } label: { Image(systemName: "cart") }
                                .buttonStyle(.plain).foregroundStyle(.orange).frame(width: 24).help(m.t("amazonSearch"))
                            Button { m.materials.removeAll { $0.id == mat.id } } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary).frame(width: 26)
                        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 6).overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                    }
                }
            }
            Text(m.t("offersNote")).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 10)).foregroundStyle(.tertiary)
                Text(m.t("affiliate")).font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
        }
    }
    func openURL(_ s: String) { if let u = URL(string: s) { NSWorkspace.shared.open(u) } }
}

// MARK: - Stampanti (database editabile)

struct PrintersView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sPrinters")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            HStack {
                Button { m.printersDB.insert(PrinterProfile(name: "Nuova", watts: 120, wearPerHour: 0.08, setupCost: 0.15), at: 0) } label: {
                    Label(m.t("addPrinter"), systemImage: "plus")
                }.buttonStyle(.borderedProminent).controlSize(.small)
                Button { m.printersDB = Store.defaultPrinters(); m.selPrinterID = m.printersDB.first?.id } label: { Label(m.t("resetDefaults"), systemImage: "arrow.counterclockwise") }.buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Text(m.t("wearHint")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            GlassCard(pad: 6) {
                VStack(spacing: 0) {
                    HStack {
                        Text("").frame(width: 30)
                        Text(m.t("pName")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(m.t("pSlicer")).frame(width: 190, alignment: .leading)
                        Text(m.t("pWatts")).frame(width: 80, alignment: .trailing)
                        Text(m.t("pWear")).frame(width: 90, alignment: .trailing)
                        Text(m.t("pSetup")).frame(width: 80, alignment: .trailing)
                        Text("").frame(width: 30)
                    }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.6).padding(.horizontal, 10).padding(.vertical, 9)
                    ForEach($m.printersDB) { $p in
                        HStack {
                            Button { m.selPrinterID = p.id } label: {
                                Image(systemName: m.selPrinterID == p.id ? "largecircle.fill.circle" : "circle").foregroundStyle(m.selPrinterID == p.id ? Color.accentColor : .secondary)
                            }.buttonStyle(.plain).frame(width: 30).help(m.t("selected"))
                            TextField("", text: $p.name).textFieldStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                            // badge slicer (v1.2): con chi slica questa stampante
                            Group {
                                if let spec = p.slicing {
                                    Text(spec.engine == "bambu" ? m.slicerAppName(spec.engine)
                                         : "\(m.slicerAppName(spec.engine)) · \(m.t("expOnly"))")
                                } else {
                                    Text("—")
                                }
                            }
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .lineLimit(1).frame(width: 190, alignment: .leading)
                            TextField("", value: $p.watts, format: .number).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 80)
                            TextField("", value: $p.wearPerHour, format: .number).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 90)
                            TextField("", value: $p.setupCost, format: .number).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 80)
                            Button { m.printersDB.removeAll { $0.id == p.id } } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary).frame(width: 30)
                        }.font(.system(size: 13)).padding(.horizontal, 10).padding(.vertical, 6).overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                    }
                }
            }
        }
    }
}

extension Color {
    // hex a 6 cifre da un Color (per ColorPicker → storage)
    var hex6: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(format: "#%02X%02X%02X", Int(ns.redComponent*255), Int(ns.greenComponent*255), Int(ns.blueComponent*255))
    }
}

// MARK: - Orienta 3D (STL/STEP/OBJ)

struct OrientView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sOrient")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
            HStack {
                Button { pick() } label: { Label(m.t("loadModel"), systemImage: "arrow.down.doc") }
                    .buttonStyle(.borderedProminent).controlSize(.regular)
                if m.meshName != nil {
                    Text(m.meshName!).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let mesh = m.mesh {
                HStack(alignment: .top, spacing: 14) {
                    GlassCard(pad: 4) {
                        MeshSceneView(mesh: mesh, supportThreshold: m.supportThreshold)
                            .frame(height: 340).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 12) {
                        // soglia
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(m.t("threshold").uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.8)
                                HStack { Slider(value: $m.supportThreshold, in: 20...70, step: 5); Text("\(Int(m.supportThreshold))°").frame(width: 40) }
                                Text(m.t("orientHint")).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        // pose
                        GlassCard(pad: 6) {
                            VStack(spacing: 0) {
                                HStack {
                                    Text(m.t("poseName")).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(m.t("poseHeight")).frame(width: 56, alignment: .trailing)
                                    Text(m.t("poseSupport")).frame(width: 74, alignment: .trailing)
                                }.font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary).tracking(0.6).padding(.horizontal, 8).padding(.vertical, 7)
                                ForEach(Array(m.poses.enumerated()), id: \.offset) { idx, p in
                                    Button { m.applyPose(p) } label: {
                                        HStack {
                                            HStack(spacing: 6) {
                                                if idx == 0 { Text(m.t("poseBest")).font(.system(size: 9, weight: .bold)).foregroundStyle(.green).padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(.green.opacity(0.16))) }
                                                Text(p.name).font(.system(size: 12.5, weight: m.chosenPose == p.name ? .bold : .regular))
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                            Text(String(format: "%.0f", p.height)).font(.system(size: 12)).frame(width: 56, alignment: .trailing)
                                            Text(String(format: "%.0f mm²", p.supportArea)).font(.system(size: 12)).foregroundStyle(p.supportArea < 1 ? .green : .primary).frame(width: 74, alignment: .trailing)
                                        }.padding(.horizontal, 8).padding(.vertical, 7)
                                        .background(m.chosenPose == p.name ? Color.accentColor.opacity(0.14) : .clear)
                                    }.buttonStyle(.plain).overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 1), alignment: .top)
                                }
                            }
                        }
                        Button { m.sliceOriented() } label: {
                            Label(m.t("sliceOriented"), systemImage: "square.and.arrow.down.on.square").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                    }.frame(width: 320)
                }
            } else {
                GlassCard { Text(m.t("noModel")).foregroundStyle(.secondary).font(.system(size: 13)).padding(30).frame(maxWidth: .infinity) }
            }
        }
    }
    func pick() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [UTType(filenameExtension: "stl"), UTType(filenameExtension: "obj"),
                                 UTType(filenameExtension: "step"), UTType(filenameExtension: "stp")].compactMap { $0 }
        p.allowsMultipleSelection = false; p.canChooseFiles = true
        if p.runModal() == .OK, let u = p.urls.first { m.loadMesh(u.path) }
    }
}
