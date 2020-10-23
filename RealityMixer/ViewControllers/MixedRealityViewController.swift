//
//  MixedRealityViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import ARKit
import SwiftSocket

final class MixedRealityViewController: UIViewController {
    private let client: TCPClient
    private let shouldShowDebug: Bool
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var debugView: UIImageView!
    @IBOutlet private weak var sceneView: SCNView!

    private var session: ARSession?
    private var scene: SCNScene?
    private var matteGenerator: ARMatteGenerator?

    private var backgroundNode: SCNNode?
    private var personNode: SCNNode?
    private var foregroundNode: SCNNode?

    var first = true
    var firstFrame = true

    private let flipTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    init(client: TCPClient, shouldShowDebug: Bool) {
        self.client = client
        self.shouldShowDebug = shouldShowDebug
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDisplay()
        configureDisplayLink()
        configureOculusMRC()
        configureDebugView()
    }

    private func configureDisplay() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func configureDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
    }

    private func configureOculusMRC() {
        self.oculusMRC = OculusMRC()
        oculusMRC?.delegate = self
    }

    private func configureDebugView() {
        debugView.isHidden = !shouldShowDebug
    }

    private func configureScene() {
        let width = Double(sceneView.frame.size.width)
        let scene = SCNScene()

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = width/4.0

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = .init(0, 0, 1)
        scene.rootNode.addChildNode(cameraNode)

        self.scene = scene
        sceneView.scene = scene
    }

    private func configureBackground() {
        let imageSize = sceneView.frame.size // 16:9

        let backgroundPlane = SCNPlane(width: imageSize.width, height: imageSize.height)
        backgroundPlane.cornerRadius = 0
        backgroundPlane.firstMaterial?.lightingModel = .constant
        backgroundPlane.firstMaterial?.diffuse.contents = UIColor.green

        let backgroundPlaneNode = SCNNode(geometry: backgroundPlane)
        backgroundPlaneNode.position = .init(0, 0, -10)

        // Flipping image
        backgroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform

        scene?.rootNode.addChildNode(backgroundPlaneNode)
        self.backgroundNode = backgroundPlaneNode
    }

    private func configurePerson(with frame: ARFrame) {
        let imageSize = frame.camera.imageResolution

        let personPlane = SCNPlane(width: imageSize.width, height: imageSize.height)
        personPlane.cornerRadius = 0
        personPlane.firstMaterial?.lightingModel = .constant
        personPlane.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 1)

        let personPlaneNode = SCNNode(geometry: personPlane)
        personPlaneNode.position = .init(0, 0, -5)

        scene?.rootNode.addChildNode(personPlaneNode)
        self.personNode = personPlaneNode
    }

    private func configureForeground() {
        let imageSize = sceneView.frame.size // 16:9

        let foregroundPlane = SCNPlane(width: imageSize.width, height: imageSize.height)
        foregroundPlane.cornerRadius = 0
        foregroundPlane.firstMaterial?.lightingModel = .constant
        foregroundPlane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 1)

        let foregroundPlaneNode = SCNNode(geometry: foregroundPlane)
        foregroundPlaneNode.position = .init(0, 0, -1)

        // Flipping image
        foregroundPlane.firstMaterial?.diffuse.contentsTransform = flipTransform
        foregroundPlane.firstMaterial?.transparent.contentsTransform = flipTransform

        foregroundPlane.firstMaterial?.transparencyMode = .rgbZero

        // Shader to invert the colors from the transparent texture
        foregroundPlane.firstMaterial?.shaderModifiers = [
            .surface: """
            float value = (1.0 - texture2D(u_transparentTexture, _surface.transparentTexcoord).r);
            _surface.transparent = vec4(value, value, value, 1.0);
            """
        ]

        scene?.rootNode.addChildNode(foregroundPlaneNode)
        self.foregroundNode = foregroundPlaneNode
    }

    private func configureAR() {
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

        let session = ARSession()
        session.run(configuration)
        session.delegate = self
        self.session = session

        if let device = sceneView.device {
            self.matteGenerator = ARMatteGenerator(device: device, matteResolution: .full)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if first {
            configureAR()
            configureScene()
            configureBackground()
            configureForeground()
            first = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.pause()
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
    func oculusMRC(
        _ oculusMRC: OculusMRC,
        didReceiveBackground background: UIImage,
        foregroundColor: UIImage,
        foregroundAlpha: UIImage
    ) {
        backgroundNode?.geometry?.firstMaterial?.diffuse.contents = background
        foregroundNode?.geometry?.firstMaterial?.diffuse.contents = foregroundColor
        foregroundNode?.geometry?.firstMaterial?.transparent.contents = foregroundAlpha
    }

    func oculusMRC(_ oculusMRC: OculusMRC, didReceive image: UIImage) {
        debugView.image = image
    }
}

extension MixedRealityViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        if firstFrame {
//            configurePerson(with: frame)
//            firstFrame = false
//        }

        // TODO
//        if let matteGenerator = matteGenerator,
//           let commandBuffer = sceneView.commandQueue?.makeCommandBuffer() {
//            let alpha = matteGenerator.generateMatte(from: frame, commandBuffer: commandBuffer)
//            let dilatedDepthTexture = matteGenerator.generateDilatedDepth(from: frame, commandBuffer: commandBuffer)
//
//
//        }
    }
}
