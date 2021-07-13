//
//  CalibrationConnectionViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit
import SwiftSocket

enum CalibrationType {
    case quick
    case standard
}

final class CalibrationConnectionViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var addressTextField: UITextField!
    @IBOutlet private weak var portTextField: UITextField!

    @IBOutlet private weak var scaleSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var poorPerformanceWarningLabel: UILabel!

    @IBOutlet private weak var calibrationTypeSegmentedControl: UISegmentedControl!

    @IBOutlet private weak var showInstructionsButton: UIButton!
    @IBOutlet private weak var instructionsContainer: UIStackView!
    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var secondInfoLabel: UILabel!
    @IBOutlet private weak var thirdInfoLabel: UILabel!

    private let networkConfigurationStorage = NetworkConfigurationStorage()

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Calibration"
        showInstructionsButton.isHidden = false
        instructionsContainer.isHidden = true

        addressTextField.delegate = self
        portTextField.delegate = self

        if let networkConfiguration = networkConfigurationStorage.configuration {
            addressTextField.text = networkConfiguration.address
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backAction))

        configureInfoLabel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollView.flashScrollIndicators()
    }

    private func configureInfoLabel() {
        infoLabel.text = """
        Before you begin:

         • Make sure that your Quest has the Oculus MRC app version 1.7 installed.
        """

        secondInfoLabel.text = """
         • Make sure that the Quest and this device are both connected to the same WiFi network. A 5 Ghz WiFi is recommended.

         • Make sure that the Reality Mixer app is allowed to access your camera and your local network. It'll ask for permission the first time you launch the calibration or mixed reality, however, you'll need to navigate to the system settings to be able to re-enable these permissions if you haven't given permissions during the first launch.
        """

        thirdInfoLabel.text = """
         • Launch the Oculus MRC app on the Quest.

         • Fill in the Quest's IP Address.

         • Select the resolution scale factor. Smaller factors will result in better performance when playing Quest games in mixed reality.

         • Position this device, using a tripod if possible. Notice that you'll need to calibrate again if you change its position or orientation. The device cannot move during the calibration process. You will also need to recalibrate if you reset the Quest's Guardian boundary.

         • Tap on "Connect".
        """
    }

    private func startConnection(address: String, port: Int32, calibrationType: CalibrationType) {
        let connectionAlert = UIAlertController(title: "Connecting...", message: nil, preferredStyle: .alert)

        present(connectionAlert, animated: true, completion: { [weak self] in
            guard let self = self else { return }

            // FIXME: Do this in a way that doesn't block the main thread

            let client = TCPClient(address: address, port: port)

            switch client.connect(timeout: 10) {
            case .failure(let error):
                connectionAlert.dismiss(animated: false, completion: { [weak self] in

                    let alert = UIAlertController(
                        title: "Error",
                        message: """
                        Unable to connect (\(error)).

                        • Make sure that this device and the Quest are connected to the same WiFi network.

                        • Make sure that the Quest is running the Oculus MRC calibration app.
                        """,
                        preferredStyle: .alert
                    )

                    alert.addAction(.init(title: "OK", style: .default, handler: nil))

                    self?.present(alert, animated: true, completion: nil)
                })

            case .success:
                try? self.networkConfigurationStorage.save(configuration: .init(address: address))

                let scaleFactor = (Double(self.scaleSegmentedControl.selectedSegmentIndex) + 1.0)/Double(self.scaleSegmentedControl.numberOfSegments)

                connectionAlert.dismiss(animated: false, completion: { [weak self] in
                    let viewController: UIViewController

                    switch calibrationType {
                    case .quick:
                        viewController = QuickCalibrationViewController(
                            client: client,
                            scaleFactor: scaleFactor,
                            delegate: self
                        )
                    case .standard:
                        viewController = CalibrationViewController(
                            client: client,
                            scaleFactor: scaleFactor,
                            delegate: self
                        )
                    }

                    viewController.modalPresentationStyle = .overFullScreen
                    self?.present(viewController, animated: true, completion: nil)
                })
            }
        })
    }

    // MARK: - Actions

    @objc private func backAction() {
        navigationController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func connectAction(_ sender: Any) {

        guard let address = addressTextField.text, !address.isEmpty,
            let portText = portTextField.text, !portText.isEmpty,
            let port = Int32(portText)
        else {
            return
        }

        let calibrationType: CalibrationType = calibrationTypeSegmentedControl.selectedSegmentIndex == 0 ? .standard:.quick

        CameraPermissionHelper.ensurePermission(from: self, completion: { [weak self] in
            self?.startConnection(address: address, port: port, calibrationType: calibrationType)
        })
    }

    @IBAction private func scaleFactorChanged(_ sender: Any) {
        poorPerformanceWarningLabel.isHidden = scaleSegmentedControl.selectedSegmentIndex < 2
    }

    @IBAction private func openScaleFactorInstructions(_ sender: Any) {
        let alert = UIAlertController(
            title: "Resolution Scale Factor",
            message: """
            Use this setting to select the resolution of the Mixed Reality video.

            Smaller factors will result in better performance and lower quality.
            """,
            preferredStyle: .alert
        )

        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func openCalibrationTypeInstructions(_ sender: Any) {
        // TODO
        let alert = UIAlertController(
            title: "TODO",
            message: """
            TODO
            """,
            preferredStyle: .alert
        )

        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func downloadMRCAction(_ sender: Any) {
        UIApplication.shared.open(Definitions.oculusMRCapp, options: [:], completionHandler: nil)
    }

    @IBAction private func openSettings(_ sender: Any) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @IBAction func showInstructionsAction(_ sender: Any) {
        showInstructionsButton.isHidden = true
        instructionsContainer.isHidden = false
        scrollView.flashScrollIndicators()
        UIView.animate(withDuration: 0.1, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

extension CalibrationConnectionViewController: CalibrationViewControllerDelegate {

    func calibrationDidCancel(_ viewController: CalibrationViewController) {
        dismiss(animated: true, completion: nil)
    }

    func calibration(_ viewController: CalibrationViewController, didFinishWith result: CalibrationResult) {
        TemporaryCalibrationStorage.shared.save(calibration: result)
        // Dismissing and also returning to the previous screen
        navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension CalibrationConnectionViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
