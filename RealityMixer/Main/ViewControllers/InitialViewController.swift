//
//  InitialViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit
import SafariServices

final class InitialViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollView.flashScrollIndicators()
    }

    @IBAction private func calibrateAction(_ sender: Any) {
        let otherNavigationController = UINavigationController(rootViewController: CalibrationConnectionViewController())
        otherNavigationController.modalPresentationStyle = .overFullScreen
        otherNavigationController.modalTransitionStyle = .crossDissolve

        present(otherNavigationController, animated: true, completion: nil)
    }

    @IBAction private func captureAction(_ sender: Any) {
        let otherNavigationController = UINavigationController(rootViewController: MixedRealityConnectionViewController())
        otherNavigationController.modalPresentationStyle = .overFullScreen
        otherNavigationController.modalTransitionStyle = .crossDissolve

        present(otherNavigationController, animated: true, completion: nil)
    }

    @IBAction private func helpAction(_ sender: Any) {
        let viewController = SFSafariViewController(url: Definitions.instructionsURL)
        present(viewController, animated: true, completion: nil)
    }

    @IBAction private func aboutAction(_ sender: Any) {
        let otherNavigationController = UINavigationController(rootViewController: AboutViewController())
        otherNavigationController.modalPresentationStyle = .overFullScreen
        otherNavigationController.modalTransitionStyle = .crossDissolve

        present(otherNavigationController, animated: true, completion: nil)
    }
}
