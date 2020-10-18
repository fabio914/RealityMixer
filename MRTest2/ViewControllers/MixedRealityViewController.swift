//
//  MixedRealityViewController.swift
//  MRTest2
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import SwiftSocket

final class MixedRealityViewController: UIViewController {
    private let client: TCPClient
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var imageView: UIImageView!

    init(client: TCPClient) {
        self.client = client
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
        self.oculusMRC = OculusMRC()
        oculusMRC?.delegate = self
    }

    @objc func update(with sender: CADisplayLink) {
        guard let oculusMRC = oculusMRC,
            let data = client.read(65536, timeout: 0),
            data.count > 0
        else {
            return
        }

        oculusMRC.addData(data, length: Int32(data.count))
        oculusMRC.update()
    }
}

extension MixedRealityViewController: OculusMRCDelegate {

    func oculusMRC(_ oculusMRC: OculusMRC, didReceiveNewFrame frame: UIImage) {
        imageView.image = frame
    }
}
