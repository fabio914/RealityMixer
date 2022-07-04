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
    private var networkThread: Thread?
    private var lastFrame: CVPixelBuffer?

    private var oculusCapture: OculusCapture?

    @IBOutlet private weak var optionsContainer: UIView!
    @IBOutlet private weak var sceneView: SCNView!
    private var textureCache: CVMetalTextureCache?
    private var backgroundNode: SCNNode?
    private var middlePlaneNode: SCNNode?
    private var foregroundNode: SCNNode?

    private let flipTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

    private var avatar: AvatarProtocol?

    var first = true

    private var keyPresses = KeyPresses()
    private var virtualCamera = VirtualCamera()

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

//        self.cameraPoseSender = configuration.enableMovingCamera ? CameraPoseSender(client: client):nil
        self.cameraPoseSender = CameraPoseSender(client: client)

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
        displayLink.preferredFramesPerSecond = 0
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
    }

    private func configureOculusMRC() {
//        self.oculusMRC = OculusMRC()
//        oculusMRC?.delegate = self

        self.oculusCapture = OculusCapture(delegate: self)

//        networkThread = Thread(block: { [weak oculusMRC, weak client] in
//            let thread = Thread.current
//            while !thread.isCancelled {
//                while let data = client?.read(65536, timeout: 0), data.count > 0, !thread.isCancelled {
//                    oculusMRC?.addData(data, length: Int32(data.count))
//                }
//            }
//         })
//
//        networkThread?.start()
    }

    private func configureScene() {
//        sceneView.rendersCameraGrain = false
//        sceneView.rendersMotionBlur = false
//
//        // Light for the model
//        if case .bodyTracking = configuration.captureMode {
//            sceneView.autoenablesDefaultLighting = true
//            sceneView.automaticallyUpdatesLighting = true
//        }

        let scene = SCNScene()

        // Adding scenekit camera
        scene.rootNode.camera = SCNCamera()

        sceneView.scene = scene
//        sceneView.session.delegate = self

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

//    private func configureBackground(with frame: ARFrame) {
    private func configureBackground(camera: SCNCamera, imageResolution: CGSize) {
        if case .hidden = configuration.backgroundLayerOptions.visibility { return }
//        let backgroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(100.0, frame: frame)
        let backgroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(100.0, camera: camera, imageResolution: imageResolution)

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

//    private func configureMiddle(with frame: ARFrame) {
//        guard case .greenScreen = configuration.captureMode,
//            let chromaConfiguration = chromaConfiguration
//        else { return }
//        let middlePlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.02, frame: frame)
//
//        middlePlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero
//
//        middlePlaneNode.geometry?.firstMaterial?.shaderModifiers = [
//            .surface: Shaders.surfaceChromaKey()
//        ]
//
//        let color = chromaConfiguration.color
//
//        middlePlaneNode.geometry?.firstMaterial?.setValue(
//            SCNVector3(color.red, color.green, color.blue),
//            forKey: "maskColor"
//        )
//
//        middlePlaneNode.geometry?.firstMaterial?.setValue(
//            chromaConfiguration.sensitivity,
//            forKey: "sensitivity"
//        )
//
//        middlePlaneNode.geometry?.firstMaterial?.setValue(
//            chromaConfiguration.smoothness,
//            forKey: "smoothness"
//        )
//
//        let maskStorage = ChromaKeyMaskStorage()
//
//        if let maskImage = maskStorage.load() {
//            middlePlaneNode.geometry?.firstMaterial?.ambient.contents = maskImage
//        } else {
//            middlePlaneNode.geometry?.firstMaterial?.ambient.contents = UIColor.white
//        }
//
//        sceneView.pointOfView?.addChildNode(middlePlaneNode)
//        self.middlePlaneNode = middlePlaneNode
//    }

//    private func configureForeground(with frame: ARFrame) {
    private func configureForeground(camera: SCNCamera, imageResolution: CGSize) {
        guard case .visible(let useMagentaAsTransparency) = configuration.foregroundLayerOptions.visibility else { return }
//        let foregroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.01, frame: frame)
        let foregroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.01, camera: camera, imageResolution: imageResolution)

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

//    private func updateMiddle(with pixelBuffer: CVPixelBuffer) {
//        guard case .greenScreen = configuration.captureMode else { return }
//        let luma = ARKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
//        let chroma = ARKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)
//
//        middlePlaneNode?.geometry?.firstMaterial?.transparent.contents = luma
//        middlePlaneNode?.geometry?.firstMaterial?.diffuse.contents = chroma
//    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareARConfiguration()

        if first {
            let imageResolution = CGSize(width: 1920, height: 1080) //sceneView.frame.size
            guard let camera = sceneView.scene?.rootNode.camera else { return }

            configureBackground(camera: camera, imageResolution: imageResolution)
            configureForeground(camera: camera, imageResolution: imageResolution)
            first = false
        }
    }

    private func prepareARConfiguration() {
//        sceneView.session.run(factory.build())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        sceneView.session.pause()
    }

    @objc func update(with sender: CADisplayLink) {

        while let data = client.read(65536, timeout: 0), data.count > 0 {
            oculusCapture?.add(data: Data(data))
        }

        oculusCapture?.update()

        if let lastFrame = lastFrame {
            updateForegroundBackground(with: lastFrame)
        }

        keyPresses.update(virtualCamera: virtualCamera, duration: sender.duration)
        cameraPoseSender?.sendCameraUpdate(pose: virtualCamera.pose)
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
        networkThread?.cancel()
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

//        if first {
//            configureBackground(with: frame)
//            configureMiddle(with: frame)
//            configureForeground(with: frame)
//            first = false
//        } else {
//            cameraPoseSender?.didUpdate(frame: frame)
//        }
//
//        updateMiddle(with: frame.capturedImage)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        guard let bodyAnchor = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }
//
//        if let avatar = avatar {
//            avatar.update(bodyAnchor: bodyAnchor)
//        } else {
//            avatar = factory.buildAvatar(bodyAnchor: bodyAnchor)
//            if let mainNode = avatar?.mainNode {
//                sceneView.scene.rootNode.addChildNode(mainNode)
//            }
//            avatar?.update(bodyAnchor: bodyAnchor)
//        }
    }
}

