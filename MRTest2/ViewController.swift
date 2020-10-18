//
//  ViewController.swift
//  MRTest2
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import SwiftSocket

final class ViewController: UIViewController {
    private var client: TCPClient?
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let client = TCPClient(address: "192.168.0.95", port: 28734)

        switch client.connect(timeout: 10) {
        case .failure(let error):
            print("Unable to connect: \(error)")
        case .success:
            print("Connected!")
            self.client = client
            let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
            displayLink.add(to: .main, forMode: .default)
            self.displayLink = displayLink
            self.oculusMRC = OculusMRC()
            oculusMRC?.delegate = self
        }
    }

    @objc func update(with sender: CADisplayLink) {
        guard let client = client,
            let oculusMRC = oculusMRC,
            let data = client.read(65536, timeout: 0),
            data.count > 0
        else {
            return
        }

        oculusMRC.addData(data, length: Int32(data.count))
        oculusMRC.update()
    }
}

extension ViewController: OculusMRCDelegate {

    func oculusMRC(_ oculusMRC: OculusMRC, didReceiveNewFrame frame: UIImage) {
        imageView.image = frame
    }
}

