//
//  ChromaKeyConfigurationViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 24/05/2021.
//

import UIKit
import ARKit

final class ChromaKeyConfigurationViewController: UIViewController {

    private let chromaConfigurationStorage = ChromaKeyConfigurationStorage()

    @IBOutlet private weak var sceneView: ARSCNView!

    private var textureCache: CVMetalTextureCache?
    private var backgroundPlaneNode: SCNNode?
    private var planeNode: SCNNode?

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    var currentConfiguration: ChromaKeyConfiguration

    private var first = true

    init() {
        currentConfiguration = chromaConfigurationStorage.configuration ?? .defaultConfiguration
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDisplay()
        configureScene()

        // TODO: Set current view state accordingly (depending on the current configuration)
    }

    private func configureDisplay() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func configureScene() {
        sceneView.rendersCameraGrain = false
        sceneView.rendersMotionBlur = false

        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.session.delegate = self

        ARKitHelpers.create(textureCache: &textureCache, for: sceneView)
    }

    private func configureBackgroundPlane(with frame: ARFrame) {
        let distance: Float = 100
        let backgroundPlaneSize = ARKitHelpers.planeSizeForDistance(distance, frame: frame)
        let backgroundPlaneNode = ARKitHelpers.makePlane(size: backgroundPlaneSize, distance: distance)

        let planeMaterial = backgroundPlaneNode.geometry?.firstMaterial
        planeMaterial?.lightingModel = .constant
        planeMaterial?.diffuse.contents = UIImage(named: "tile")

        let repeatX = (Float(backgroundPlaneSize.width)/6.4).rounded()
        let repeatY = (Float(backgroundPlaneSize.height)/6.4).rounded()
        planeMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatX, repeatY, 0)

        planeMaterial?.diffuse.wrapS = SCNWrapMode.repeat
        planeMaterial?.diffuse.wrapT = SCNWrapMode.repeat

        sceneView.pointOfView?.addChildNode(backgroundPlaneNode)
        self.backgroundPlaneNode = backgroundPlaneNode
    }

    private func configurePlane(with frame: ARFrame) {
        let planeNode = ARKitHelpers.makePlaneNodeForDistance(0.1, frame: frame)

        planeNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        planeNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: Shaders.surfaceChromaKey(red: 0, green: 0, blue: 0, threshold: 0)
        ]

        sceneView.pointOfView?.addChildNode(planeNode)
        self.planeNode = planeNode
    }

    func updatePlaneImage(with pixelBuffer: CVPixelBuffer) {
        let luma = ARKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        planeNode?.geometry?.firstMaterial?.transparent.contents = luma
        planeNode?.geometry?.firstMaterial?.diffuse.contents = chroma
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareARConfiguration()
    }

    private func prepareARConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Actions

    @IBAction private func editMaskAction(_ sender: Any) {
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }

        // TODO: Pass the current mask
        let viewController = MaskEditorViewController(frame: currentFrame, chromaConfiguration: currentConfiguration)
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: true, completion: nil)
    }

    @IBAction private func saveAction(_ sender: Any) {
        // TODO: - Implement
    }

    @IBAction private func cancelAction(_ sender: Any) {
        dismiss(animated: false, completion: nil)
    }

    @IBAction func sliderValueChanged(_ slider: UISlider) {
        // TODO: Improve this, avoid resetting the shader
        planeNode?.geometry?.firstMaterial?.shaderModifiers = [
            .surface: Shaders.surfaceChromaKey(red: 0, green: 1, blue: 0, threshold: slider.value)
        ]

        self.currentConfiguration = .init(color: .init(red: 0, green: 1, blue: 0), mode: .threshold(slider.value))
    }
}

extension ChromaKeyConfigurationViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if first {
            configureBackgroundPlane(with: frame)
            configurePlane(with: frame)
            first = false
        }

        updatePlaneImage(with: frame.capturedImage)
    }
}