extension MixedRealityViewController {

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        for press in presses {
            guard let key = press.key else { continue }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputLeftArrow {
                keyPresses.rotateLeft = true
                didHandleEvent = true
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputRightArrow {
                keyPresses.rotateRight = true
                didHandleEvent = true
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputUpArrow {
                keyPresses.rotateUp = true
                didHandleEvent = true
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputDownArrow {
                keyPresses.rotateDown = true
                didHandleEvent = true
            }
            if key.keyCode == .keyboardA {
                keyPresses.left = true
                didHandleEvent = true
            }
            if key.keyCode == .keyboardD {
                keyPresses.right = true
                didHandleEvent = true
            }
            if key.keyCode == .keyboardW {
                keyPresses.forward = true
                didHandleEvent = true
            }
            if key.keyCode == .keyboardS {
                keyPresses.backward = true
                didHandleEvent = true
            }
        }

        if !didHandleEvent {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandleEvent = false
        for press in presses {
            guard let key = press.key else { continue }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputLeftArrow {
                keyPresses.rotateLeft = false
                didHandleEvent = true
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputRightArrow {
                keyPresses.rotateRight = false
                didHandleEvent = true
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputUpArrow {
                keyPresses.rotateUp = false
                didHandleEvent = true
            }
            if key.charactersIgnoringModifiers == UIKeyCommand.inputDownArrow {
                keyPresses.rotateDown = false
                didHandleEvent = true
            }
            if key.keyCode == .keyboardA {
                keyPresses.left = false
                didHandleEvent = true
            }
            if key.keyCode == .keyboardD {
                keyPresses.right = false
                didHandleEvent = true
            }
            if key.keyCode == .keyboardW {
                keyPresses.forward = false
                didHandleEvent = true
            }
            if key.keyCode == .keyboardS {
                keyPresses.backward = false
                didHandleEvent = true
            }
        }

        if !didHandleEvent {
            super.pressesEnded(presses, with: event)
        }
    }
}

final class KeyPresses {
    var forward = false
    var backward = false
    var left = false
    var right = false

    var rotateRight = false
    var rotateLeft = false
    var rotateUp = false
    var rotateDown = false

    func update(virtualCamera: VirtualCamera, duration: CFTimeInterval) {
        let verticalDelta = 2.0 /* rad per s */ * duration
        let horizontalDelta = 2.0 /* rad per s */ * duration
        let positionDelta = 2.0 /* m per s */ * duration

        if rotateRight {
            virtualCamera.longitude -= horizontalDelta
        } else if rotateLeft {
            virtualCamera.longitude += horizontalDelta
        }

        let right = Vector3(x: 0, y: 0, z: 1)
        let up = Vector3(x: 0, y: 1, z: 0)

        let right2 = (Double(cos(virtualCamera.longitude)) * right) + (Double(sin(virtualCamera.longitude)) * (up.cross(right)))

        if rotateUp {
            virtualCamera.latitude += verticalDelta
            virtualCamera.latitude = min(virtualCamera.latitude, .pi/2.0)
        } else if rotateDown {
            virtualCamera.latitude -= verticalDelta
            virtualCamera.latitude = max(virtualCamera.latitude, -.pi/2.0)
        }

        let up2 = (Double(cos(virtualCamera.latitude)) * up) + (Double(sin(virtualCamera.latitude)) * (right2.cross(up)))
        let forward2 = up2.cross(right2)

        virtualCamera.up = up2
        virtualCamera.right = right2
        virtualCamera.forward = forward2

        if forward {
            virtualCamera.position = virtualCamera.position + (virtualCamera.forward * positionDelta)
        } else if backward {
            virtualCamera.position = virtualCamera.position - (virtualCamera.forward * positionDelta)
        }

        if self.right {
            virtualCamera.position = virtualCamera.position + (virtualCamera.right * positionDelta)
        } else if left {
            virtualCamera.position = virtualCamera.position - (virtualCamera.right * positionDelta)
        }
    }
}

final class VirtualCamera {
    var position = Vector3(x: 0, y: 1.5, z: 0)

    var latitude = 0.0
    var longitude = 0.0

    var up = Vector3(x: 0, y: 1, z: 0)
    var forward = Vector3(x: 0, y: 0, z: -1)
    var right = Vector3(x: 1, y: 0, z: 0)

    var pose: Pose {
        let rotation = SCNMatrix4(
            m11: Float(right.x),
            m12: Float(right.y),
            m13: Float(right.z),
            m14: 0.0,
            m21: Float(up.x),
            m22: Float(up.y),
            m23: Float(up.z),
            m24: 0.0,
            m31: Float(-forward.x),
            m32: Float(-forward.y),
            m33: Float(-forward.z),
            m34: 0.0,
            m41: 0.0,
            m42: 0.0,
            m43: 0.0,
            m44: 1.0
        )

        return Pose(
            position: position,
            rotation: Quaternion(rotationMatrix: rotation)
        )
    }
}
