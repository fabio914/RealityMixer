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

    // MARK: - Capture Mode
    @IBOutlet private weak var captureModeSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var captureModeInfoLabel: UILabel!

    // MARK: - Avatar
    @IBOutlet private weak var avatarSection: UIStackView!
    @IBOutlet private weak var avatarSegmentedControl: UISegmentedControl!

    // MARK: - Options
    @IBOutlet private weak var optionsStackView: UIStackView!
    @IBOutlet private weak var audioSwitch: UISwitch!
    @IBOutlet private weak var autoFocusSwitch: UISwitch!
    @IBOutlet private weak var unflipSwitch: UISwitch!

    // MARK: - Foreground layer options
    @IBOutlet private weak var foregroundVisibilitySegmentedControl: UISegmentedControl!
    @IBOutlet private weak var foregroundTransparencySection: UIStackView!
    @IBOutlet private weak var magentaSwitch: UISwitch!

    // MARK: - Background layer options
    @IBOutlet private weak var backgroundVisibilitySegmentedControl: UISegmentedControl!
    @IBOutlet private weak var backgroundChromaKeySection: UIStackView!
    @IBOutlet private weak var backgroundChromaKeySegmentedControl: UISegmentedControl!

    @IBOutlet private weak var showOptionsButton: UIButton!
    @IBOutlet private weak var resetOptionsButton: UIButton!

    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var secondInfoLabel: UILabel!
    @IBOutlet private weak var thirdInfoLabel: UILabel!

    private let preferenceStorage = PreferenceStorage()
    private let configurationStorage = ConfigurationStorage()

    private var configuration: MixedRealityConfiguration {
        get {
            configurationStorage.configuration
        }
        set {
            guard newValue != configuration else { return }
            didUpdate(configuration: newValue)
            UIView.animate(withDuration: 0.1, animations: {
                self.view.layoutIfNeeded()
            })
            try? configurationStorage.save(configuration: newValue)
        }
    }

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

        if let preferences = preferenceStorage.preference {
            addressTextField.text = preferences.address
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backAction))

        showOptionsButton.isHidden = false
        optionsStackView.isHidden = true

        configureInfoLabel()
        didUpdate(configuration: configuration)
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

    private func didUpdate(configuration: MixedRealityConfiguration) {
        switch configuration.captureMode {
        case .personSegmentation:
            captureModeSegmentedControl.selectedSegmentIndex = 0
            avatarSection.isHidden = true
            avatarSegmentedControl.selectedSegmentIndex = 0
            captureModeInfoLabel.text = "TODO: Info about person segmentation"
        case .bodyTracking(let avatarType):
            captureModeSegmentedControl.selectedSegmentIndex = 1
            avatarSection.isHidden = false
            captureModeInfoLabel.text = "TODO: Info about body tracking"
            switch avatarType {
            case .avatar1:
                avatarSegmentedControl.selectedSegmentIndex = 0
            case .avatar2:
                avatarSegmentedControl.selectedSegmentIndex = 1
            case .avatar3:
                avatarSegmentedControl.selectedSegmentIndex = 2
            case .avatar4:
                avatarSegmentedControl.selectedSegmentIndex = 3
            case .robot:
                avatarSegmentedControl.selectedSegmentIndex = 4
            case .skeleton:
                avatarSegmentedControl.selectedSegmentIndex = 5
            }
        case .raw:
            captureModeSegmentedControl.selectedSegmentIndex = 2
            avatarSection.isHidden = true
            avatarSegmentedControl.selectedSegmentIndex = 0
            captureModeInfoLabel.text = "TODO: Info about raw"
        }

        audioSwitch.isOn = configuration.enableAudio
        autoFocusSwitch.isOn = configuration.enableAutoFocus
        unflipSwitch.isOn = !configuration.shouldFlipOutput

        switch configuration.foregroundLayerOptions.visibility {
        case .visible(let magentaAsTransparency):
            foregroundVisibilitySegmentedControl.selectedSegmentIndex = 0
            foregroundTransparencySection.isHidden = false
            magentaSwitch.isOn = magentaAsTransparency
        case .hidden:
            foregroundVisibilitySegmentedControl.selectedSegmentIndex = 1
            foregroundTransparencySection.isHidden = true
            magentaSwitch.isOn = false
        }

        switch configuration.backgroundLayerOptions.visibility {
        case .visible:
            backgroundVisibilitySegmentedControl.selectedSegmentIndex = 0
            backgroundChromaKeySection.isHidden = true
            backgroundChromaKeySegmentedControl.selectedSegmentIndex = 0
        case .chromaKey(let chromaColor):
            backgroundVisibilitySegmentedControl.selectedSegmentIndex = 1
            backgroundChromaKeySection.isHidden = false
            switch chromaColor {
            case .black:
                backgroundChromaKeySegmentedControl.selectedSegmentIndex = 0
            case .green:
                backgroundChromaKeySegmentedControl.selectedSegmentIndex = 1
            case .magenta:
                backgroundChromaKeySegmentedControl.selectedSegmentIndex = 2
            }
        case .hidden:
            backgroundVisibilitySegmentedControl.selectedSegmentIndex = 2
            backgroundChromaKeySection.isHidden = true
            backgroundChromaKeySegmentedControl.selectedSegmentIndex = 0
        }

        resetOptionsButton.isHidden = configuration == .defaultConfiguration
    }

    private func updateConfiguration() {
        updateConfiguration(
            captureMode: {
                switch captureModeSegmentedControl.selectedSegmentIndex {
                case 0:
                    return .personSegmentation
                case 1:
                    return .bodyTracking(avatar: {
                        switch avatarSegmentedControl.selectedSegmentIndex {
                        case 0:
                            return .avatar1
                        case 1:
                            return .avatar2
                        case 2:
                            return .avatar3
                        case 3:
                            return .avatar4
                        case 4:
                            return .robot
                        default: // 5
                            return .skeleton
                        }
                    }())
                default: // 2
                    return .raw
                }
            }()
        )
    }

    private func updateConfiguration(captureMode: MixedRealityConfiguration.CaptureMode) {
        configuration = MixedRealityConfiguration(
            captureMode: captureMode,
            enableAudio: audioSwitch.isOn,
            enableAutoFocus: autoFocusSwitch.isOn,
            shouldFlipOutput: !unflipSwitch.isOn,
            foregroundLayerOptions: .init(
                visibility: {
                    switch foregroundVisibilitySegmentedControl.selectedSegmentIndex {
                    case 0:
                        return .visible(useMagentaAsTransparency: magentaSwitch.isOn)
                    default: // 1
                        return .hidden
                    }
                }()
            ),
            backgroundLayerOptions: .init(
                visibility: {
                    switch backgroundVisibilitySegmentedControl.selectedSegmentIndex {
                    case 0:
                        return .visible
                    case 1:
                        return .chromaKey(color: {
                            switch backgroundChromaKeySegmentedControl.selectedSegmentIndex {
                            case 0:
                                return .black
                            case 1:
                                return .green
                            default: // 2
                                return .magenta
                            }
                        }())
                    default:
                        return .hidden
                    }
                }()
            )
        )
    }

    private func startConnection(address: String, port: Int32) {
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
                try? self.preferenceStorage.save(preference: .init(address: address))
                let cameraPoseSender = CameraPoseSender(address: address)
                let configuration = self.configuration

                connectionAlert.dismiss(animated: false, completion: { [weak self] in

                    let viewController = MixedRealityViewController(
                        client: client,
                        configuration: configuration,
                        cameraPoseSender: cameraPoseSender
                    )

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

    @IBAction private func showOptionsAction(_ sender: Any) {
        showOptionsButton.isHidden = true
        optionsStackView.isHidden = false
        scrollView.flashScrollIndicators()
        UIView.animate(withDuration: 0.1, animations: {
            self.view.layoutIfNeeded()
        })
    }

    @IBAction func configurationValueDidChange(_ sender: Any) {
        updateConfiguration()
    }

    @IBAction func resetOptionsAction(_ sender: Any) {
        configuration = .defaultConfiguration
    }

    @IBAction func connectAction(_ sender: Any) {

        guard let address = addressTextField.text, !address.isEmpty,
            let portText = portTextField.text, !portText.isEmpty,
            let port = Int32(portText)
        else {
            return
        }

        switch (configuration.captureMode, configuration.captureMode.isSupported) {
        case (.bodyTracking, false):
            let alert = UIAlertController(
                title: "Sorry",
                message: "Body tracking (avatar) requires a device with an A12 chip or newer. Would you like to continue without it?",
                preferredStyle: .alert
            )

            alert.addAction(.init(title: "Continue", style: .default, handler: { [weak self] _ in
                self?.updateConfiguration(captureMode: .raw)
                self?.startConnection(address: address, port: port)
            }))

            alert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        case (.personSegmentation, false):
            let alert = UIAlertController(
                title: "Sorry",
                message: "Person segmentation (virtual green screen) requires a device with an A12 chip or newer. Would you like to continue without it?",
                preferredStyle: .alert
            )

            alert.addAction(.init(title: "Continue", style: .default, handler: { [weak self] _ in
                self?.updateConfiguration(captureMode: .raw)
                self?.startConnection(address: address, port: port)
            }))

            alert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        default:
            startConnection(address: address, port: port)
        }
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
