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
    private let maskStorage = ChromaKeyMaskStorage()

    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var sensitivitySlider: UISlider!
    @IBOutlet private weak var sensitivityLabel: UILabel!
    @IBOutlet private weak var smoothnessSlider: UISlider!
    @IBOutlet private weak var smoothnessLabel: UILabel!
    @IBOutlet private weak var colorWell: UIColorWell!
    @IBOutlet private weak var editMaskButton: UIButton!

    private static let defaultChromaColor = UIColor(red: 0, green: 1, blue: 0, alpha: 1)

    private var chromaColor: UIColor
    private var maskImage: UIImage?

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
    private var isPresentingColorPicker = false

    init() {
        self.chromaColor = Self.defaultChromaColor
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDisplay()
        configureScene()
        configureSliders()
        configureColorWell()
        resetValues()

        if let currentConfiguration = chromaConfigurationStorage.configuration {
            sensitivitySlider.value = currentConfiguration.sensitivity
            smoothnessSlider.value = currentConfiguration.smoothness
            chromaColor = currentConfiguration.color.uiColor
            colorWell.selectedColor = chromaColor
            updateValueLabels()
        }

        maskImage = maskStorage.load()
        updateMaskButton()
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

    private func configureColorWell() {
        colorWell.supportsAlpha = false
        colorWell.addTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)
    }

    private func configureSliders() {
        // TODO: Update these intervals!
        sensitivitySlider.minimumValue = 0.0
        sensitivitySlider.maximumValue = 1.0

        smoothnessSlider.minimumValue = 0
        smoothnessSlider.maximumValue = 0.1
    }

    private func resetValues() {
        sensitivitySlider.value = 0.5
        smoothnessSlider.value = 0
        chromaColor = Self.defaultChromaColor
        colorWell.selectedColor = chromaColor
        updateValueLabels()
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
        planeNode.geometry?.firstMaterial?.lightingModel = .constant
        planeNode.geometry?.firstMaterial?.transparencyMode = .rgbZero
        planeNode.geometry?.firstMaterial?.shaderModifiers = [.surface: Shaders.surfaceChromaKeyConfiguration()]
        sceneView.pointOfView?.addChildNode(planeNode)
        self.planeNode = planeNode
    }

    func updatePlaneImage(with pixelBuffer: CVPixelBuffer) {
        let luma = ARKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        planeNode?.geometry?.firstMaterial?.transparent.contents = luma
        planeNode?.geometry?.firstMaterial?.diffuse.contents = chroma
    }

    func updateValueLabels() {
        sensitivityLabel.text = String(format: "%.2lf", sensitivitySlider.value)
        smoothnessLabel.text = String(format: "%.2lf", smoothnessSlider.value)
    }

    func updateMaskButton() {
        if maskImage != nil {
            editMaskButton.setTitle("Remove Mask", for: .normal)
        } else {
            editMaskButton.setTitle("Add Mask", for: .normal)
        }
    }

    func didUpdateValues() {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        chromaColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

        if let maskImage = maskImage, !isPresentingColorPicker {
            planeNode?.geometry?.firstMaterial?.ambient.contents = maskImage
        } else {
            planeNode?.geometry?.firstMaterial?.ambient.contents = UIColor.white
        }

        planeNode?.geometry?.firstMaterial?.setValue(
            SCNVector3(red, green, blue),
            forKey: "maskColor"
        )

        if isPresentingColorPicker {
            planeNode?.geometry?.firstMaterial?.setValue(0.0, forKey: "sensitivity")
            planeNode?.geometry?.firstMaterial?.setValue(0.0, forKey: "smoothness")
        } else {
            planeNode?.geometry?.firstMaterial?.setValue(
                sensitivitySlider.value,
                forKey: "sensitivity"
            )

            planeNode?.geometry?.firstMaterial?.setValue(
                smoothnessSlider.value,
                forKey: "smoothness"
            )
        }

        updateValueLabels()
    }

    func currentConfiguration() -> ChromaKeyConfiguration {
        .init(
            color: .init(uiColor: chromaColor),
            sensitivity: sensitivitySlider.value,
            smoothness: smoothnessSlider.value
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareARConfiguration()
    }

    private func prepareARConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = false
        configuration.isAutoFocusEnabled = true // Consider changing to false
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Actions

    @IBAction func pickColorAction(_ sender: Any) {
        isPresentingColorPicker = true
        didUpdateValues()

        let pickerController = UIColorPickerViewController()
        pickerController.delegate = self
        pickerController.selectedColor = chromaColor
        pickerController.supportsAlpha = false

        pickerController.modalPresentationStyle = .popover
        pickerController.popoverPresentationController?.sourceView = colorWell
        pickerController.popoverPresentationController?.delegate = self

        present(pickerController, animated: true, completion: nil)
    }

    @IBAction func resetValuesAction(_ sender: Any) {
        resetValues()
        didUpdateValues()
    }

    @IBAction private func editMaskAction(_ sender: Any) {
        if maskImage == nil {
            guard let currentFrame = sceneView.session.currentFrame else {
                return
            }

            self.maskImage = ChromaKeyMaskBuilder.buildMask(for: currentFrame, chromaConfiguration: currentConfiguration())
        } else {
            self.maskImage = nil
        }

        updateMaskButton()
        didUpdateValues()
    }

    @IBAction private func saveAction(_ sender: Any) {
        try? chromaConfigurationStorage.save(configuration: currentConfiguration())
        try? maskStorage.update(mask: maskImage)
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

extension ChromaKeyConfigurationViewController: UIColorPickerViewControllerDelegate {

    // This won't get called if the user dismisses the View Controller without tapping
    // on the close button, thanks Apple.
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        isPresentingColorPicker = false
        didUpdateValues()
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        chromaColor = viewController.selectedColor
        colorWell.selectedColor = chromaColor
        didUpdateValues()
    }
}

extension ChromaKeyConfigurationViewController: UIPopoverPresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        isPresentingColorPicker = false
        didUpdateValues()
    }
}
