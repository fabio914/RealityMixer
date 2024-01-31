////
////  ChromaKeyConfigurationViewModel.swift
////  RealityMixerMac
////
////  Created by Fabio Dela Antonio on 06/07/2022.
////
//
//import SwiftUI
//import SceneKit
//import AVFoundation
//import RealityMixerKit
//
//struct ChromaKeyReadyState {
//    let scene: SCNScene
//    let pointOfView: SCNNode
//    let rendererDelegate: WeakSCNSceneRendererDelegate
//    let sensitivity: Float
//    let smoothness: Float
//    let color: NSColor
//    let hasMask: Bool
//}
//
//final class WeakSCNSceneRendererDelegate {
//    weak var delegate: SCNSceneRendererDelegate?
//
//    init(delegate: SCNSceneRendererDelegate) {
//        self.delegate = delegate
//    }
//}
//
//enum ChromaKeyState {
//    case loading
//    case error
//    case notAuthorized
//    case ready(ChromaKeyReadyState)
//}
//
//final class ChromaKeyConfigurationViewModel: NSObject, ChromaKeyConfigurationViewModelProtocol {
//    @Published var state: ChromaKeyState = .loading
//
//    private let device: AVCaptureDevice?
//    private var cameraSession: CameraSession?
//
//    private var chromaConfigurationStorage: ChromaKeyConfigurationStorage?
//    private var maskStorage: ChromaKeyMaskStorage?
//
//    private let defaultChromaKeyColor = NSColor(red: 0, green: 1, blue: 0, alpha: 1)
//    private let defaultSensitivity: Float = 0.15
//    private let defaultSmoothness: Float = 0
//
//    private var imageSize: CGSize?
//
//    private var isSceneInitialized = false
//    private let scene: SCNScene
//    private let pointOfView: SCNNode
//    private var chromaColor: NSColor
//    private var maskImage: NSImage?
//    private var sensitivity: Float
//    private var smoothness: Float
//
//    private var textureCache: CVMetalTextureCache?
//    private var backgroundPlaneNode: SCNNode?
//    private var planeNode: SCNNode?
//
//    private let onNavigateBack: () -> Void
//
//    init(device: AVCaptureDevice?, onNavigateBack: @escaping () -> Void) {
//        self.device = device
//        self.onNavigateBack = onNavigateBack
//
//        self.chromaColor = defaultChromaKeyColor
//        self.sensitivity = defaultSensitivity
//        self.smoothness = defaultSmoothness
//
//        self.scene = SCNScene()
//
//        let camera = SCNCamera()
//        camera.usesOrthographicProjection = true
//        camera.orthographicScale = 1
//
//        let cameraNode = SCNNode()
//        cameraNode.camera = camera
//        cameraNode.position = .init(0, 0, 0)
//        self.pointOfView = cameraNode
//        self.scene.rootNode.addChildNode(cameraNode)
//    }
//
//    func onAppear() {
//        guard case .loading = state else {
//            return
//        }
//
//        guard let device = device else {
//            self.state = .error
//            return
//        }
//
//        do {
//            self.cameraSession = try CameraSession(device: device, delegate: self)
//            cameraSession?.startRunning()
//        } catch CameraSessionError.notAuthorized {
//            self.state = .notAuthorized
//        } catch {
//            self.state = .error
//        }
//    }
//
//    private func initializeConfiguration(device: AVCaptureDevice) {
//        self.chromaConfigurationStorage = ChromaKeyConfigurationStorage(device.uniqueID)
//        self.maskStorage = ChromaKeyMaskStorage(device.uniqueID)
//
//        if let currentConfiguration = chromaConfigurationStorage?.configuration {
//            sensitivity = currentConfiguration.sensitivity
//            smoothness = currentConfiguration.smoothness
//            chromaColor = currentConfiguration.color.nsColor
//        }
//
//        self.maskImage = maskStorage?.load()
//
//        self.state = .ready(
//            .init(
//                scene: scene,
//                pointOfView: pointOfView,
//                rendererDelegate: .init(delegate: self),
//                sensitivity: sensitivity,
//                smoothness: smoothness,
//                color: chromaColor,
//                hasMask: (maskImage != nil)
//            )
//        )
//    }
//
//    private func initializeScene(renderer: SCNSceneRenderer, imageSize: CGSize) {
//        guard let metalDevice = renderer.device else {
//            self.state = .error
//            return
//        }
//
//        SceneKitHelpers.create(textureCache: &textureCache, forDevice: metalDevice)
//
//        let planeSize: CGSize = {
//            if imageSize.width > imageSize.height {
//                return CGSize(width: 2 * (imageSize.width/imageSize.height), height: 2)
//            } else {
//                return CGSize(width: 2, height: 2 * (imageSize.height/imageSize.width))
//            }
//        }()
//
//        configureBackgroundPlane(with: imageSize, planeSize: planeSize)
//        configurePlane(with: planeSize)
//        didUpdateValues()
//
//        isSceneInitialized = true
//    }
//
//    private func configureBackgroundPlane(with imageSize: CGSize, planeSize: CGSize) {
//        let backgroundPlaneNode = SceneKitHelpers.makePlane(size: planeSize, distance: 1)
//
//        let planeMaterial = backgroundPlaneNode.geometry?.firstMaterial
//        planeMaterial?.lightingModel = .constant
//        planeMaterial?.diffuse.contents = NSImage(named: "tile")
//
//        let repeatX = (imageSize.width/6.4).rounded()
//        let repeatY = (imageSize.height/6.4).rounded()
//        planeMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatX, repeatY, 0)
//
//        planeMaterial?.diffuse.wrapS = SCNWrapMode.repeat
//        planeMaterial?.diffuse.wrapT = SCNWrapMode.repeat
//
//        scene.rootNode.addChildNode(backgroundPlaneNode)
//        self.backgroundPlaneNode = backgroundPlaneNode
//    }
//
//    private func configurePlane(with planeSize: CGSize) {
//        let planeNode = SceneKitHelpers.makePlane(size: planeSize, distance: 0.1)
//        planeNode.geometry?.firstMaterial?.lightingModel = .constant
//        planeNode.geometry?.firstMaterial?.transparencyMode = .rgbZero
//        planeNode.geometry?.firstMaterial?.shaderModifiers = [.surface: Shaders.surfaceChromaKeyConfiguration()]
//        scene.rootNode.addChildNode(planeNode)
//        self.planeNode = planeNode
//    }
//
//    private func updatePlaneImage(with pixelBuffer: CVPixelBuffer) {
//        let luma = SceneKitHelpers.texture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
//        let chroma = SceneKitHelpers.texture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)
//
//        planeNode?.geometry?.firstMaterial?.transparent.contents = luma
//        planeNode?.geometry?.firstMaterial?.diffuse.contents = chroma
//    }
//
//    private func didUpdateValues() {
//        var red: CGFloat = 0
//        var green: CGFloat = 0
//        var blue: CGFloat = 0
//        chromaColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
//
//        if let maskImage = maskImage/*, !isPresentingColorPicker */ {
//            planeNode?.geometry?.firstMaterial?.ambient.contents = maskImage
//        } else {
//            planeNode?.geometry?.firstMaterial?.ambient.contents = NSColor.white
//        }
//
//        planeNode?.geometry?.firstMaterial?.setValue(
//            SCNVector3(red, green, blue),
//            forKey: "maskColor"
//        )
//
////        if isPresentingColorPicker {
////            planeNode?.geometry?.firstMaterial?.setValue(0.0, forKey: "sensitivity")
////            planeNode?.geometry?.firstMaterial?.setValue(0.0, forKey: "smoothness")
////        } else {
//            planeNode?.geometry?.firstMaterial?.setValue(
//                sensitivity,
//                forKey: "sensitivity"
//            )
//
//            planeNode?.geometry?.firstMaterial?.setValue(
//                smoothness,
//                forKey: "smoothness"
//            )
////        }
//    }
//
//    func navigateBack() {
//        onNavigateBack()
//    }
//}
//
//extension ChromaKeyConfigurationViewModel: SCNSceneRendererDelegate {
//
//    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        DispatchQueue.main.async {
//            if !self.isSceneInitialized, let imageSize = self.imageSize {
//                self.initializeScene(renderer: renderer, imageSize: imageSize)
//            }
//        }
//    }
//}
//
//extension ChromaKeyConfigurationViewModel: CameraSessionDelegate {
//
//    func cameraSession(_ cameraSession: CameraSession, didReceiveFrame buffer: CMSampleBuffer) {
//        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
//
//        // Assuming that this size won't change during this session
//        self.imageSize = SceneKitHelpers.size(from: imageBuffer)
//
//        if isSceneInitialized {
//            updatePlaneImage(with: imageBuffer)
//        } else {
//            initializeConfiguration(device: cameraSession.device)
//        }
//    }
//}
