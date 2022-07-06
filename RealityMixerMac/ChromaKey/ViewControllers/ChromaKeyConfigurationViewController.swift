//
//  ChromaKeyConfigurationViewController.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 07/07/2022.
//

import Cocoa
import AVFoundation
import SceneKit
import RealityMixerKit

class ChromaKeyConfigurationViewController: NSViewController {

    private let device: AVCaptureDevice
    private let onNavigateBack: () -> Void

    @IBOutlet private weak var sceneView: SCNView!

    init(device: AVCaptureDevice, onNavigateBack: @escaping () -> Void) {
        self.device = device
        self.onNavigateBack = onNavigateBack
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction private func goBackAction(_ sender: Any) {
        onNavigateBack()
    }
}

import SwiftUI

struct ChromaKeyConfigurationScreen: NSViewControllerRepresentable {
    typealias NSViewControllerType = ChromaKeyConfigurationViewController
    let device: AVCaptureDevice
    let onNavigateBack: () -> Void

    func makeNSViewController(context: Context) -> ChromaKeyConfigurationViewController {
        ChromaKeyConfigurationViewController(device: device, onNavigateBack: onNavigateBack)
    }

    func updateNSViewController(_ nsViewController: ChromaKeyConfigurationViewController, context: Context) {

    }
}
