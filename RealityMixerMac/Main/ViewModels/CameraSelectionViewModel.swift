//
//  CameraSelectionViewModel.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 05/07/2022.
//

import SwiftUI
import AVFoundation

struct CameraOption: Identifiable {
    let id: String
    let localizedName: String

    init(id: String, localizedName: String) {
        self.id = id
        self.localizedName = localizedName
    }

    init(captureDevice: AVCaptureDevice) {
        self.id = captureDevice.uniqueID
        self.localizedName = captureDevice.localizedName
    }
}

enum CameraSelectionState {
    case loading
    case notAuthorized
    case options([CameraOption])
}

final class CameraSelectionViewModel: CameraSelectionViewModelProtocol {
    @Published var state: CameraSelectionState = .loading
    @Binding private var cameraSelection: AVCaptureDevice?

    init(cameraSelection: Binding<AVCaptureDevice?>) {
        self._cameraSelection = cameraSelection
    }

    func onAppear() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            discoverCameras()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    if granted {
                        self?.discoverCameras()
                    } else {
                        self?.state = .notAuthorized
                    }
                }
            }

        case .denied, .restricted:
            self.state = .notAuthorized
        @unknown default:
            self.state = .notAuthorized
        }
    }

    func select(_ camera: CameraOption) {
        guard case .options(let options) = state,
            Set(options.map({ $0.id })).contains(camera.id),
            let device = AVCaptureDevice(uniqueID: camera.id)
        else { return }

        cameraSelection = device
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func discoverCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        self.state = .options(discovery.devices.map(CameraOption.init(captureDevice:)))
    }
}
