//
//  MixedRealityViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import ARKit
import AVFoundation
import SwiftSocket

final class MixedRealityViewController: UIViewController {
    private let client: TCPClient
    private let configuration: MixedRealityConfiguration
    private let chromaConfiguration: ChromaKeyConfiguration?
    private let factory: ARConfigurationFactory

    private let audioManager = AudioManager()
    private var displayLink: CADisplayLink?
    private var oculusCapture: OculusCapture?
//    private var networkThread: Thread?
    private var lastFrame: CVPixelBuffer?

    @IBOutlet private weak var optionsContainer: UIView!
    @IBOutlet private weak var sceneView: ARSCNView!
    private var textureCache: CVMetalTextureCache?
    private var backgroundNode: SCNNode?
    private var middlePlaneNode: SCNNode?
    private var foregroundNode: SCNNode?

    private let flipTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

    private var avatar: AvatarProtocol?

    var first = true

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    private let cameraPoseSender: CameraPoseSender?

    private var hideTimer: Timer?

    init(
        client: TCPClient,
        configuration: MixedRealityConfiguration,
        chromaConfiguration: ChromaKeyConfiguration?
    ) {
        self.client = client
        self.configuration = configuration
        self.chromaConfiguration = chromaConfiguration
        self.factory = ARConfigurationFactory(mrConfiguration: configuration)
        self.cameraPoseSender = configuration.enableMovingCamera ? CameraPoseSender(client: client):nil
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
        configureTap()
        configureBackgroundEvent()
    }

    private func configureDisplay() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func configureDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
    }

    private func configureOculusMRC() {
        self.oculusCapture = OculusCapture(delegate: self)

//        networkThread = Thread(block: { [weak oculusCapture, weak client] in
//            let thread = Thread.current
//            while !thread.isCancelled {
//                while let data = client?.read(65536, timeout: 0), data.count > 0, !thread.isCancelled {
//                    oculusCapture?.add(data: .init(data))
//                }
//            }
//         })
//
//         networkThread?.start()
    }

    private func configureScene() {
        sceneView.rendersCameraGrain = false
        sceneView.rendersMotionBlur = false

        // Light for the model
        if case .bodyTracking = configuration.captureMode {
            sceneView.autoenablesDefaultLighting = true
            sceneView.automaticallyUpdatesLighting = true
        }

        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.session.delegate = self

        if case .visible = configuration.backgroundLayerOptions.visibility {
            sceneView.pointOfView?.addChildNode(ARKitHelpers.makePlane(size: .init(width: 9999, height: 9999), distance: 120))
        }

        ARKitHelpers.create(textureCache: &textureCache, for: sceneView)
    }

    private func configureTap() {
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAction)))
    }

    private func configureBackgroundEvent() {
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    private func configureBackground(viewPortSize: CGSize, projectionMatrix: simd_float4x4) {
        if case .hidden = configuration.backgroundLayerOptions.visibility { return }
        let backgroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(100.0, viewPortSize: viewPortSize, projectionMatrix: projectionMatrix)

        // Flipping image
        if configuration.shouldFlipOutput {
            backgroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform
            backgroundPlaneNode.geometry?.firstMaterial?.transparent.contentsTransform = flipTransform
        }

        backgroundPlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        let surfaceShader = { () -> String in
            switch configuration.backgroundLayerOptions.visibility {
            case .chromaKey(.black):
                return Shaders.backgroundSurfaceWithBlackChromaKey
            case .chromaKey(.green):
                return Shaders.backgroundSurfaceWithGreenChromaKey
            case .chromaKey(.magenta):
                return Shaders.backgroundSurfaceWithMagentaChromaKey
            default:
                return Shaders.backgroundSurface
            }
        }()

        backgroundPlaneNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: surfaceShader
        ]

        sceneView.pointOfView?.addChildNode(backgroundPlaneNode)
        self.backgroundNode = backgroundPlaneNode
    }

    private func configureMiddle(viewPortSize: CGSize, projectionMatrix: simd_float4x4) {
        guard case .greenScreen = configuration.captureMode,
            let chromaConfiguration = chromaConfiguration
        else { return }
        let middlePlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.02, viewPortSize: viewPortSize, projectionMatrix: projectionMatrix)

        middlePlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        middlePlaneNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: Shaders.surfaceChromaKey()
        ]

        let color = chromaConfiguration.color

        middlePlaneNode.geometry?.firstMaterial?.setValue(
            SCNVector3(color.red, color.green, color.blue),
            forKey: "maskColor"
        )

        middlePlaneNode.geometry?.firstMaterial?.setValue(
            chromaConfiguration.sensitivity,
            forKey: "sensitivity"
        )

        middlePlaneNode.geometry?.firstMaterial?.setValue(
            chromaConfiguration.smoothness,
            forKey: "smoothness"
        )

        let maskStorage = ChromaKeyMaskStorage()

        if let maskImage = maskStorage.load() {
            middlePlaneNode.geometry?.firstMaterial?.ambient.contents = maskImage
        } else {
            middlePlaneNode.geometry?.firstMaterial?.ambient.contents = UIColor.white
        }

        sceneView.pointOfView?.addChildNode(middlePlaneNode)
        self.middlePlaneNode = middlePlaneNode
    }

    private func configureForeground(viewPortSize: CGSize, projectionMatrix: simd_float4x4) {
        guard case .visible(let useMagentaAsTransparency) = configuration.foregroundLayerOptions.visibility else { return }
        let foregroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.01, viewPortSize: viewPortSize, projectionMatrix: projectionMatrix)

        // Flipping image
        if configuration.shouldFlipOutput {
            foregroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform
            foregroundPlaneNode.geometry?.firstMaterial?.transparent.contentsTransform = flipTransform
        }

        foregroundPlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        if useMagentaAsTransparency {
            foregroundPlaneNode.geometry?.firstMaterial?.shaderModifiers = [
                .surface: Shaders.magentaForegroundSurface
            ]
        } else {
            foregroundPlaneNode.geometry?.firstMaterial?.shaderModifiers = [
                .surface: Shaders.foregroundSurface
            ]
        }

        // FIXME: Semi-transparent textures won't work with person segmentation. They'll
        // blend with the background instead of blending with the segmented image of the person.

        sceneView.pointOfView?.addChildNode(foregroundPlaneNode)
        self.foregroundNode = foregroundPlaneNode
    }

    private func updateForegroundBackground(with pixelBuffer: CVPixelBuffer) {
        let luma = ARKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        backgroundNode?.geometry?.firstMaterial?.transparent.contents = luma
        backgroundNode?.geometry?.firstMaterial?.diffuse.contents = chroma

        foregroundNode?.geometry?.firstMaterial?.transparent.contents = luma
        foregroundNode?.geometry?.firstMaterial?.diffuse.contents = chroma
    }

    private func updateMiddle(with pixelBuffer: CVPixelBuffer) {
        guard case .greenScreen = configuration.captureMode else { return }
        let luma = ARKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        middlePlaneNode?.geometry?.firstMaterial?.transparent.contents = luma
        middlePlaneNode?.geometry?.firstMaterial?.diffuse.contents = chroma
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareARConfiguration()
    }

    private func prepareARConfiguration() {
        sceneView.session.run(factory.build())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @objc func update(with sender: CADisplayLink) {
        while let data = client.read(65536, timeout: 0), data.count > 0 {
            oculusCapture?.add(data: .init(data))
        }

        oculusCapture?.update()

        if let lastFrame = lastFrame {
            updateForegroundBackground(with: lastFrame)
        }
    }

    // MARK: - Actions

    private func hideOptions() {
        hideTimer?.invalidate()
        hideTimer = nil
        optionsContainer.isHidden = true
    }

    @objc private func tapAction() {
        if optionsContainer.isHidden {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { [weak self] _ in
                self?.hideOptions()
            })

            optionsContainer.isHidden = false
        } else {
            hideOptions()
        }
    }

    private func disconnect() {
        invalidate()
        dismiss(animated: false, completion: nil)
    }

    @objc private func willResignActive() {
        disconnect()
    }

    @IBAction private func disconnectAction(_ sender: Any) {
        disconnect()
    }

    @IBAction private func hideAction(_ sender: Any) {
        hideOptions()
    }

    func invalidate() {
//        networkThread?.cancel()
        audioManager.invalidate()
        displayLink?.invalidate()
        hideTimer?.invalidate()
        client.close()
    }

    deinit {
        invalidate()
    }
}

