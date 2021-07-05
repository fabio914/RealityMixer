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
    @IBOutlet private weak var captureModeInfoLabel: UILabel!
    @IBOutlet private weak var specialModesContainer: UIView!
    @IBOutlet private weak var virtualGreenScreenModeView: UIView!
    @IBOutlet private weak var avatarModeView: UIView!
    @IBOutlet private weak var greenScreenModeView: UIView!
    @IBOutlet private weak var rawModeView: UIView!

    enum Mode {
        case personSegmentation
        case bodyTracking
        case greenScreen
        case raw
    }

    private var selectedMode: Mode = .personSegmentation

    // MARK: - Avatar
    @IBOutlet private weak var avatarSection: UIStackView!
    @IBOutlet private weak var avatarSegmentedControl: UISegmentedControl!

    // MARK: - Chroma Key Options
    @IBOutlet private weak var chromaKeySection: UIStackView!

    // MARK: - Options
    @IBOutlet private weak var optionsStackView: UIStackView!
    @IBOutlet private weak var movingCameraSwitch: UISwitch!
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

    // MARK: - Info
    @IBOutlet private weak var showInstructionsButton: UIButton!
    @IBOutlet private weak var instructionsContainer: UIStackView!
    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var secondInfoLabel: UILabel!
    @IBOutlet private weak var thirdInfoLabel: UILabel!

    private let networkConfigurationStorage = NetworkConfigurationStorage()
    private let mixedRealityConfigurationStorage = MixedRealityConfigurationStorage()
    private let chromaConfigurationStorage = ChromaKeyConfigurationStorage()

    private var configuration: MixedRealityConfiguration {
        get {
            mixedRealityConfigurationStorage.configuration
        }
        set {
            guard newValue != configuration else { return }
            didUpdate(configuration: newValue)
            UIView.animate(withDuration: 0.1, animations: {
                self.view.layoutIfNeeded()
            })
            try? mixedRealityConfigurationStorage.save(configuration: newValue)
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

        showInstructionsButton.isHidden = false
        instructionsContainer.isHidden = true

        if let networkConfiguration = networkConfigurationStorage.configuration {
            addressTextField.text = networkConfiguration.address
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backAction))

        showOptionsButton.isHidden = false
        optionsStackView.isHidden = true

        configureInfoLabel()
        configureModes()
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

    private func configureModes() {
        let personSegmentationSupported = MixedRealityConfiguration.CaptureMode.personSegmentation.isSupported
        let bodyTrackingSupported = MixedRealityConfiguration.CaptureMode.bodyTracking(avatar: .avatar1).isSupported

        if personSegmentationSupported || bodyTrackingSupported {
            virtualGreenScreenModeView.isHidden = !personSegmentationSupported
            avatarModeView.isHidden = !bodyTrackingSupported
            specialModesContainer.isHidden = false
        } else {
            specialModesContainer.isHidden = true
        }
    }

    private func didUpdate(configuration: MixedRealityConfiguration) {
        avatarSection.isHidden = true
        avatarSegmentedControl.selectedSegmentIndex = 0
        chromaKeySection.isHidden = true

        virtualGreenScreenModeView.backgroundColor = UIColor.clear
        avatarModeView.backgroundColor = UIColor.clear
        greenScreenModeView.backgroundColor = UIColor.clear
        rawModeView.backgroundColor = UIColor.clear

        switch configuration.captureMode {
        case .personSegmentation:
            selectedMode = .personSegmentation
            virtualGreenScreenModeView.backgroundColor = UIColor.white
            captureModeInfoLabel.text = """
            This mode uses Person Segmentation to extract your body from the video without using a green screen. It works best if the camera is pointed to a wall in a well-lit environment, and if you're the only thing between the camera and the wall.
            """
        case .bodyTracking(let avatarType):
            selectedMode = .bodyTracking
            avatarModeView.backgroundColor = UIColor.white
            avatarSection.isHidden = false
            captureModeInfoLabel.text = """
            This mode uses Body Tracking to capture your movement and animate an avatar. It works best if your entire body is within frame (including your feet) and if you're facing the back camera, the avatar might not appear or animate properly otherwise.
            """
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
        case .greenScreen:
            selectedMode = .greenScreen
            greenScreenModeView.backgroundColor = UIColor.white
            chromaKeySection.isHidden = false
            captureModeInfoLabel.text = """
            Use this mode if you have a physical green screen. Make sure that your green screen is lit evenly.
            """
        case .raw:
            selectedMode = .raw
            rawModeView.backgroundColor = UIColor.white
            captureModeInfoLabel.text = """
            This mode only displays the raw output from the Oculus Quest. You won't be able to see the output from the camera unless you hide or filter the background layer.
            """
        }

        movingCameraSwitch.isOn = configuration.enableMovingCamera
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
        configuration = MixedRealityConfiguration(
            captureMode: {
                switch selectedMode {
                case .personSegmentation:
                    return .personSegmentation
                case .bodyTracking:
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
                case .greenScreen:
                    return .greenScreen
                case .raw:
                    return .raw
                }
            }(),
            enableMovingCamera: movingCameraSwitch.isOn,
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
                        message: """
                        Unable to connect (\(error)).

                        • Make sure that this device and the Quest are connected to the same WiFi network.

                        • Make sure that you've completed and saved the Calibration.

                        • Make sure that the Quest is running a game/app that supports Mixed Reality Capture.

                        • Some games/apps require you to enable Mixed Reality Capture first before you can connect.
                        """,
                        preferredStyle: .alert
                    )

                    alert.addAction(.init(title: "OK", style: .default, handler: nil))

                    self?.present(alert, animated: true, completion: nil)
                })

            case .success:
                try? self.networkConfigurationStorage.save(configuration: .init(address: address))
                let configuration = self.configuration
                let chromaConfiguration = self.chromaConfigurationStorage.configuration

                connectionAlert.dismiss(animated: false, completion: { [weak self] in

                    let viewController = MixedRealityViewController(
                        client: client,
                        configuration: configuration,
                        chromaConfiguration: chromaConfiguration
                    )

                    viewController.modalPresentationStyle = .overFullScreen
                    self?.present(viewController, animated: true, completion: nil)
                })
            }
        })
    }

    private func presentChromaKeyOptions() {
        let viewController = ChromaKeyConfigurationViewController()
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: true, completion: nil)
    }

    private func presentCalibration() {
        let otherNavigationController = UINavigationController(rootViewController: CalibrationConnectionViewController())
        otherNavigationController.modalPresentationStyle = .overFullScreen
        otherNavigationController.modalTransitionStyle = .crossDissolve

        present(otherNavigationController, animated: true, completion: nil)
    }

    // MARK: - Actions

    @IBAction private func selectVirtualGreenScreenAction(_ sender: Any) {
        selectedMode = .personSegmentation
        updateConfiguration()
    }

    @IBAction private func selectAvatarAction(_ sender: Any) {
        selectedMode = .bodyTracking
        updateConfiguration()
    }

    @IBAction private func selectGreenScreenAction(_ sender: Any) {
        selectedMode = .greenScreen
        updateConfiguration()
    }

    @IBAction func selectRawAction(_ sender: Any) {
        selectedMode = .raw
        updateConfiguration()
    }

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

    @IBAction func showInstructionsAction(_ sender: Any) {
        showInstructionsButton.isHidden = true
        instructionsContainer.isHidden = false
        scrollView.flashScrollIndicators()
        UIView.animate(withDuration: 0.1, animations: {
            self.view.layoutIfNeeded()
        })
    }

    @IBAction func showChromaKeyOptions(_ sender: Any) {
        presentChromaKeyOptions()
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
            let port = Int32(portText),
            configuration.captureMode.isSupported
        else {
            return
        }

        if configuration.enableMovingCamera,
           !TemporaryCalibrationStorage.shared.hasCalibration {

            let missingCalibrationAlert = UIAlertController(
                title: "Calibration",
                message: "You'll need to complete the calibration before you can continue.",
                preferredStyle: .alert
            )

            missingCalibrationAlert.addAction(
                .init(title: "Calibrate", style: .default, handler: { [weak self] _ in
                    self?.presentCalibration()
                })
            )

            missingCalibrationAlert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))

            present(missingCalibrationAlert, animated: true, completion: nil)
            return
        }

        if case .greenScreen = configuration.captureMode,
           chromaConfigurationStorage.configuration == nil {

            let missingConfigurationAlert = UIAlertController(
                title: "Chroma Key",
                message: "You'll need to configure the Chroma Key effect before you can continue.",
                preferredStyle: .alert
            )

            missingConfigurationAlert.addAction(
                .init(title: "Configure Chroma Key", style: .default, handler: { [weak self] _ in
                    self?.presentChromaKeyOptions()
                })
            )

            missingConfigurationAlert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))

            present(missingConfigurationAlert, animated: true, completion: nil)
            return
        }

        startConnection(address: address, port: port)
    }

    @IBAction private func startCalibrationAction(_ sender: Any) {
        presentCalibration()
    }

    @IBAction func openSettingsAction(_ sender: Any) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @IBAction private func openMovingCameraInstructions(_ sender: Any) {
        let alert = UIAlertController(
            title: "Moving Camera",
            message: """
            Enable this setting if you wish to be able to move the camera around the scene.

            This might not work with every game/app, and you can only move this device during a Mixed Reality session.

            You'll need to recalibrate if you move this device while not connected to a Quest game/app.
            """,
            preferredStyle: .alert
        )

        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func openUnflipOutputInstructions(_ sender: Any) {
        let alert = UIAlertController(
            title: "Unflip Output",
            message: """
            Use this setting if the Mixed Reality video appears to be upside down.

            This is necessary for a few games/apps. Remember to switch it off before connecting to a game that doesn't require it.
            """,
            preferredStyle: .alert
        )

        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @IBAction private func openBackgroundVisibilityInstructions(_ sender: Any) {

    }

    @IBAction private func openForegroundVisibilityInstructions(_ sender: Any) {

    }

    @IBAction private func openMagentaForTransparencyInstructions(_ sender: Any) {
        let alert = UIAlertController(
            title: "Magenta for Transparency",
            message: """
            Some old games/apps use the color magenta to indicate the areas of the foreground layer that should be transparent.

            Use this setting if that's the case for the game/app you're connecting to. Remember to switch it off before connecting to a game that doesn't require it.
            """,
            preferredStyle: .alert
        )

        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension MixedRealityConnectionViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
