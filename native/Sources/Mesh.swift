import Foundation
import simd

// MARK: - Mesh (STL/OBJ) + geometria per l'analisi di orientamento

struct Mesh {
    var verts: [SIMD3<Float>]          // vertici dei triangoli, a gruppi di 3
    var count: Int { verts.count / 3 }

    // triangolo i → (a,b,c)
    func tri(_ i: Int) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        (verts[i*3], verts[i*3+1], verts[i*3+2])
    }
    func normal(_ i: Int) -> SIMD3<Float> {
        let (a,b,c) = tri(i)
        let n = cross(b-a, c-a)
        let l = length(n)
        return l > 0 ? n / l : SIMD3<Float>(0,0,1)
    }
    func area(_ i: Int) -> Float {
        let (a,b,c) = tri(i)
        return length(cross(b-a, c-a)) * 0.5
    }

    var bounds: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let f = verts.first else { return (.zero, .zero) }
        var lo = f, hi = f
        for v in verts { lo = min(lo, v); hi = max(hi, v) }
        return (lo, hi)
    }

    // applica una rotazione (matrice) a tutti i vertici
    func rotated(_ r: simd_float3x3) -> Mesh { Mesh(verts: verts.map { r * $0 }) }

    // ricentra sul piano: appoggia il minimo Z a 0 e centra X/Y
    func onBed() -> Mesh {
        let b = bounds
        let off = SIMD3<Float>((b.min.x+b.max.x)/2, (b.min.y+b.max.y)/2, b.min.z)
        return Mesh(verts: verts.map { $0 - off })
    }

    // esporta come STL binario (per rislicare la posa scelta)
    func exportSTLbinary(to path: String) -> Bool {
        var data = Data(count: 80)                     // header
        var n = UInt32(count); withUnsafeBytes(of: &n) { data.append(contentsOf: $0) }
        for i in 0..<count {
            let nrm = normal(i); let (a,b,c) = tri(i)
            for v in [nrm, a, b, c] {
                for f in [v.x, v.y, v.z] { var x = f; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            }
            var attr: UInt16 = 0; withUnsafeBytes(of: &attr) { data.append(contentsOf: $0) }
        }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }
}

// MARK: - Analisi di una posa (orientamento)

struct PoseStats {
    var name: String
    var rot: simd_float3x3
    var height: Float          // mm sull'asse Z
    var footprintX: Float
    var footprintY: Float
    var supportArea: Float     // mm² di superficie in sbalzo da supportare
    var contactArea: Float     // mm² a contatto col piatto (stabilità)
    var footprint: Float { footprintX * footprintY }
}

enum Orient {
    // soglia: una faccia rivolta in basso serve supporto se l'angolo tra la sua normale
    // e la direzione verticale-giù è < thresholdDeg (default 45° → superfici molto orizzontali).
    static func stats(_ mesh: Mesh, name: String, rot: simd_float3x3, thresholdDeg: Float = 45) -> PoseStats {
        let m = mesh.rotated(rot).onBed()
        let b = m.bounds
        let cutoff = cos(thresholdDeg * .pi / 180)   // n·down > cutoff → supporto
        let bedEps: Float = 0.4
        var support: Float = 0, contact: Float = 0
        for i in 0..<m.count {
            let n = m.normal(i)
            let a = m.area(i)
            let (p0,p1,p2) = m.tri(i)
            let zmin = Swift.min(p0.z, p1.z, p2.z)
            let zmax = Swift.max(p0.z, p1.z, p2.z)
            // faccia sul piatto (bassa e rivolta in giù) = contatto, non supporto
            if zmax < bedEps && n.z < -0.7 { contact += a; continue }
            // faccia rivolta in giù e troppo orizzontale, sopra il piatto → supporto
            if n.z < 0 && (-n.z) > cutoff && zmin > bedEps { support += a }
        }
        return PoseStats(name: name, rot: rot,
                         height: b.max.z - b.min.z,
                         footprintX: b.max.x - b.min.x, footprintY: b.max.y - b.min.y,
                         supportArea: support, contactArea: contact)
    }

