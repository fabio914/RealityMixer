//
//  CalibrationConnectionViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit
import SwiftSocket

final class CalibrationConnectionViewController: UIViewController {
    @IBOutlet private weak var addressTextField: UITextField!
    @IBOutlet private weak var portTextField: UITextField!

    @IBOutlet weak var scaleSegmentedControl: UISegmentedControl!
    private let storage = PreferenceStorage()

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Calibration"

        if let preferences = storage.preference {
            addressTextField.text = preferences.address
        }
    }

    @IBAction func connectAction(_ sender: Any) {
        guard let address = addressTextField.text, !address.isEmpty,
            let portText = portTextField.text, !portText.isEmpty,
            let port = Int32(portText)
        else {
            return
        }

        let client = TCPClient(address: address, port: port)

        switch client.connect(timeout: 10) {
        case .failure(let error):
            let alert = UIAlertController(
                title: "Error",
                message: "Unable to connect: \(error)",
                preferredStyle: .alert
            )

            alert.addAction(.init(title: "OK", style: .default, handler: nil))

            present(alert, animated: true, completion: nil)
        case .success:
            try? storage.save(preference: .init(address: address))

            let scaleFactor = (Double(scaleSegmentedControl.selectedSegmentIndex) + 1.0)/Double(scaleSegmentedControl.numberOfSegments)

            let viewController = CalibrationViewController(
                client: client,
                scaleFactor: scaleFactor
            )

            viewController.modalPresentationStyle = .overFullScreen
            present(viewController, animated: true, completion: nil)
        }
    }
}