extension MixedRealityViewController: OculusCaptureDelegate {

    func oculusCapture(_ oculusCapture: OculusCapture, didReceive pixelBuffer: CVPixelBuffer) {
        lastFrame = pixelBuffer
    }

    func oculusCapture(_ oculusCapture: OculusCapture, didReceiveAudio audio: AVAudioPCMBuffer, timestamp: UInt64) {
        audioManager.play(audio: audio, timestamp: timestamp)
    }
}

extension MixedRealityViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        if first {
            let viewPortSize = sceneView.bounds.size
            let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? UIInterfaceOrientation.unknown
            let projectionMatrix = frame.camera.projectionMatrix(for: interfaceOrientation, viewportSize: viewPortSize, zNear: 0.001, zFar: 1000.0)

            configureBackground(viewPortSize: viewPortSize, projectionMatrix: projectionMatrix)
            configureMiddle(viewPortSize: viewPortSize, projectionMatrix: projectionMatrix)
            configureForeground(viewPortSize: viewPortSize, projectionMatrix: projectionMatrix)
            first = false
        } else {
            // TODO: Check this (this might need to be updated)
            cameraPoseSender?.didUpdate(frame: frame)
        }

        updateMiddle(with: frame.capturedImage)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let bodyAnchor = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }

        if let avatar = avatar {
            avatar.update(bodyAnchor: bodyAnchor)
        } else {
            avatar = factory.buildAvatar(bodyAnchor: bodyAnchor)
            if let mainNode = avatar?.mainNode {
                sceneView.scene.rootNode.addChildNode(mainNode)
            }
            avatar?.update(bodyAnchor: bodyAnchor)
        }
    }
}
