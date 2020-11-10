import UIKit
import SceneKit
import PlaygroundSupport

let size = CGSize(width: 2048, height: 2048)

let floor = SCNPlane(width: 250, height: 250)
floor.firstMaterial?.diffuse.contents = UIImage(named: "grid")!
floor.firstMaterial?.lightingModel = .phong
floor.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(15, 15, 0)
floor.firstMaterial?.diffuse.wrapS = .repeat
floor.firstMaterial?.diffuse.wrapT = .repeat
floor.firstMaterial?.shaderModifiers = [
    .surface: """
    vec4 color = texture2D(u_diffuseTexture, _surface.diffuseTexcoord);
    _surface.diffuse = vec4(1.0 - color.r, 1.0 - color.g, 1.0 - color.b, 1.0);
    """
]

let floorNode = SCNNode()
floor.firstMaterial?.diffuse.maxAnisotropy = .greatestFiniteMagnitude
floorNode.position = .init(0, 0, 0)
floorNode.eulerAngles.x = -.pi/2.0
floorNode.geometry = floor

let camera = SCNCamera()
camera.wantsHDR = true
camera.bloomIntensity = 5.0

let cameraNode = SCNNode()
cameraNode.position = .init(0, 10, 25)
cameraNode.look(at: .init(0, 10, 0))
cameraNode.camera = camera

let scene = SCNScene()
scene.rootNode.addChildNode(floorNode)
scene.rootNode.addChildNode(cameraNode)

scene.fogStartDistance = 10
scene.fogEndDistance = 50
scene.fogDensityExponent = 2.0
scene.fogColor = UIColor.black

let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
renderer.scene = scene

let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: SCNAntialiasingMode.multisampling4X)

let imageData = image.pngData()
let url = playgroundSharedDataDirectory.appendingPathComponent("background@3x.png")
try? imageData?.write(to: url, options: .atomicWrite)

print("Path: \(url)")

