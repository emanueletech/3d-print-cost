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
            if !m.unlocked { GateView() }        // schermata di sblocco all'avvio
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
            navGroup(m.t("grpProject"), [.overview, .files, .orient, .colors, .plates])
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

struct StatRow: Identifiable { let id = UUID(); let hex: String; let name: String; let value: String }

/// Grammi esatti: sotto il chilo in g, sopra in kg con precisione al grammo.
func gramsLabel(_ g: Double) -> String {
    g < 1000 ? String(format: "%.0f g", g) : String(format: "%.3f kg", g / 1000)
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
            Text(m.t("sFiles")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
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
}

struct FileCard: View {
    @EnvironmentObject var m: AppModel
    @ObservedObject var f: LoadedFile
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
                    } else {
                        if case .error(let e) = f.state {
                            Label(m.t(e == "noBambu" ? "noBambuShort" : "sliceFailed"), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.orange)
                                .lineLimit(2).frame(maxWidth: 300, alignment: .trailing)
                        }
                        Button(m.t("slice")) { m.slice(f) }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                    Button { m.remove(f) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
                // striscia anteprime piatti — cliccabili per includere/escludere
                if !f.thumbs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(f.thumbs.enumerated()), id: \.offset) { i, img in
                                let on = !f.excluded.contains(i+1)
                                Button { m.togglePlate(f, i+1) } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                            .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 9))
                                            .background(RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.15)))
                                            .saturation(on ? 1 : 0).opacity(on ? 1 : 0.4)
                                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(on ? Color.accentColor.opacity(0.9) : .white.opacity(0.12), lineWidth: on ? 2 : 1))
                                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14)).foregroundStyle(on ? Color.accentColor : .white.opacity(0.7))
                                            .background(Circle().fill(.black.opacity(0.4))).padding(3)
                                        Text("\(i+1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(Capsule().fill(.black.opacity(0.55)))
                                            .padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    }.frame(width: 64, height: 64)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.top, 1)
                    }
                    Text(m.t("plateHint")).font(.system(size: 11)).foregroundStyle(.secondary)
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

// MARK: - Materiali (database editabile)

struct MaterialsView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(m.t("sMaterials")).foregroundStyle(.secondary).font(.system(size: 13)).padding(.top, 6)
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
