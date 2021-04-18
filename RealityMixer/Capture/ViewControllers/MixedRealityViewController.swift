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

//    private var skeleton: Skeleton?
    private var avatar: Avatar?

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
        cameraPoseSender: CameraPoseSender?
    ) {
        self.client = client
        self.configuration = configuration
        self.cameraPoseSender = cameraPoseSender
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
        sceneView.rendersCameraGrain = false
        sceneView.rendersMotionBlur = false

        // Light for the model
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true

        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.session.delegate = self

        if case .visible = configuration.backgroundLayerOptions.visibility {
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
        if case .hidden = configuration.backgroundLayerOptions.visibility { return }
        let backgroundPlaneNode = makePlaneNodeForDistance(100.0, frame: frame)

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

    private func configureForeground(with frame: ARFrame) {
        guard case .visible(let useMagentaAsTransparency) = configuration.foregroundLayerOptions.visibility else { return }
        let foregroundPlaneNode = makePlaneNodeForDistance(0.1, frame: frame)

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareARConfiguration()
    }

    private func prepareARConfiguration() {
        guard ARBodyTrackingConfiguration.isSupported else {
            return
        }

        let configuration = ARBodyTrackingConfiguration()
        sceneView.session.run(configuration)

//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.horizontal, .vertical]
//        configuration.environmentTexturing = .none
//        configuration.isLightEstimationEnabled = true
//        configuration.isAutoFocusEnabled = self.configuration.enableAutoFocus
//
//        if self.configuration.enablePersonSegmentation {
//            if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
//                configuration.frameSemantics.insert(.personSegmentationWithDepth)
//            } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
//                configuration.frameSemantics.insert(.personSegmentation)
//            }
//        }
//
//        sceneView.session.run(configuration)
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
        } else {
            cameraPoseSender?.didUpdate(frame: frame)
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let bodyAnchor = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }

        if let avatar = avatar {
            avatar.update(bodyAnchor: bodyAnchor)
        } else {
            avatar = Avatar(bodyAnchor: bodyAnchor)
            if let mainNode = avatar?.mainNode {
                sceneView.scene.rootNode.addChildNode(mainNode)
            }
        }
    }
}

struct Avatar {

// The rotations don't match those of ARKit's robot, so the avatar is becoming distorted

    static let nodes: [String: String] = [
//        "root": "Skeleton",
        "hips_joint": "Hips", // 2 nodes with this name...
        "left_upLeg_joint": "LeftUpLeg",
        "left_leg_joint": "LeftLeg",
        "left_foot_joint": "LeftFoot",
        "left_toes_joint": "LeftToeBase",
        "left_toesEnd_joint": "LeftToe_End",
        "right_upLeg_joint": "RightUpLeg",
        "right_leg_joint": "RightLeg",
        "right_foot_joint": "RightFoot",
        "right_toes_joint": "RightToeBase",
        "right_toesEnd_joint": "RightToe_End",
        "spine_1_joint": "Spine",
        "spine_2_joint": "",
        "spine_3_joint": "",
        "spine_4_joint": "",
        "spine_5_joint": "",
        "spine_6_joint": "Spine1",
        "spine_7_joint": "Spine2",
        "right_shoulder_1_joint": "RightShoulder",
        "right_arm_joint": "RightArm",
        "right_forearm_joint": "RightForeArm",
        "right_hand_joint": "RightHand",
        "right_handThumbStart_joint": "RightHandThumb1",
        "right_handThumb_1_joint": "RightHandThumb2",
        "right_handThumb_2_joint": "RightHandThumb3",
        "right_handThumbEnd_joint": "RightHandThumb4",
//        "right_handIndexStart_joint": "",
        "right_handIndex_1_joint": "RightHandIndex1",
        "right_handIndex_2_joint": "RightHandIndex2",
        "right_handIndex_3_joint": "RightHandIndex3",
        "right_handIndexEnd_joint": "RightHandIndex4",
//        "right_handMidStart_joint": "",
        "right_handMid_1_joint": "RightHandMiddle1",
        "right_handMid_2_joint": "RightHandMiddle2",
        "right_handMid_3_joint": "RightHandMiddle3",
        "right_handMidEnd_joint": "RightHandMiddle4",
//        "right_handRingStart_joint": "",
        "right_handRing_1_joint": "RightHandRing1",
        "right_handRing_2_joint": "RightHandRing2",
        "right_handRing_3_joint": "RightHandRing3",
        "right_handRingEnd_joint": "RightHandRing4",
//        "right_handPinkyStart_joint": "",
        "right_handPinky_1_joint": "RightHandPinky1",
        "right_handPinky_2_joint": "RightHandPinky2",
        "right_handPinky_3_joint": "RightHandPinky3",
        "right_handPinkyEnd_joint": "RightHandPinky4",
        "left_shoulder_1_joint": "LeftShoulder",
        "left_arm_joint": "LeftArm",
        "left_forearm_joint": "LeftForeArm",
        "left_hand_joint": "LeftHand",
        "left_handThumbStart_joint": "LeftHandThumb1",
        "left_handThumb_1_joint": "LeftHandThumb2",
        "left_handThumb_2_joint": "LeftHandThumb3",
        "left_handThumbEnd_joint": "LeftHandThumb4",
//        "left_handIndexStart_joint": "",
        "left_handIndex_1_joint": "LeftHandIndex1",
        "left_handIndex_2_joint": "LeftHandIndex2",
        "left_handIndex_3_joint": "LeftHandIndex3",
        "left_handIndexEnd_joint": "LeftHandIndex4",
//        "left_handMidStart_joint": "",
        "left_handMid_1_joint": "LeftHandMiddle1",
        "left_handMid_2_joint": "LeftHandMiddle2",
        "left_handMid_3_joint": "LeftHandMiddle3",
        "left_handMidEnd_joint": "LeftHandMiddle4",
//        "left_handRingStart_joint": "",
        "left_handRing_1_joint": "LeftHandRing1",
        "left_handRing_2_joint": "LeftHandRing2",
        "left_handRing_3_joint": "LeftHandRing3",
        "left_handRingEnd_joint": "LeftHandRing4",
//        "left_handPinkyStart_joint": "",
        "left_handPinky_1_joint": "LeftHandPinky1",
        "left_handPinky_2_joint": "LeftHandPinky2",
        "left_handPinky_3_joint": "LeftHandPinky3",
        "left_handPinkyEnd_joint": "LeftHandPinky4",
        "head_joint": "Head",
//        "jaw_joint": "",
//        "chin_joint": "",
//        "nose_joint": "",
        "right_eye_joint": "RightEye",
//        "right_eyeUpperLid_joint": "",
//        "right_eyeLowerLid_joint": "",
//        "right_eyeball_joint": "",
        "left_eye_joint": "LeftEye",
//        "left_eyeUpperLid_joint": "",
//        "left_eyeLowerLid_joint": "",
//        "left_eyeball_joint": "",
//        "neck_1_joint": "",
//        "neck_2_joint": "",
        "neck_3_joint": "Neck",
//        "neck_4_joint": ""
    ]

