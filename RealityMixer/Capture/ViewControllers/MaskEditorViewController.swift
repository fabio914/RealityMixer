//
//  MaskEditorViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 16/06/2021.
//

import UIKit
import ARKit

struct Mask {
    static let opaqueColor = UIColor.white
    static let transparentColor = UIColor.black
}

final class MaskEditorViewController: UIViewController {

    private var framePixelBuffer: CVPixelBuffer
    private var maskImage: UIImage?

    private let size: CGSize
    private let chromaConfiguration: ChromaKeyConfiguration

    @IBOutlet private weak var sceneView: SCNView!

    @IBOutlet private weak var radiusSlider: UISlider!
    @IBOutlet private weak var modeSegmentedControl: UISegmentedControl!

    enum Mode: Int {
        case drawing = 0
        case erasing = 1
    }

    private var currentMode: Mode {
        Mode(rawValue: modeSegmentedControl.selectedSegmentIndex) ?? .drawing
    }

    private var textureCache: CVMetalTextureCache?

    private var first = true

    // TODO: Receive current mask (if it exists)
    init(frame: ARFrame, chromaConfiguration: ChromaKeyConfiguration) {
        self.chromaConfiguration = chromaConfiguration
        self.size = frame.camera.imageResolution

        // TODO: Load existing mask (if it exists)
        self.maskImage = Mask.transparentColor.image(size: self.size)
        self.framePixelBuffer = frame.capturedImage
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ARKitHelpers.create(textureCache: &textureCache, for: sceneView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if first {
            buildScene()
            first = false
        }
    }

    private func buildScene() {
        let scene = SCNScene()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = .init(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // TODO: Add background plane with pattern

        let planeNode = ARKitHelpers.makePlane(size: .init(width: 1, height: 1), distance: 1)

        planeNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        planeNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: Shaders.surfaceChromaKey()
        ]

        let color = chromaConfiguration.color

        planeNode.geometry?.firstMaterial?.setValue(
            SCNVector3(color.red, color.green, color.blue),
            forKey: "maskColor"
        )

        planeNode.geometry?.firstMaterial?.setValue(
            chromaConfiguration.sensitivity,
            forKey: "sensitivity"
        )

        planeNode.geometry?.firstMaterial?.setValue(
            chromaConfiguration.smoothness,
            forKey: "smoothness"
        )

        let luma = ARKitHelpers.texture(from: framePixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: framePixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        planeNode.geometry?.firstMaterial?.transparent.contents = luma
        planeNode.geometry?.firstMaterial?.diffuse.contents = chroma

        // TODO: Set texture with mask (and update this texture as we draw)

        cameraNode.addChildNode(planeNode)

        sceneView.scene = scene
    }

    // MARK: - Actions

    @IBAction private func resetAction(_ sender: Any) {

    }

    @IBAction private func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func updateAction(_ sender: Any) {

    }
}
