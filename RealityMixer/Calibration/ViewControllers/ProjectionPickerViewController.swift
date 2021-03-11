//
//  ProjectionPickerViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 07/03/2021.
//

import UIKit
import ARKit

private struct Touch {
    let delta: CGPoint
    let touch: UITouch
}

protocol ProjectionPickerViewControllerDelegate: AnyObject {
    func disableScrolling()
    func enableScrolling()
}

final class ProjectionPickerViewController: UIViewController {
    weak var delegate: ProjectionPickerViewControllerDelegate?
    private let scaleFactor: Double
    private let cameraOrigin: Vector3
    private let rightControllerPosition: Vector3
    private let frame: ARFrame
    private let lastPoseUpdate: PoseUpdate

    private var image: UIImage {
        UIImage(ciImage: CIImage(cvImageBuffer: frame.capturedImage))
    }
    
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var sceneOverlay: SCNView!
    @IBOutlet private weak var blueView: UIView!
    
    private weak var mainNode: SCNNode?
    private let radius = CGFloat(20)
    private var currentTouch: Touch?
    
    private(set) var currentResult: (SCNMatrix4, CalibrationResult)?

    var distanceAdjustment: Double = 0.0 {
        didSet {
            updateTransform()
        }
    }

    private var blueViewCenter: CGPoint = .init(x: 30, y: 30) {
        didSet {
            updateTransform()
        }
    }
    
    private var first = true
    
    init(
        scaleFactor: Double,
        cameraOrigin: Vector3,
        rightControllerPosition: Vector3,
        frame: ARFrame,
        lastPoseUpdate: PoseUpdate
    ) {
        self.scaleFactor = scaleFactor
        self.cameraOrigin = cameraOrigin
        self.rightControllerPosition = rightControllerPosition
        self.frame = frame
        self.lastPoseUpdate = lastPoseUpdate
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
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
            let imageHeightInImageViewCoordinates = frame.camera.imageResolution.height * (imageView.frame.size.width/frame.camera.imageResolution.width)
            let distanceInImageViewCoordinates = (imageHeightInImageViewCoordinates * 0.5)/CGFloat(tan(yFov/2.0))
            let adjustedYFov = CGFloat(2.0 * atan2((imageView.frame.size.height * 0.5), distanceInImageViewCoordinates))

            camera.projectionDirection = .vertical
            camera.fieldOfView = (adjustedYFov * (180.0/CGFloat.pi))
        } else {
            let imageWidthInImageViewCoordinates = frame.camera.imageResolution.width * (imageView.frame.size.height/frame.camera.imageResolution.height)
            let distanceInImageViewCoordinates = (imageWidthInImageViewCoordinates * 0.5)/CGFloat(tan(xFov/2.0))
            let adjustedXFov = CGFloat(2.0 * atan2((imageView.frame.size.width * 0.5), distanceInImageViewCoordinates))

            camera.projectionDirection = .horizontal
            camera.fieldOfView = (adjustedXFov * (180.0/CGFloat.pi))
        }

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.addChildNode(mainNode)
        scene.rootNode.addChildNode(cameraNode)

        if let leftHand = lastPoseUpdate.leftHand {
            leftControllerNode.position = .init(leftHand.position)
            leftControllerNode.eulerAngles = .init(leftHand.rotation.eulerAngles)
        }

        if let rightHand = lastPoseUpdate.rightHand {
            rightControllerNode.position = .init(rightHand.position)
            rightControllerNode.eulerAngles = .init(rightHand.rotation.eulerAngles)
        }

        headsetNode.position = .init(lastPoseUpdate.head.position)
        headsetNode.eulerAngles = .init(lastPoseUpdate.head.rotation.eulerAngles)
        sceneOverlay.scene = scene
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        for touch in touches {
            let location = touch.location(in: view)
            let viewCenter = blueView.center

            guard viewCenter.distance(to: location) < radius * 2.0,
                currentTouch == nil
            else { continue }

            currentTouch = .init(delta: viewCenter - location, touch: touch)
            delegate?.disableScrolling()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        for touch in touches {
            let location = touch.location(in: view)
            guard let currentTouch = currentTouch, currentTouch.touch === touch else { continue }
            blueViewCenter = location + currentTouch.delta
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.enableScrolling()
        currentTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.enableScrolling()
        currentTouch = nil
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
            let imageHeightInImageViewCoordinates = image.size.height * (imageView.frame.size.width/image.size.width)
            let offsetY = (imageHeightInImageViewCoordinates - imageView.frame.size.height)/2.0

            return CGPoint(
                x: floor(viewCoordinate.x * (image.size.width/imageView.frame.size.width)),
                y: floor((viewCoordinate.y + offsetY) * (image.size.height/imageHeightInImageViewCoordinates))
            )
        } else if imageViewRatio < imageRatio {
            let imageWidthInImageViewCoordinates = image.size.width * (imageView.frame.size.height/image.size.height)
            let offsetX = (imageWidthInImageViewCoordinates - imageView.frame.size.width)/2.0

            return CGPoint(
                x: floor((viewCoordinate.x + offsetX) * (image.size.width/imageWidthInImageViewCoordinates)),
                y: floor(viewCoordinate.y * (image.size.height/imageView.frame.size.height))
            )
        } else {
            return CGPoint(
                x: floor(viewCoordinate.x * (image.size.width/imageView.frame.size.width)),
                y: floor(viewCoordinate.y * (image.size.height/imageView.frame.size.height))
            )
        }
    }
}
