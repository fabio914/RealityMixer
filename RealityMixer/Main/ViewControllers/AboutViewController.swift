//
//  AboutViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/8/20.
//

import UIKit
import SwiftlyAttributedStrings

final class AboutViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var infoLabel: UILabel!

    init() {
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "About"
        configureVersionLabel()
        configureInfoLabel()

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backAction))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollView.flashScrollIndicators()
    }

    @objc private func backAction() {
        navigationController?.dismiss(animated: true, completion: nil)
    }

    private func configureVersionLabel() {
        versionLabel.text = "Version \(Definitions.version) (build \(Definitions.buildNumber))"
    }

    private func configureInfoLabel() {
        let oculusMRCplugin = Font(.systemFont(ofSize: 15, weight: .medium)) { "Oculus Mixed Reality Capture plugin for OBS" }
        let swiftSocket = Font(.systemFont(ofSize: 15, weight: .medium)) { "SwiftSocket" }
        let ffmpeg = Font(.systemFont(ofSize: 15, weight: .medium)) { "FFMPEG" }
        let arkitScenekit = Font(.systemFont(ofSize: 15, weight: .medium)) { "Apple's ARKit and SceneKit" }

        let libraries = "This project is based on the " + oculusMRCplugin + ". It also uses " + swiftSocket + ", " + ffmpeg + ", " + arkitScenekit + ".\n\n"

        infoLabel.attributedText = (
            Font(.systemFont(ofSize: 15, weight: .medium)) {
                """
                Developed by Fabio de A. Dela Antonio\n\n
                """
            } +
            Font(.systemFont(ofSize: 15, weight: .regular)) {
                """
                Special thanks to:
                Giovanni Longatto N. Marques
                Gustavo Buzogany Eboli\n\n
                """
            } +
            Font(.systemFont(ofSize: 15, weight: .regular)) {
                libraries + "Follow us on Twitter for updates and more mixed reality content."
            }
        ).attributedString
    }

    @IBAction private func gitHubAction(_ sender: Any) {
        UIApplication.shared.open(Definitions.gitHubURL, options: [:], completionHandler: nil)
    }

    @IBAction private func twitterAction(_ sender: Any) {
        UIApplication.shared.open(Definitions.twitterURL, options: [:], completionHandler: nil)
    }
}
