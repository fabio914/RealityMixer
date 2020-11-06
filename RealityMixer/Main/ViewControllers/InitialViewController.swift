//
//  InitialViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit

final class InitialViewController: UIViewController {

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reality Mixer"
    }

    @IBAction private func calibrateAction(_ sender: Any) {
        navigationController?.pushViewController(CalibrationConnectionViewController(), animated: true)
    }

    @IBAction private func captureAction(_ sender: Any) {
        navigationController?.pushViewController(MixedRealityConnectionViewController(), animated: true)
    }
}
