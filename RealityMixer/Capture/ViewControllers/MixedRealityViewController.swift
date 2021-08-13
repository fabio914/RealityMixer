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

//    private var initialAudioTime: UInt64 = 0
    private var currentAudioFormat: AVAudioFormat?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?

    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?
    private var networkThread: Thread?
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

    private func configureAudio(with audioFormat: AVAudioFormat) {
        let audioEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let mainMixerNode = audioEngine.mainMixerNode

        audioEngine.attach(player)
        audioEngine.connect(player, to: mainMixerNode, format: audioFormat)
        audioEngine.prepare()

        do {
            try audioEngine.start()
            player.play()

            audioEngine.mainMixerNode.outputVolume = 1.0
            self.audioEngine = audioEngine
            self.audioPlayer = player
            self.currentAudioFormat = audioFormat
//            self.initialAudioTime = mach_absolute_time()
        } catch {
            print("Unable to start audio: \(error)")
        }
    }

    private func configureDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
    }

    private func configureOculusMRC() {
        self.oculusMRC = OculusMRC()
        oculusMRC?.delegate = self

        networkThread = Thread(block: { [weak oculusMRC, weak client] in
            let thread = Thread.current
            while !thread.isCancelled {
                while let data = client?.read(65536, timeout: 0), data.count > 0, !thread.isCancelled {
                    oculusMRC?.addData(data, length: Int32(data.count))
                }
            }
         })

         networkThread?.start()
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

    private func configureBackground(with frame: ARFrame) {
        if case .hidden = configuration.backgroundLayerOptions.visibility { return }
        let backgroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(100.0, frame: frame)

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

    private func configureMiddle(with frame: ARFrame) {
        guard case .greenScreen = configuration.captureMode,
            let chromaConfiguration = chromaConfiguration
        else { return }
        let middlePlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.02, frame: frame)

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

    private func configureForeground(with frame: ARFrame) {
        guard case .visible(let useMagentaAsTransparency) = configuration.foregroundLayerOptions.visibility else { return }
        let foregroundPlaneNode = ARKitHelpers.makePlaneNodeForDistance(0.01, frame: frame)

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
        oculusMRC?.update()

        if let lastFrame = lastFrame {
            updateForegroundBackground(with: lastFrame)
        }
    }

    // MARK: - Actions

    @objc private func tapAction() {
        optionsContainer.isHidden = !optionsContainer.isHidden
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
        optionsContainer.isHidden = true
    }

    func invalidate() {
        networkThread?.cancel()
        audioPlayer?.stop()
        audioEngine?.stop()
        displayLink?.invalidate()
        client.close()
    }

    deinit {
        invalidate()
    }
}

extension MixedRealityViewController: OculusMRCDelegate {

    func oculusMRC(_ oculusMRC: OculusMRC, didReceive pixelBuffer: CVPixelBuffer) {
        lastFrame = pixelBuffer
    }

    func oculusMRC(_ oculusMRC: OculusMRC, didReceiveAudio audio: AVAudioPCMBuffer, timestamp: UInt64) {
        if currentAudioFormat == nil {
            configureAudio(with: audio.format)
        }

        guard let currentAudioFormat = currentAudioFormat,
            audio.format.sampleRate == currentAudioFormat.sampleRate,
            audio.format.channelCount == currentAudioFormat.channelCount
        else {
            print("Unexpected audio format")
            return
        }

        let sampleTime = AVAudioFramePosition(Double(timestamp)/1_000_000 * currentAudioFormat.sampleRate)

        let audioTime = AVAudioTime(
//            hostTime: initialAudioTime,
            sampleTime: sampleTime,
            atRate: currentAudioFormat.sampleRate
        )

        audioPlayer?.scheduleBuffer(audio, at: audioTime, options: .interruptsAtLoop, completionHandler: nil)
    }
}

extension MixedRealityViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        if first {
            configureBackground(with: frame)
            configureMiddle(with: frame)
            configureForeground(with: frame)
            first = false
        } else {
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
