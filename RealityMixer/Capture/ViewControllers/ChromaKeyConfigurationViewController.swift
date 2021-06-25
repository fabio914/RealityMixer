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
    @IBOutlet private weak var modeSegmentedControl: UISegmentedControl!

    @IBOutlet private weak var thresholdContainer: UIStackView!
    @IBOutlet private weak var thresholdSlider: UISlider!

    @IBOutlet private weak var smoothContainer: UIStackView!
    @IBOutlet private weak var sensitivitySlider: UISlider!
    @IBOutlet private weak var smoothnessSlider: UISlider!

    private var chromaColor: UIColor = .init(red: 0, green: 1, blue: 0, alpha: 0)
    // TODO: Add reference to the current Mask

    private var textureCache: CVMetalTextureCache?
    private var backgroundPlaneNode: SCNNode?
    private var planeNode: SCNNode?

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    private var first = true

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDisplay()
        configureScene()

        smoothnessSlider.minimumValue = 0
        smoothnessSlider.maximumValue = 0.1

        if let currentConfiguration = chromaConfigurationStorage.configuration {
            switch currentConfiguration.mode {
            case .threshold(let threshold):
                modeSegmentedControl.selectedSegmentIndex = 0
                thresholdSlider.value = threshold
            case .smooth(let sensitivity, let smoothness):
                modeSegmentedControl.selectedSegmentIndex = 1
                sensitivitySlider.value = sensitivity
                smoothnessSlider.value = smoothness
            }

            self.chromaColor = currentConfiguration.color.uiColor
        }

        updateMode()
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

    func updateMode() {
        thresholdContainer.isHidden = modeSegmentedControl.selectedSegmentIndex == 1
        smoothContainer.isHidden = modeSegmentedControl.selectedSegmentIndex == 0
    }

    func updatePlaneImage(with pixelBuffer: CVPixelBuffer) {
        let luma = ARKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        planeNode?.geometry?.firstMaterial?.transparent.contents = luma
        planeNode?.geometry?.firstMaterial?.diffuse.contents = chroma
    }

    func didUpdateValues() {
        updateMode()

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        chromaColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

        // TODO: Avoid updating the shader all the time (pass these as
        // parameters)
        if modeSegmentedControl.selectedSegmentIndex == 0 {

            planeNode?.geometry?.firstMaterial?.shaderModifiers = [
                .surface: Shaders.surfaceChromaKey(
                    red: Float(red), green: Float(green), blue: Float(blue),
                    threshold: thresholdSlider.value
                )
            ]
        } else {

            planeNode?.geometry?.firstMaterial?.shaderModifiers = [
                .surface: Shaders.surfaceChromaKey(
                    red: Float(red), green: Float(green), blue: Float(blue),
                    sensitivity: sensitivitySlider.value,
                    smoothness: smoothnessSlider.value
                )
            ]
        }
    }

    func currentConfiguration() -> ChromaKeyConfiguration {
        if modeSegmentedControl.selectedSegmentIndex == 0 {
            return .init(
                color: .init(uiColor: chromaColor),
                mode: .threshold(thresholdSlider.value)
            )
        } else {
            return .init(
                color: .init(uiColor: chromaColor),
                mode: .smooth(
                    sensitivity: sensitivitySlider.value,
                    smoothness: smoothnessSlider.value
                )
            )
        }
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

    @IBAction func pickColorAction(_ sender: Any) {
        // TODO
    }

    @IBAction private func editMaskAction(_ sender: Any) {
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }

        // TODO: Pass the current mask
        let viewController = MaskEditorViewController(frame: currentFrame, chromaConfiguration: currentConfiguration())
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: true, completion: nil)
    }

    @IBAction private func saveAction(_ sender: Any) {
        try? chromaConfigurationStorage.save(configuration: currentConfiguration())
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func valueChanged(_ sender: Any) {
        didUpdateValues()
    }
}

extension ChromaKeyConfigurationViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if first {
            configureBackgroundPlane(with: frame)
            configurePlane(with: frame)
            didUpdateValues()
            first = false
        }

        updatePlaneImage(with: frame.capturedImage)
    }
}
