//
//  MixedRealityViewController.swift
//  MRTest2
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import ARKit
import SwiftSocket

final class MixedRealityViewController: UIViewController {
    private let client: TCPClient
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var sceneView: ARSCNView!

    private var backgroundNode: SCNNode?

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    init(client: TCPClient) {
        self.client = client
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
        self.oculusMRC = OculusMRC()
        oculusMRC?.delegate = self

        let scene = SCNScene()
//        sceneView.delegate = self
        sceneView.scene = scene
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        } else {
            // TODO: Display Alert
            fatalError("Person Segmentation not available")
        }

        sceneView.session.run(configuration)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateScenePlane()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        updateScenePlane()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    private func updateScenePlane() {
//        let depth: Float = 0.9
//
//        let width = Float(sceneView.frame.width)
//        let height = sceneView.frame.height
//
//        var origin = sceneView.unprojectPoint(SCNVector3(0, 0, depth))
//        let topRight = sceneView.unprojectPoint(SCNVector3(width, 0, depth))
//        let scale = 2.0 * (topRight.x - origin.x) / width
//
//        origin.z *= -1
//        origin.x = -2 * topRight.x
//        origin.y = -2 * topRight.y

//        let plane = SCNPlane(width: CGFloat(width), height: height)
        let plane = SCNPlane(width: 0.5, height: 0.5)

        plane.cornerRadius = 0
        plane.firstMaterial?.lightingModel = .constant
        plane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 1)

        let planeNode = SCNNode(geometry: plane)

        planeNode.position = .init(0, 0, -1) //origin
//        planeNode.scale = SCNVector3(scale, -scale, scale)

        // Flipping image
        planeNode.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

        sceneView.pointOfView?.childNodes.forEach({ $0.removeFromParentNode() })
        sceneView.pointOfView?.addChildNode(planeNode)

        self.backgroundNode = planeNode
    }

    @objc func update(with sender: CADisplayLink) {
        guard let oculusMRC = oculusMRC,
            let data = client.read(65536, timeout: 0),
            data.count > 0
        else {
            return
        }

        oculusMRC.addData(data, length: Int32(data.count))
        oculusMRC.update()
    }
}

extension MixedRealityViewController: OculusMRCDelegate {

    func oculusMRC(_ oculusMRC: OculusMRC, didReceiveNewFrame frame: UIImage) {
        backgroundNode?.geometry?.firstMaterial?.diffuse.contents = frame
    }
}
