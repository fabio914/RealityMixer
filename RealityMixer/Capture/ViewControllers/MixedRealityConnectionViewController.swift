//
//  MixedRealityConnectionViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import SwiftSocket

final class MixedRealityConnectionViewController: UIViewController {

    @IBOutlet private weak var addressTextField: UITextField!
    @IBOutlet private weak var portTextField: UITextField!
    @IBOutlet private weak var showDebugSwitch: UISwitch!
    @IBOutlet private weak var hardwareDecoderSwitch: UISwitch!
    @IBOutlet private weak var magentaSwitch: UISwitch!

    @IBOutlet private weak var overlayView: UIView!
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
        overlayView.isHidden = true

        if let preferences = storage.preference {
            addressTextField.text = preferences.address
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backAction))
    }

    @objc private func backAction() {
        navigationController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func connectAction(_ sender: Any) {
        overlayView.isHidden = false

        guard let address = addressTextField.text, !address.isEmpty,
            let portText = portTextField.text, !portText.isEmpty,
            let port = Int32(portText)
        else {
            return
        }

        let client = TCPClient(address: address, port: port)

        switch client.connect(timeout: 10) {
        case .failure(let error):
            overlayView.isHidden = true

            let alert = UIAlertController(
                title: "Error",
                message: "Unable to connect: \(error)",
                preferredStyle: .alert
            )

            alert.addAction(.init(title: "OK", style: .default, handler: nil))

            present(alert, animated: true, completion: nil)
        case .success:
            try? storage.save(preference: .init(address: address))

            let configuration = MixedRealityConfiguration(
                shouldShowDebug: showDebugSwitch.isOn,
                shouldUseHardwareDecoder: hardwareDecoderSwitch.isOn,
                shouldUseMagentaAsTransparency: magentaSwitch.isOn
            )

            let viewController = MixedRealityViewController(
                client: client,
                configuration: configuration
            )

            viewController.modalPresentationStyle = .overFullScreen
            present(viewController, animated: true, completion: nil)
        }
    }
}
