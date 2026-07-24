import SwiftUI
import SceneKit
import simd

// Vista 3D del modello orientato, appoggiato su un piatto con griglia.
struct MeshSceneView: NSViewRepresentable {
    let mesh: Mesh
    let supportThreshold: Double

    func makeNSView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = true
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        return v
    }

    func updateNSView(_ v: SCNView, context: Context) {
        v.scene = buildScene()
    }

    func buildScene() -> SCNScene {
        let scene = SCNScene()
        let b = mesh.bounds
        let dx: Float = b.max.x - b.min.x
        let dy: Float = b.max.y - b.min.y
        let h: Float = b.max.z - b.min.z
        let sizeXY: Float = Swift.max(dx, dy, Float(1))

        // modello
        scene.rootNode.addChildNode(SCNNode(geometry: geometry(from: mesh)))

        // piatto con griglia
        let bed: Float = Swift.max(sizeXY * Float(1.6), Float(40))
        let plane = SCNPlane(width: CGFloat(bed), height: CGFloat(bed))
        let pm = SCNMaterial()
        pm.diffuse.contents = NSColor(calibratedWhite: 0.5, alpha: 0.12)
        pm.isDoubleSided = true
        plane.materials = [pm]
        let pnode = SCNNode(geometry: plane)
        pnode.eulerAngles.x = -.pi/2
        scene.rootNode.addChildNode(pnode)

        let grid = SCNNode()
        let half: Float = bed / 2
        let step: Float = bed / 10
        for i in 0...10 {
            let off: Float = -half + Float(i) * step
            grid.addChildNode(lineNode(from: SIMD3<Float>(off, 0.01, -half), to: SIMD3<Float>(off, 0.01, half)))
            grid.addChildNode(lineNode(from: SIMD3<Float>(-half, 0.01, off), to: SIMD3<Float>(half, 0.01, off)))
        }
        scene.rootNode.addChildNode(grid)

        // camera
        let cam = SCNNode(); cam.camera = SCNCamera()
        let d: Double = Double(Swift.max(sizeXY, h)) * 2.2 + 30
        let camY: Double = Double(h) * 0.6 + d * 0.5
        cam.position = SCNVector3(d * 0.8, camY, d)
        cam.look(at: SCNVector3(0, Double(h) / 2, 0))
        scene.rootNode.addChildNode(cam)
        return scene
    }

    // costruisce SCNGeometry colorando in rosso le facce in sbalzo (che serviranno supporti)
    func geometry(from m: Mesh) -> SCNGeometry {
        let mm = m   // già onBed
        var positions: [SCNVector3] = []; positions.reserveCapacity(mm.verts.count)
        var normals: [SCNVector3] = []; normals.reserveCapacity(mm.verts.count)
        var colors: [SIMD4<Float>] = []; colors.reserveCapacity(mm.verts.count)
        let cutoff = Float(cos(supportThreshold * .pi / 180))
        let bodyColor = SIMD4<Float>(0.62, 0.68, 0.85, 1)     // azzurrino
        let supColor  = SIMD4<Float>(0.95, 0.35, 0.32, 1)     // rosso sbalzo
        for i in 0..<mm.count {
            let n = mm.normal(i); let (a,b,c) = mm.tri(i)
            let zmin = Swift.min(a.z, b.z, c.z)
            let isSup = n.z < 0 && (-n.z) > cutoff && zmin > 0.4
            let col = isSup ? supColor : bodyColor
            for v in [a,b,c] { positions.append(SCNVector3(v.x, v.z, -v.y)) }  // Z-up → Y-up per SceneKit
            let sn = SCNVector3(n.x, n.z, -n.y)
            for _ in 0..<3 { normals.append(sn); colors.append(col) }
        }
        let vSrc = SCNGeometrySource(vertices: positions)
        let nSrc = SCNGeometrySource(normals: normals)
        let cData = Data(bytes: colors, count: colors.count * MemoryLayout<SIMD4<Float>>.stride)
        let cSrc = SCNGeometrySource(data: cData, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride)
        let idx = (0..<UInt32(positions.count)).map { $0 }
        let elem = SCNGeometryElement(indices: idx, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [vSrc, nSrc, cSrc], elements: [elem])
        let mat = SCNMaterial(); mat.lightingModel = .physicallyBased; mat.roughness.contents = 0.7; mat.isDoubleSided = true
        geo.materials = [mat]
        return geo
    }

    func lineNode(from: SIMD3<Float>, to: SIMD3<Float>) -> SCNNode {
        let src = SCNGeometrySource(vertices: [SCNVector3(from.x, from.y, from.z), SCNVector3(to.x, to.y, to.z)])
        let elem = SCNGeometryElement(indices: [UInt32(0), UInt32(1)], primitiveType: .line)
        let geo = SCNGeometry(sources: [src], elements: [elem])
        let mat = SCNMaterial(); mat.diffuse.contents = NSColor(calibratedWhite: 0.6, alpha: 0.25); mat.lightingModel = .constant
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }
}
