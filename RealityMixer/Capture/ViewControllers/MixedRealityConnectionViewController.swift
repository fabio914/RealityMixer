//
//  MixedRealityConnectionViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import SwiftSocket

final class MixedRealityConnectionViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var addressTextField: UITextField!
    @IBOutlet private weak var portTextField: UITextField!
    @IBOutlet private weak var audioSwitch: UISwitch!
    @IBOutlet private weak var autoFocusSwitch: UISwitch!
    @IBOutlet private weak var magentaSwitch: UISwitch!
    @IBOutlet private weak var unflipSwitch: UISwitch!
    @IBOutlet private weak var backgroundVisibilitySegmentedControl: UISegmentedControl!
    @IBOutlet private weak var backgroundChromaKeySection: UIStackView!
    @IBOutlet private weak var backgroundChromaKeySegmentedControl: UISegmentedControl!
    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var secondInfoLabel: UILabel!
    @IBOutlet private weak var thirdInfoLabel: UILabel!
    private let storage = PreferenceStorage()

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mixed Reality"

        addressTextField.delegate = self
        portTextField.delegate = self

        if let preferences = storage.preference {
            addressTextField.text = preferences.address
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

         • Make sure the device is calibrated. A new calibration is required whenever you move this device or when you reset the Quest's Guardian boundary. You might also need to calibrate again when a new game is installed.
        """

        secondInfoLabel.text = """
         • Make sure that the Quest and this device are both connected to the same WiFi network, and that both have a strong signal. A 5 Ghz WiFi is recommended.

         • Make sure that the Reality Mixer app is allowed to access your camera and your local network. It'll ask for permission the first time you launch the calibration or mixed reality, however, you'll need to navigate to the system settings to be able to re-enable these permissions if you haven't given permissions during the first launch.
        """

        thirdInfoLabel.text = """
         • Launch your compatible VR game/application on the Quest. Some games might require you to enable Mixed Reality Capture on their Settings screen.

         • Some games use the color magenta as the color for transparency, make sure to use this option if that's the case for the game you're about to play.

         • Fill in the Quest's IP Address. You can find this address on the Quest's WiFi options.

         • Make sure that your device is not on Low Power mode.

         • Tap on "Connect".

         • After your mixed reality session is over, tap on the screen once to display the options on the top left side of the screen, and then tap on "Disconnect".
        """
    }

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
                        message: "Unable to connect: \(error)",
                        preferredStyle: .alert
                    )

                    alert.addAction(.init(title: "OK", style: .default, handler: nil))

                    self?.present(alert, animated: true, completion: nil)
                })

            case .success:
                try? self.storage.save(preference: .init(address: address))

                let configuration = MixedRealityConfiguration(
                    shouldUseMagentaAsTransparency: self.magentaSwitch.isOn,
                    enableAudio: self.audioSwitch.isOn,
                    enableAutoFocus: self.autoFocusSwitch.isOn,
                    shouldFlipOutput: !self.unflipSwitch.isOn,
                    backgroundVisibility: self.backgroundVisibility()
                )

                connectionAlert.dismiss(animated: false, completion: { [weak self] in

                    let viewController = MixedRealityViewController(
                        client: client,
                        configuration: configuration
                    )

                    viewController.modalPresentationStyle = .overFullScreen
                    self?.present(viewController, animated: true, completion: nil)
                })
            }
        })
    }

    private func backgroundVisibility() -> MixedRealityConfiguration.BackgroundVisibility {
        switch backgroundVisibilitySegmentedControl.selectedSegmentIndex {
        case 0:
            return .visible
        case 1:
            return .chromaKey({
                switch backgroundChromaKeySegmentedControl.selectedSegmentIndex {
                case 0:
                    return .black
                case 1:
                    return .green
                default:
                    return .magenta
                }
            }())
        default:
            return .hidden
        }
    }

    @IBAction func backgroundVisibilityDidChange(_ sender: UISegmentedControl) {
        backgroundChromaKeySection.isHidden = sender.selectedSegmentIndex != 1
    }

    @IBAction private func startCalibrationAction(_ sender: Any) {
        let otherNavigationController = UINavigationController(rootViewController: CalibrationConnectionViewController())
        otherNavigationController.modalPresentationStyle = .overFullScreen
        otherNavigationController.modalTransitionStyle = .crossDissolve

        present(otherNavigationController, animated: true, completion: nil)
    }

    @IBAction func openSettingsAction(_ sender: Any) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

extension MixedRealityConnectionViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
