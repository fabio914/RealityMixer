//
//  CalibrationViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit
import ARKit
import SwiftSocket

enum CalibrationState {
    case started
    case cameraOriginSet(_ cameraOrigin: Vector3)
    case controllerPositionSet(
        _ cameraOrigin: Vector3,
        _ rightControllerPosition: Vector3,
        _ poseUpdate: PoseUpdate,
        _ frame: ARFrame
    )
    case calibrationSet(
        _ transform: SCNMatrix4,
        _ calibration: CalibrationResult
    )
}

final class CalibrationViewController: UIViewController {
    private let scaleFactor: Double
    private let client: TCPClient
    private var displayLink: CADisplayLink?
    private let oculusCalibration = OculusCalibration()

    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var saveButton: UIButton!

    private weak var leftControllerNode: SCNNode?
    private weak var rightControllerNode: SCNNode?
    private weak var headsetNode: SCNNode?

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    private var lastPoseUpdate: PoseUpdate?
    private var isPaused = false {
        didSet {
            // TODO: Update "paused" view
        }
    }

    private var first = true

    private var state: CalibrationState = .started {
        didSet {
            didUpdate(state)
        }
    }

    init(client: TCPClient, scaleFactor: Double) {
        self.client = client
        self.scaleFactor = scaleFactor
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDisplay()
        configureDisplayLink()
        configureCalibrationSource()
        didUpdate(state)
    }

    private func configureDisplay() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func configureDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdate(with:)))
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
    }

    private func configureCalibrationSource() {
        oculusCalibration.delegate = self
    }

    @objc private func displayLinkUpdate(with sender: CADisplayLink) {
        guard let bytes = client.read(65536, timeout: 0),
            bytes.count > 0
        else {
            return
        }

        oculusCalibration.add(data: .init(bytes: bytes, count: bytes.count))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard first else { return }
        first = false

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }

    private func didUpdate(_ state: CalibrationState) {
        print("Current State: \(state)")

        switch state {
        case .started:
            saveButton.isHidden = true
            sceneView.scene = SCNScene()

            // TODO: Tell the user to move the right controller to the camera and press the trigger
        case .cameraOriginSet:
            saveButton.isHidden = true
            // TODO: Tell the user to move farther from the camera and press the trigger
            break
        case .controllerPositionSet(
            let cameraOrigin,
            let rightControllerPosition,
            let poseUpdate,
            let frame
        ):
            saveButton.isHidden = true

            let viewController = ProjectionViewController(
                scaleFactor: scaleFactor,
                cameraOrigin: cameraOrigin,
                rightControllerPosition: rightControllerPosition,
                frame: frame,
                lastPoseUpdate: poseUpdate,
                delegate: self
            )

            let navigationController = UINavigationController(rootViewController: viewController)

            navigationController.isModalInPresentation = true
            navigationController.modalPresentationStyle = .fullScreen

            present(navigationController, animated: true, completion: nil)
        case .calibrationSet(let transform, _):
            saveButton.isHidden = false

            let calibrationSceneNodes = CalibrationSceneNodeBuilder.build()

            let mainNode = calibrationSceneNodes.main
            mainNode.transform = transform

            self.rightControllerNode = calibrationSceneNodes.rightController
            self.leftControllerNode = calibrationSceneNodes.leftController
            self.headsetNode = calibrationSceneNodes.headset

            sceneView.scene = SCNScene()
            sceneView.pointOfView?.addChildNode(mainNode)
        }
    }

    private func reset() {
        self.state = .started
    }

    @IBAction private func saveAction(_ sender: Any) {
        guard case .calibrationSet(_, let calibration) = state else { return }

        guard let data = calibration.toFrame()?.toData() else {
            // TODO: Present alert to warn the user...
            return
        }

        switch client.send(data: data) {
        case .failure(let error):
            // TODO: Present alert to warn the user...
            print("Unable to save calibration: \(error)")
        case .success:
            // TODO: Present alert saying that the calibration was saved!
            print("New calibration saved!")
            dismiss(animated: true, completion: nil)
        }
    }

    deinit {
        client.close()
    }
}

extension CalibrationViewController: OculusCalibrationDelegate {

    func oculusCalibrationDidPause(_ oculusCalibration: OculusCalibration) {
        self.isPaused = true
    }

    func oculusCalibrationDidPressPrimaryButton(_ oculusCalibration: OculusCalibration) {
        switch state {
        case .started:
            if let rightHand = lastPoseUpdate?.rightHand {
                self.state = .cameraOriginSet(rightHand.position)
            }
        case .cameraOriginSet(let cameraOrigin):
            if let poseUpdate = lastPoseUpdate,
               let rightHand = poseUpdate.rightHand,
               let frame = sceneView.session.currentFrame {
                self.state = .controllerPositionSet(
                    cameraOrigin,
                    rightHand.position,
                    poseUpdate,
                    frame
                )
            }
        default:
            break
        }
    }

    func oculusCalibrationDidPressSecondaryButton(_ oculusCalibration: OculusCalibration) {
        if case .controllerPositionSet = state { return }
        reset()
    }

    func oculusCalibration(_ oculusCalibration: OculusCalibration, didUpdatePose pose: PoseUpdate) {
        self.isPaused = false
        self.lastPoseUpdate = pose

        if let leftHand = pose.leftHand {
            leftControllerNode?.position = leftHand.position.sceneKitVector
            leftControllerNode?.eulerAngles = leftHand.rotation.eulerAngles.sceneKitVector
        }

        if let rightHand = pose.rightHand {
            rightControllerNode?.position = rightHand.position.sceneKitVector
            rightControllerNode?.eulerAngles = rightHand.rotation.eulerAngles.sceneKitVector
        }

        headsetNode?.position = pose.head.position.sceneKitVector
        headsetNode?.eulerAngles = pose.head.rotation.eulerAngles.sceneKitVector
    }

    func oculusCalibration(_ oculusCalibration: OculusCalibration, didReceiveCalibrationXMLString xmlString: String) {
    }
}

extension CalibrationViewController: ProjectionViewControllerDelegate {

    func projectionDidCancel(_ viewController: ProjectionViewController) {
        dismiss(animated: true, completion: nil)
        reset()
    }

    func projection(
        _ viewController: ProjectionViewController,
        didFinishWithCalibration calibration: CalibrationResult,
        transform: SCNMatrix4
    ) {
        dismiss(animated: true, completion: nil)
        guard case .controllerPositionSet = state else { return }
        self.state = .calibrationSet(transform, calibration)
    }
}