    static func node(forJoint jointName: String) -> String? {
        nodes[jointName]
    }

    private(set) var mainNode: SCNNode
    private let corrections: [String: Quaternion]

    init?(bodyAnchor: ARBodyAnchor) {

        let maybeAvatarReferenceNode = Bundle.main
            .url(forResource: "tpose", withExtension: "usdz")
            .flatMap(SCNReferenceNode.init(url:))

        let maybeRobotReferenceNode = Bundle.main
            .url(forResource: "robot", withExtension: "usdz")
            .flatMap(SCNReferenceNode.init(url:))

        guard let avatarNode = maybeAvatarReferenceNode,
            let robotNode = maybeRobotReferenceNode
        else {
            return nil
        }

        avatarNode.load()
        robotNode.load()

        guard let skeletonNode = avatarNode.childNode(withName: "Skeleton", recursively: true),
            let hipsNode = skeletonNode.childNode(withName: "Hips", recursively: false)
        else {
            return nil
        }

        hipsNode.transform = SCNMatrix4(bodyAnchor.transform)

        let skeleton = bodyAnchor.skeleton
        let jointLocalTransforms = skeleton.jointLocalTransforms

        var corrections: [String: Quaternion] = [:]

        for (i, _) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            guard parentIndex != -1,
                jointName != "root",
                jointName != "hips_joint",
                let avatarNodeName = Avatar.node(forJoint: jointName),
                let avatarNode = hipsNode.childNode(withName: avatarNodeName, recursively: true),
                let referenceNode = robotNode.childNode(withName: jointName, recursively: true)
            else {
                continue
            }

//            corrections[jointName] = Quaternion(rotationMatrix: referenceNode.transform).inverse * Quaternion(rotationMatrix: avatarNode.transform)
            corrections[jointName] = Quaternion(rotationMatrix: avatarNode.transform) * Quaternion(rotationMatrix: referenceNode.transform).inverse
        }

        self.corrections = corrections

        for (i, jointLocalTransform) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            guard parentIndex != -1,
                jointName != "root",
                jointName != "hips_joint",
                let nodeName = Avatar.node(forJoint: jointName),
                let node = hipsNode.childNode(withName: nodeName, recursively: true),
                let correction = corrections[jointName]
            else {
                continue
            }

//            let correctedOrientation = Quaternion(rotationMatrix: SCNMatrix4(jointLocalTransform)) * correction
            let correctedOrientation = correction * Quaternion(rotationMatrix: SCNMatrix4(jointLocalTransform))

            node.orientation = SCNQuaternion(correctedOrientation.x, correctedOrientation.y, correctedOrientation.z, correctedOrientation.w)

//            node.position = SCNVector3(simd_make_float3(jointLocalTransform.columns.3))
        }

        mainNode = avatarNode
    }

    func update(bodyAnchor: ARBodyAnchor) {
        guard let skeletonNode = mainNode.childNode(withName: "Skeleton", recursively: true),
            let hipsNode = skeletonNode.childNode(withName: "Hips", recursively: false)
        else {
            return
        }

        hipsNode.transform = SCNMatrix4(bodyAnchor.transform)

        let skeleton = bodyAnchor.skeleton
        let jointLocalTransforms = skeleton.jointLocalTransforms

        for (i, jointLocalTransform) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            guard parentIndex != -1,
                jointName != "root",
                jointName != "hips_joint",
                let nodeName = Avatar.node(forJoint: jointName),
                let node = hipsNode.childNode(withName: nodeName, recursively: true),
                let correction = corrections[jointName]
            else {
                continue
            }

//            let correctedOrientation = Quaternion(rotationMatrix: SCNMatrix4(jointLocalTransform)) * correction
            let correctedOrientation = correction * Quaternion(rotationMatrix: SCNMatrix4(jointLocalTransform))

            node.orientation = SCNQuaternion(correctedOrientation.x, correctedOrientation.y, correctedOrientation.z, correctedOrientation.w)

//            node.position = SCNVector3(simd_make_float3(jointLocalTransform.columns.3))
        }
    }
}
