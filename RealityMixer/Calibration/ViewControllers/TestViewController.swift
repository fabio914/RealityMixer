//
//  TestViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/28/20.
//

import UIKit
import SceneKit
import SceneKit.ModelIO

class TestViewController: UIViewController {

    @IBOutlet private weak var sceneView: SCNView!

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func model(named name: String) -> SCNNode? {
        Bundle.main.url(forResource: name, withExtension: "stl")
            .flatMap(MDLAsset.init(url:))
            .flatMap({ asset -> MDLMesh? in
                guard asset.count > 0 else { return nil }
                return asset.object(at: 0) as? MDLMesh
            })
            .flatMap({ SCNNode(mdlObject: $0) })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let scene = SCNScene()

        let leftController: SCNNode! = model(named: "left")
        leftController.geometry?.firstMaterial?.lightingModel = .constant
        leftController.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        leftController.position = SCNVector3(-0.004, 0.027, 0.04)
//        leftController.position = SCNVector3(0.004, 0.027, 0.04)

        let rotatedLeftController = SCNNode()
        rotatedLeftController.addChildNode(leftController)
        rotatedLeftController.rotation = SCNVector4(1, 0, 0, 45.0 * .pi/180.0)

        let leftControllerNode = SCNNode()
        leftControllerNode.addChildNode(rotatedLeftController)
        leftControllerNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(leftControllerNode)

        let origin = SCNSphere(radius: 0.01)
        origin.firstMaterial?.lightingModel = .constant
        origin.firstMaterial?.diffuse.contents = UIColor.green
        let originNode = SCNNode()
        originNode.geometry = origin
        scene.rootNode.addChildNode(originNode)

        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 10.0
        let cameraNode = SCNNode()
        cameraNode.position = SCNVector3(0, 0, 0.5)
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        sceneView.scene = scene
        sceneView.debugOptions = .showWireframe
        sceneView.allowsCameraControl = true
    }
}
