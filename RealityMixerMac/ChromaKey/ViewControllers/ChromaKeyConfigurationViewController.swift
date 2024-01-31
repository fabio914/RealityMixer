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

    private let chromaConfigurationStorage: ChromaKeyConfigurationStorage
    private let maskStorage: ChromaKeyMaskStorage

    private let device: AVCaptureDevice
    private let onNavigateBack: () -> Void

    @IBOutlet private weak var sceneView: SCNView!

    @IBOutlet private weak var sensitivitySlider: NSSlider!
    @IBOutlet private weak var sensitivityLabel: NSTextField!
    @IBOutlet private weak var smoothnessSlider: NSSlider!
    @IBOutlet private weak var smoothnessLabel: NSTextField!
    @IBOutlet private weak var colorWell: NSColorWell!
    @IBOutlet private weak var editMaskButton: NSButton!

    private static let defaultChromaColor = NSColor(red: 0, green: 1, blue: 0, alpha: 1)

    private var chromaColor: NSColor
    private var maskImage: NSImage?

    private var textureCache: CVMetalTextureCache?
    private var backgroundPlaneNode: SCNNode?
    private var planeNode: SCNNode?

    private var first = true

    private var isPresentingColorPicker: Bool {
        colorWell.isActive
    }

    init(device: AVCaptureDevice, onNavigateBack: @escaping () -> Void) {
        self.device = device
        self.onNavigateBack = onNavigateBack
        self.chromaColor = Self.defaultChromaColor
        self.chromaConfigurationStorage = ChromaKeyConfigurationStorage(device.uniqueID)
        self.maskStorage = ChromaKeyMaskStorage(device.uniqueID)
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScene()
        configureSliders()
        resetValues()

        if let currentConfiguration = chromaConfigurationStorage.configuration {
            sensitivitySlider.floatValue = currentConfiguration.sensitivity
            smoothnessSlider.floatValue = currentConfiguration.smoothness
            chromaColor = currentConfiguration.color.nsColor
            colorWell.color = chromaColor
            updateValueLabels()
        }

        maskImage = maskStorage.load()
        updateMaskButton()
    }

    private func configureScene() {
        let scene = SCNScene()
        sceneView.scene = scene

        SceneKitHelpers.create(textureCache: &textureCache, for: sceneView)
    }

    private func configureSliders() {
        sensitivitySlider.minValue = 0.0
        sensitivitySlider.maxValue = 0.6

        smoothnessSlider.minValue = 0
        smoothnessSlider.maxValue = 0.1
    }

    private func resetValues() {
        sensitivitySlider.doubleValue = 0.15
        smoothnessSlider.doubleValue = 0
        chromaColor = Self.defaultChromaColor
        colorWell.color = chromaColor
        updateValueLabels()
    }

    func updateValueLabels() {
        sensitivityLabel.stringValue = String(format: "%.2lf", sensitivitySlider.doubleValue)
        smoothnessLabel.stringValue = String(format: "%.2lf", smoothnessSlider.doubleValue)
    }

    func updateMaskButton() {
        if maskImage != nil {
            editMaskButton.title = "Remove Mask"
        } else {
            editMaskButton.title = "Add Mask"
        }
    }

    func didUpdateValues() {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        chromaColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

        if let maskImage = maskImage, !isPresentingColorPicker {
            planeNode?.geometry?.firstMaterial?.ambient.contents = maskImage
        } else {
            planeNode?.geometry?.firstMaterial?.ambient.contents = NSColor.white
        }

        planeNode?.geometry?.firstMaterial?.setValue(
            SCNVector3(red, green, blue),
            forKey: "maskColor"
        )

        if isPresentingColorPicker {
            planeNode?.geometry?.firstMaterial?.setValue(0.0, forKey: "sensitivity")
            planeNode?.geometry?.firstMaterial?.setValue(0.0, forKey: "smoothness")
        } else {
            planeNode?.geometry?.firstMaterial?.setValue(
                sensitivitySlider.doubleValue,
                forKey: "sensitivity"
            )

            planeNode?.geometry?.firstMaterial?.setValue(
                smoothnessSlider.doubleValue,
                forKey: "smoothness"
            )
        }

        updateValueLabels()
    }

    func currentConfiguration() -> ChromaKeyConfiguration {
        .init(
            color: .init(nsColor: chromaColor),
            sensitivity: sensitivitySlider.floatValue,
            smoothness: smoothnessSlider.floatValue
        )
    }

    // MARK: - Actions

    @IBAction func resetValuesAction(_ sender: Any) {
        resetValues()
        didUpdateValues()
    }

    @IBAction private func editMaskAction(_ sender: Any) {

    }

    @IBAction private func saveAction(_ sender: Any) {
        try? chromaConfigurationStorage.save(configuration: currentConfiguration())
        try? maskStorage.update(mask: maskImage)
        onNavigateBack()
    }

    @IBAction private func goBackAction(_ sender: Any) {
        onNavigateBack()
    }

    @IBAction func valueDidChange(_ sender: Any) {
        didUpdateValues()
    }

    @IBAction func colorDidChange(_ sender: Any) {
        chromaColor = colorWell.color
        didUpdateValues()
    }
}

extension ChromaKeyConfigurationViewController: CameraSessionDelegate {

    func cameraSession(_ cameraSession: CameraSession, didReceiveFrame: CMSampleBuffer) {
        
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