    // pose candidate: identità + i 6 assi verso il basso
    static func candidates(_ mesh: Mesh, thresholdDeg: Float = 45) -> [PoseStats] {
        func rotToDown(_ axis: SIMD3<Float>) -> simd_float3x3 {
            // ruota così che 'axis' del modello punti in -Z
            let down = SIMD3<Float>(0,0,-1)
            let a = normalize(axis)
            let d = dot(a, down)
            if d > 0.9999 { return matrix_identity_float3x3 }
            if d < -0.9999 { return simd_float3x3(SIMD3(1,0,0), SIMD3(0,-1,0), SIMD3(0,0,-1)) }
            let v = cross(a, down); let s = length(v); let c = d
            let vx = simd_float3x3(SIMD3(0, v.z, -v.y), SIMD3(-v.z, 0, v.x), SIMD3(v.y, -v.x, 0))
            return matrix_identity_float3x3 + vx + vx*vx*((1-c)/(s*s))
        }
        var out: [PoseStats] = [stats(mesh, name: "Originale", rot: matrix_identity_float3x3, thresholdDeg: thresholdDeg)]
        let axes: [(String, SIMD3<Float>)] = [
            ("+X giù", SIMD3(1,0,0)), ("−X giù", SIMD3(-1,0,0)),
            ("+Y giù", SIMD3(0,1,0)), ("−Y giù", SIMD3(0,-1,0)),
            ("Testa giù", SIMD3(0,0,1)), ("Base giù", SIMD3(0,0,-1)),
        ]
        for (n, ax) in axes { out.append(stats(mesh, name: n, rot: rotToDown(ax), thresholdDeg: thresholdDeg)) }
        return out
    }
}

// MARK: - Loader

enum MeshLoader {
    static func load(_ path: String) -> Mesh? {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "stl": return loadSTL(path)
        case "obj": return loadOBJ(path)
        default: return nil
        }
    }

    static func loadSTL(_ path: String) -> Mesh? {
        guard let data = FileManager.default.contents(atPath: path), data.count > 84 else { return nil }
        // ASCII se inizia con "solid" e contiene "facet"
        let head = String(data: data.prefix(256), encoding: .ascii) ?? ""
        if head.hasPrefix("solid"), let full = String(data: data, encoding: .ascii), full.contains("facet") {
            return loadSTLascii(full)
        }
        return loadSTLbinary(data)
    }

    static func loadSTLbinary(_ data: Data) -> Mesh? {
        return data.withUnsafeBytes { raw -> Mesh? in
            let base = raw.baseAddress!
            let n = raw.loadUnaligned(fromByteOffset: 80, as: UInt32.self)
            var off = 84
            var verts: [SIMD3<Float>] = []; verts.reserveCapacity(Int(n)*3)
            for _ in 0..<Int(n) {
                guard off + 50 <= data.count else { break }
                func f(_ o: Int) -> Float { raw.loadUnaligned(fromByteOffset: o, as: Float32.self) }
                // salta normale (12 byte), leggi 3 vertici (9 float)
                for k in 0..<3 {
                    let vo = off + 12 + k*12
                    verts.append(SIMD3<Float>(f(vo), f(vo+4), f(vo+8)))
                }
                off += 50
            }
            _ = base
            return verts.isEmpty ? nil : Mesh(verts: verts)
        }
    }

    static func loadSTLascii(_ s: String) -> Mesh? {
        var verts: [SIMD3<Float>] = []
        s.enumerateLines { line, _ in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("vertex") {
                let c = t.split(separator: " ").compactMap { Float($0) }
                if c.count >= 3 { verts.append(SIMD3(c[0], c[1], c[2])) }
            }
        }
        return verts.count >= 3 ? Mesh(verts: verts) : nil
    }

    static func loadOBJ(_ path: String) -> Mesh? {
        guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var pts: [SIMD3<Float>] = []
        var verts: [SIMD3<Float>] = []
        s.enumerateLines { line, _ in
            if line.hasPrefix("v ") {
                let c = line.dropFirst(2).split(separator: " ").compactMap { Float($0) }
                if c.count >= 3 { pts.append(SIMD3(c[0], c[1], c[2])) }
            } else if line.hasPrefix("f ") {
                let idx = line.dropFirst(2).split(separator: " ").compactMap { tok -> Int? in
                    guard let first = tok.split(separator: "/").first, let i = Int(first) else { return nil }
                    return i > 0 ? i - 1 : pts.count + i
                }
                // fan triangulation
                if idx.count >= 3 {
                    for k in 1..<(idx.count-1) {
                        for j in [0, k, k+1] where idx[j] >= 0 && idx[j] < pts.count { verts.append(pts[idx[j]]) }
                    }
                }
            }
        }
        return verts.count >= 3 ? Mesh(verts: verts) : nil
    }
}
