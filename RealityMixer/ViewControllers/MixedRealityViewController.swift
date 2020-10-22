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
    @IBOutlet private weak var sceneView: ARSCNView!
    private var backgroundNode: SCNNode?
    private var foregroundNode: SCNNode?

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
        configureBackground()
        configureForeground()
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

    private func configureBackground() {
        let backgroundScene = SCNScene()
        sceneView.scene = backgroundScene

        let backgroundPlane = SCNPlane(width: 160, height: 90) // Assuming a 16:9 aspect ratio
        backgroundPlane.cornerRadius = 0
        backgroundPlane.firstMaterial?.lightingModel = .constant
        backgroundPlane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 1)

        let backgroundPlaneNode = SCNNode(geometry: backgroundPlane)
        backgroundPlaneNode.position = .init(0, 0, -90)

        // Flipping image
        backgroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform

        sceneView.pointOfView?.addChildNode(backgroundPlaneNode)
        self.backgroundNode = backgroundPlaneNode
    }

    private func configureForeground() {
        let foregroundPlane = SCNPlane(width: 0.16, height: 0.09) // Assuming a 16:9 aspect ratio
        foregroundPlane.cornerRadius = 0
        foregroundPlane.firstMaterial?.lightingModel = .constant
        foregroundPlane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 1)

        let foregroundPlaneNode = SCNNode(geometry: foregroundPlane)
        foregroundPlaneNode.position = .init(0, 0, -0.09)

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

        // FIXME: Semi-transparent textures won't work with person segmentation. They'll
        // blend with the background instead of blending with the segmented image of the person.

        sceneView.pointOfView?.addChildNode(foregroundPlaneNode)
        self.foregroundNode = foregroundPlaneNode
    }

    private func configureDebugView() {
        debugView.isHidden = !shouldShowDebug
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

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
