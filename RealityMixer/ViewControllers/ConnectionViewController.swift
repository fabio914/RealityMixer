//
//  ViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import SwiftSocket

final class ConnectionViewController: UIViewController {

    @IBOutlet private weak var addressTextField: UITextField!
    @IBOutlet private weak var portTextField: UITextField!
    @IBOutlet private weak var showDebugSwitch: UISwitch!
    @IBOutlet private weak var hardwareDecoderSwitch: UISwitch!

    @IBOutlet private weak var overlayView: UIView!
    private let storage = AddressPortPreferenceStorage()

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reality Mixer"
        overlayView.isHidden = true

        if let preferences = storage.preference {
            addressTextField.text = preferences.address
            portTextField.text = "\(preferences.port)"
        }
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
            try? storage.save(preference: .init(address: address, port: port))

            let viewController = MixedRealityViewController(
                client: client,
                shouldShowDebug: showDebugSwitch.isOn,
                shouldUseHardwareDecoder: hardwareDecoderSwitch.isOn
            )

            viewController.modalPresentationStyle = .overFullScreen
            present(viewController, animated: true, completion: nil)
        }
    }
}

struct AddressPortPreference: Codable {
    let address: String
    let port: Int32
}

final class AddressPortPreferenceStorage {
    private let defaults: UserDefaults
    private let key = "preference"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(preference: AddressPortPreference) throws {
        let data = try JSONEncoder().encode(preference)
        let string = data.base64EncodedString()
        defaults.setValue(string, forKey: key)
    }

    var preference: AddressPortPreference? {
        defaults.string(forKey: key)
            .flatMap({ Data(base64Encoded: $0) })
            .flatMap({ try? JSONDecoder().decode(AddressPortPreference.self, from: $0) })
    }
}
