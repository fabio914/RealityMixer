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
    private let shouldUseHardwareDecoder: Bool
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var debugView: UIImageView!
    @IBOutlet private weak var sceneView: ARSCNView!
    private var backgroundNode: SCNNode?
    private var foregroundNode: SCNNode?

    private let flipTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

    var first = true

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    init(
        client: TCPClient,
        shouldShowDebug: Bool,
        shouldUseHardwareDecoder: Bool
    ) {
        self.client = client
        self.shouldShowDebug = shouldShowDebug
        self.shouldUseHardwareDecoder = shouldUseHardwareDecoder
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
        configureScene()
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
        self.oculusMRC = OculusMRC(hardwareDecoder: shouldUseHardwareDecoder)
        oculusMRC?.delegate = self
    }

    private func configureScene() {
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.session.delegate = self

        sceneView.pointOfView?.addChildNode(makePlane(size: .init(width: 9999, height: 9999), distance: 120))
    }

    private func planeSizeForDistance(_ distance: Float, frame: ARFrame) -> CGSize {
        let projection = frame.camera.projectionMatrix
        let yScale = projection[1,1]
        let imageResolution = frame.camera.imageResolution
        let width = (2.0 * distance) * tan(atan(1/yScale) * Float(imageResolution.width / imageResolution.height))

        // 16:9 aspect ratio
        let height = (9.0 * width)/16.0
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    private func makePlane(size: CGSize, distance: Float) -> SCNNode {
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.cornerRadius = 0
        plane.firstMaterial?.lightingModel = .constant
        plane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 0, alpha: 1)

        let planeNode = SCNNode(geometry: plane)
        planeNode.position = .init(0, 0, -distance)
        return planeNode
    }

    private func makePlaneNodeForDistance(_ distance: Float, frame: ARFrame) -> SCNNode {
        makePlane(size: planeSizeForDistance(distance, frame: frame), distance: distance)
    }

    private func configureBackground(with frame: ARFrame) {
        let backgroundPlaneNode = makePlaneNodeForDistance(100.0, frame: frame)

        // Flipping image
        backgroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform

        backgroundPlaneNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: """
            vec2 backgroundCoords = vec2((_surface.diffuseTexcoord.x * 0.5), _surface.diffuseTexcoord.y);
            _surface.diffuse = texture2D(u_diffuseTexture, backgroundCoords);
            """
        ]

        sceneView.pointOfView?.addChildNode(backgroundPlaneNode)
        self.backgroundNode = backgroundPlaneNode
    }

    private func configureForeground(with frame: ARFrame) {
        let foregroundPlaneNode = makePlaneNodeForDistance(0.1, frame: frame)

        // Flipping image
        foregroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform
        foregroundPlaneNode.geometry?.firstMaterial?.transparent.contentsTransform = flipTransform

        foregroundPlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        foregroundPlaneNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: """
            vec2 foregroundCoords = vec2((_surface.diffuseTexcoord.x * 0.25) + 0.5, _surface.diffuseTexcoord.y);
            _surface.diffuse = texture2D(u_diffuseTexture, foregroundCoords);

            vec2 alphaCoords = vec2((_surface.transparentTexcoord.x * 0.25) + 0.75, _surface.transparentTexcoord.y);
            float alpha = texture2D(u_transparentTexture, alphaCoords).r;

            // Threshold to prevent glitches because of the video compression.
            float threshold = 0.25;
            float correctedAlpha = step(threshold, alpha) * alpha;

            float value = (1.0 - correctedAlpha);
            _surface.transparent = vec4(value, value, value, 1.0);
            """
        ]

        // FIXME: Semi-transparent textures won't work with person segmentation. They'll
        // blend with the background instead of blending with the segmented image of the person.

        sceneView.pointOfView?.addChildNode(foregroundPlaneNode)
        self.foregroundNode = foregroundPlaneNode
    }

    private func configureDebugView() {
        debugView.isHidden = !shouldShowDebug
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
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

    func oculusMRC(_ oculusMRC: OculusMRC, didReceive image: UIImage) {
        debugView.image = image
        backgroundNode?.geometry?.firstMaterial?.diffuse.contents = image
        foregroundNode?.geometry?.firstMaterial?.diffuse.contents = image
        foregroundNode?.geometry?.firstMaterial?.transparent.contents = image
    }
}

extension MixedRealityViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if first {
            configureBackground(with: frame)
            configureForeground(with: frame)
            first = false
        }
    }
}
