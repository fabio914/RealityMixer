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
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var optionsContainer: UIView!
    @IBOutlet private weak var sceneView: ARSCNView!
    private var textureCache: CVMetalTextureCache?
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
        configuration: MixedRealityConfiguration
    ) {
        self.client = client
        self.configuration = configuration
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDisplay()
        configureAudio()
        configureDisplayLink()
        configureOculusMRC()
        configureScene()
        configureTap()
        configureBackgroundEvent()
    }

    private func configureDisplay() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func configureAudio() {
        guard configuration.enableAudio else { return }

        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) else {
            return
        }

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
        self.oculusMRC = OculusMRC(audio: configuration.enableAudio)
        oculusMRC?.delegate = self
    }

    private func configureScene() {
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.session.delegate = self

        if case .visible = configuration.backgroundVisibility {
            sceneView.pointOfView?.addChildNode(makePlane(size: .init(width: 9999, height: 9999), distance: 120))
        }

        if let metalDevice = sceneView.device {
            let result = CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                metalDevice,
                nil,
                &textureCache
            )

            if result != kCVReturnSuccess {
                print("Unable to create metal texture cache!")
            }
        }
    }

    private func configureTap() {
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAction)))
    }

    private func configureBackgroundEvent() {
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    private func planeSizeForDistance(_ distance: Float, frame: ARFrame) -> CGSize {
        let projection = frame.camera.projectionMatrix
        let yScale = projection[1,1]
        let imageResolution = frame.camera.imageResolution
        let width = (2.0 * distance) * tan(atan(1/yScale) * Float(imageResolution.width / imageResolution.height))

        // Assuming the same aspect ratio as the camera (this might be different if the Quest was
        // calibrated with the PC app)
        let height = width * Float(imageResolution.height / imageResolution.width)
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
        if case .hidden = configuration.backgroundVisibility { return }
        let backgroundPlaneNode = makePlaneNodeForDistance(100.0, frame: frame)

        // Flipping image
        if configuration.shouldFlipOutput {
            backgroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform
            backgroundPlaneNode.geometry?.firstMaterial?.transparent.contentsTransform = flipTransform
        }

        backgroundPlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        let surfaceShader = { () -> String in
            switch configuration.backgroundVisibility {
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

    private func configureForeground(with frame: ARFrame) {
        let foregroundPlaneNode = makePlaneNodeForDistance(0.1, frame: frame)

        // Flipping image
        if configuration.shouldFlipOutput {
            foregroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = flipTransform
            foregroundPlaneNode.geometry?.firstMaterial?.transparent.contentsTransform = flipTransform
        }

        foregroundPlaneNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        if configuration.shouldUseMagentaAsTransparency {
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = self.configuration.enableAutoFocus

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        } else {
            let parentViewController = presentingViewController

            invalidate()
            dismiss(animated: true, completion: { [weak parentViewController] in

                let alert = UIAlertController(title: "Sorry", message: "Mixed Reality capture requires a device with an A12 chip or newer.", preferredStyle: .alert)

                alert.addAction(.init(title: "OK", style: .default, handler: nil))

                parentViewController?.present(alert, animated: true, completion: nil)
            })
            return
        }

        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @objc func update(with sender: CADisplayLink) {
        receiveData()
        oculusMRC?.update()
    }

    // MARK: - Helpers

    private func receiveData() {
        while let data = client.read(65536, timeout: 0), data.count > 0 {
            oculusMRC?.addData(data, length: Int32(data.count))
        }
    }

    private func texture(from pixelBuffer: CVPixelBuffer, format: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
        guard let textureCache = textureCache,
              planeIndex >= 0, planeIndex < CVPixelBufferGetPlaneCount(pixelBuffer),
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        else {
            return nil
        }

        var texture: MTLTexture?

        let width =  CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var textureRef : CVMetalTexture?

        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            format,
            width,
            height,
            planeIndex,
            &textureRef
        )

        if result == kCVReturnSuccess, let textureRef = textureRef {
            texture = CVMetalTextureGetTexture(textureRef)
        }

        return texture
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
        let luma = texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0)
        let chroma = texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1)

        backgroundNode?.geometry?.firstMaterial?.transparent.contents = luma
        backgroundNode?.geometry?.firstMaterial?.diffuse.contents = chroma

        foregroundNode?.geometry?.firstMaterial?.transparent.contents = luma
        foregroundNode?.geometry?.firstMaterial?.diffuse.contents = chroma
    }

    func oculusMRC(_ oculusMRC: OculusMRC, didReceiveAudio audio: AVAudioPCMBuffer) {
        audioPlayer?.scheduleBuffer(audio, completionHandler: nil)
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
