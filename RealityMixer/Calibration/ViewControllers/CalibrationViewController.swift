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

protocol CalibrationViewControllerDelegate: AnyObject {
    func calibrationDidCancel(_ viewController: CalibrationViewController)
    func calibrationDidFinish(_ viewController: CalibrationViewController)
}

final class CalibrationViewController: UIViewController {
    weak var delegate: CalibrationViewControllerDelegate?
    private let scaleFactor: Double
    private let client: TCPClient
    private var displayLink: CADisplayLink?
    private let oculusCalibration = OculusCalibration()

    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var saveButtonContainer: UIView!
    @IBOutlet private weak var pauseView: UIView!
    @IBOutlet private weak var infoLabel: UILabel!

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
            pauseView.isHidden = !isPaused
        }
    }

    private var first = true

    private var state: CalibrationState = .started {
        didSet {
            didUpdate(state)
        }
    }

    init(client: TCPClient, scaleFactor: Double, delegate: CalibrationViewControllerDelegate?) {
        self.client = client
        self.scaleFactor = scaleFactor
        self.delegate = delegate
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
        configureBackgroundEvent()
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

    private func configureBackgroundEvent() {
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
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
            saveButtonContainer.isHidden = true

            sceneView.scene.rootNode.enumerateChildNodes({ (node, _) in node.removeFromParentNode() })
            sceneView.pointOfView?.enumerateChildNodes({ (node, _) in node.removeFromParentNode() })

            updateInfo("Step 1 of 4: Put your headset on, face the camera, and move your right controller's trigger button as close as possible to the device's camera, then press the \"A\" button or the right controller's trigger button.")
        case .cameraOriginSet:
            saveButtonContainer.isHidden = true
            updateInfo("Step 2 of 4: Put your headset on, move 1.5 meters (5 feet) away from the camera, face the camera, stay still and then press the \"A\" button or the right controller's trigger button.")
        case .controllerPositionSet(
            let cameraOrigin,
            let rightControllerPosition,
            let poseUpdate,
            let frame
        ):
            saveButtonContainer.isHidden = true
            updateInfo("Step 3 of 4")

            let viewController = ProjectionViewController(
                scaleFactor: scaleFactor,
                cameraOrigin: cameraOrigin,
                rightControllerPosition: rightControllerPosition,
                frame: frame,
                lastPoseUpdate: poseUpdate,
                delegate: self
            )

            viewController.isModalInPresentation = true
            viewController.modalPresentationStyle = .overFullScreen
            viewController.modalTransitionStyle = .crossDissolve

            present(viewController, animated: true, completion: nil)
        case .calibrationSet(let transform, _):
            saveButtonContainer.isHidden = false
            updateInfo("Step 4 of 4: Review your calibration and tap on \"Save to Headset\" to save it. ")

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

    private func updateInfo(_ text: String) {
        infoLabel.text = "\(text)\n\nRemember: Do not move this device during and after the calibration. Press \"B\" at any moment to cancel and go back to the first step."
    }

    // MARK: - Actions

    private func reset() {
        self.state = .started
    }

    private func disconnect() {
        displayLink?.invalidate()
        delegate?.calibrationDidCancel(self)
    }

    @objc private func willResignActive() {
        disconnect()
    }

    @IBAction func disconnectAction(_ sender: Any) {
        disconnect()
    }

    @IBAction private func saveAction(_ sender: Any) {
        guard case .calibrationSet(_, let calibration) = state else { return }

        guard let data = calibration.toFrame()?.toData() else {
            let alert = UIAlertController(title: "Error", message: "Unable to generate calibration data.", preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }

        switch client.send(data: data) {
        case .failure(let error):
            let alert = UIAlertController(title: "Error", message: "Unable to save calibration: \(error)", preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        case .success:
            let alert = UIAlertController(title: "Calibration Saved!", message: "You can now close the Oculus Mixed Reality Capture Calibration app and launch your VR application/game.", preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                self.displayLink?.invalidate()
                self.delegate?.calibrationDidFinish(self)
            }))
            present(alert, animated: true, completion: nil)
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
        guard !isPaused else { return }

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
            leftControllerNode?.position = .init(leftHand.position)
            leftControllerNode?.eulerAngles = .init(leftHand.rotation.eulerAngles)
        }

        if let rightHand = pose.rightHand {
            rightControllerNode?.position = .init(rightHand.position)
            rightControllerNode?.eulerAngles = .init(rightHand.rotation.eulerAngles)
        }

        headsetNode?.position = .init(pose.head.position)
        headsetNode?.eulerAngles = .init(pose.head.rotation.eulerAngles)
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
