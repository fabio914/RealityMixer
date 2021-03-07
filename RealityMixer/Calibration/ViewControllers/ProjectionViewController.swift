//
//  ProjectionViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit
import ARKit

protocol ProjectionViewControllerDelegate: AnyObject {
    func projection(_ viewController: ProjectionViewController, didFinishWithCalibration: CalibrationResult, transform: SCNMatrix4)
    func projectionDidCancel(_ viewController: ProjectionViewController)
}

final class ProjectionViewController: UIViewController {
    weak var delegate: ProjectionViewControllerDelegate?
    
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var calibrationView: UIView!
    @IBOutlet private weak var adjustDistanceButtonContainer: UIView!
    @IBOutlet private weak var adjustDistanceContainer: UIView!
    @IBOutlet private weak var distanceLabel: UILabel!
    @IBOutlet private weak var instructionsOverlayView: UIView!

    private var projectionPickerViewController: ProjectionPickerViewController

    init(
        scaleFactor: Double,
        cameraOrigin: Vector3,
        rightControllerPosition: Vector3,
        frame: ARFrame,
        lastPoseUpdate: PoseUpdate,
        delegate: ProjectionViewControllerDelegate
    ) {
        self.projectionPickerViewController = ProjectionPickerViewController(
            scaleFactor: scaleFactor,
            cameraOrigin: cameraOrigin,
            rightControllerPosition: rightControllerPosition,
            frame: frame,
            lastPoseUpdate: lastPoseUpdate
        )
        self.delegate = delegate
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        
        addChild(projectionPickerViewController)

        projectionPickerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        calibrationView.addSubview(projectionPickerViewController.view)

        NSLayoutConstraint.activate([
            projectionPickerViewController.view.topAnchor.constraint(equalTo: calibrationView.topAnchor),
            projectionPickerViewController.view.bottomAnchor.constraint(equalTo: calibrationView.bottomAnchor),
            projectionPickerViewController.view.leadingAnchor.constraint(equalTo: calibrationView.leadingAnchor),
            projectionPickerViewController.view.trailingAnchor.constraint(equalTo: calibrationView.trailingAnchor)
        ])

        projectionPickerViewController.didMove(toParent: self)
        projectionPickerViewController.delegate = self
    }

    @IBAction private func distanceAdjustmentChanged(_ sender: UISlider) {
        let distanceAdjustment = Double(sender.value)
        distanceLabel?.text = String(format: "%.1f cm", distanceAdjustment * 100.0)
        projectionPickerViewController.distanceAdjustment = distanceAdjustment
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
        guard let currentResult = projectionPickerViewController.currentResult else { return }
        delegate?.projection(self, didFinishWithCalibration: currentResult.1, transform: currentResult.0)
    }

    @IBAction private func cancel() {
        delegate?.projectionDidCancel(self)
    }
}

extension ProjectionViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        calibrationView
    }
}

extension ProjectionViewController: ProjectionPickerViewControllerDelegate {

    func disableScrolling() {
        scrollView.pinchGestureRecognizer?.isEnabled = false
        scrollView.panGestureRecognizer.isEnabled = false
    }
    
    func enableScrolling() {
        scrollView.pinchGestureRecognizer?.isEnabled = true
        scrollView.panGestureRecognizer.isEnabled = true
    }
}
