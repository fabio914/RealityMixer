//
//  ProjectionViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit
import ARKit

private struct Touch {
    let delta: CGPoint
    let touch: UITouch
}

protocol ProjectionViewControllerDelegate: AnyObject {
    func projection(_ viewController: ProjectionViewController, didFinishWithCalibration: CalibrationResult, transform: SCNMatrix4)
    func projectionDidCancel(_ viewController: ProjectionViewController)
}

final class ProjectionViewController: UIViewController {
    weak var delegate: ProjectionViewControllerDelegate?
    private let scaleFactor: Double
    private let cameraOrigin: Vector3
    private let rightControllerPosition: Vector3
    private let frame: ARFrame

    private let lastPoseUpdate: PoseUpdate

    private var image: UIImage {
        UIImage(ciImage: CIImage(cvImageBuffer: frame.capturedImage))
    }

    @IBOutlet private weak var calibrationView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var sceneOverlay: SCNView!
    @IBOutlet private weak var blueView: UIView!

    @IBOutlet private weak var adjustDistanceButtonContainer: UIView!
    @IBOutlet private weak var adjustDistanceContainer: UIView!
    @IBOutlet private weak var distanceLabel: UILabel!

    @IBOutlet private weak var instructionsOverlayView: UIView!

    private weak var mainNode: SCNNode?

    private let radius = CGFloat(20)
    private var currentTouch: Touch?

    private var currentResult: (SCNMatrix4, CalibrationResult)?

    private var distanceAdjustment: Double = 0.0 {
        didSet {
            distanceLabel?.text = String(format: "%.1f cm", distanceAdjustment * 100.0)
            updateTransform()
        }
    }

    private var blueViewCenter: CGPoint = .init(x: 30, y: 30) {
        didSet {
            updateTransform()
        }
    }

    init(
        scaleFactor: Double,
        cameraOrigin: Vector3,
        rightControllerPosition: Vector3,
        frame: ARFrame,
        lastPoseUpdate: PoseUpdate,
        delegate: ProjectionViewControllerDelegate
    ) {
        self.scaleFactor = scaleFactor
        self.cameraOrigin = cameraOrigin
        self.rightControllerPosition = rightControllerPosition
        self.frame = frame
        self.lastPoseUpdate = lastPoseUpdate
        self.delegate = delegate
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
        buildScene()
    }

    private func buildScene() {
        let scene = SCNScene()
        let calibrationSceneNodes = CalibrationSceneNodeBuilder.build()

        let leftControllerNode = calibrationSceneNodes.leftController
        let rightControllerNode = calibrationSceneNodes.rightController
        let headsetNode = calibrationSceneNodes.headset

        let mainNode = calibrationSceneNodes.main
        self.mainNode = mainNode

        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100.0
        let (xFov, yFov) = CalibrationBuilder.fov(from: frame)

        let imageViewRatio = imageView.frame.size.width/imageView.frame.size.height
        let imageRatio = frame.camera.imageResolution.width/frame.camera.imageResolution.height

        if imageViewRatio > imageRatio {
            camera.projectionDirection = .vertical
            camera.fieldOfView = CGFloat(yFov * (180.0/Float.pi))
        } else {
            camera.projectionDirection = .horizontal
            camera.fieldOfView = CGFloat(xFov * (180.0/Float.pi))
        }

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.addChildNode(mainNode)
        scene.rootNode.addChildNode(cameraNode)

        if let leftHand = lastPoseUpdate.leftHand {
            leftControllerNode.position = leftHand.position.sceneKitVector
            leftControllerNode.eulerAngles = leftHand.rotation.eulerAngles.sceneKitVector
        }

        if let rightHand = lastPoseUpdate.rightHand {
            rightControllerNode.position = rightHand.position.sceneKitVector
            rightControllerNode.eulerAngles = rightHand.rotation.eulerAngles.sceneKitVector
        }

        headsetNode.position = lastPoseUpdate.head.position.sceneKitVector
        headsetNode.eulerAngles = lastPoseUpdate.head.rotation.eulerAngles.sceneKitVector
        sceneOverlay.scene = scene
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        for touch in touches {
            let location = touch.location(in: calibrationView)
            let viewCenter = blueView.center

            guard viewCenter.distance(to: location) < radius * 2.0,
                currentTouch == nil
            else { continue }

            currentTouch = .init(delta: viewCenter - location, touch: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        for touch in touches {
            let location = touch.location(in: calibrationView)
            guard let currentTouch = currentTouch, currentTouch.touch === touch else { continue }
            blueViewCenter = location + currentTouch.delta
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentTouch = nil
    }

    @IBAction private func distanceAdjustmentChanged(_ sender: UISlider) {
        distanceAdjustment = Double(sender.value)
    }

    @IBAction private func hideInstructionsAction(_ sender: UIButton) {
        sender.isUserInteractionEnabled = false

        UIView.animateKeyframes(
            withDuration: 0.2,
            delay: 0,
            animations: { [weak self] in
                self?.instructionsOverlayView.alpha = 0
            },
            completion: { [weak self] _ in
                self?.instructionsOverlayView.isHidden = true
            }
        )
    }

    @IBAction private func showDistanceAdjustmentAction(_ sender: UIButton) {
        adjustDistanceButtonContainer.isHidden = true
        adjustDistanceContainer.isHidden = false
    }

    @IBAction private func done() {
        guard let currentResult = currentResult else { return }
        delegate?.projection(self, didFinishWithCalibration: currentResult.1, transform: currentResult.0)
    }

    @IBAction private func cancel() {
        delegate?.projectionDidCancel(self)
    }

    private func updateTransform() {
        let vector = (rightControllerPosition - cameraOrigin)
        let direction = vector.normalized
        let distance = vector.norm

        let newCameraOrigin = rightControllerPosition - ((distance + distanceAdjustment) * direction)

        let calibration = CalibrationBuilder.buildCalibration(
            scaleFactor: scaleFactor,
            cameraOrigin: newCameraOrigin,
            rightControllerPosition: rightControllerPosition,
            rightControllerScreenCoordinates: pixelCoordinate(from: blueViewCenter),
            centerPose: lastPoseUpdate.trackingTransformRaw,
            frame: frame
        )

        mainNode?.transform = calibration.0
        self.currentResult = calibration
        blueView?.center = blueViewCenter
    }

    // Using Aspect Fill
    private func pixelCoordinate(from viewCoordinate: CGPoint) -> CGPoint {

        let imageViewRatio = imageView.frame.size.width/imageView.frame.size.height
        let imageRatio = image.size.width/image.size.height

        if imageViewRatio > imageRatio {
            return CGPoint(
                x: floor(viewCoordinate.x/(imageView.frame.size.width/image.size.width)),
                y: floor(viewCoordinate.y/(imageView.frame.size.width/image.size.width))
            )
        } else if imageViewRatio < imageRatio {
            return CGPoint(
                x: floor(viewCoordinate.x/(imageView.frame.size.height/image.size.height)),
                y: floor(viewCoordinate.y/(imageView.frame.size.height/image.size.height))
            )
        } else {
            return CGPoint(
                x: floor(viewCoordinate.x/(imageView.frame.size.width/image.size.width)),
                y: floor(viewCoordinate.y/(imageView.frame.size.width/image.size.height))
            )
        }
    }
}
