//
//  CameraTestViewModel.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 06/07/2022.
//

import SwiftUI
import AVFoundation

enum CameraTestState {
    case loading
    case error
    case notAuthorized
    case ready(NSImage?)
}

final class CameraTestViewModel: CameraTestViewModelProtocol {
    @Published var state: CameraTestState = .loading

    private let device: AVCaptureDevice?
    private let onNavigateBack: () -> Void
    private var cameraSession: CameraSession?

    init(device: AVCaptureDevice?, onNavigateBack: @escaping () -> Void) {
        self.device = device
        self.onNavigateBack = onNavigateBack
    }

    func onAppear() {
        guard case .loading = state else {
            return
        }

        guard let device = device else {
            self.state = .error
            return
        }

        do {
            self.cameraSession = try CameraSession(device: device, delegate: self)
            self.state = .ready(nil)
            cameraSession?.startRunning()
        } catch CameraSessionError.notAuthorized {
            self.state = .notAuthorized
        } catch {
            self.state = .error
        }
    }

    func navigateBack() {
        onNavigateBack()
    }
}

extension CameraTestViewModel: CameraSessionDelegate {

    func cameraSession(_ cameraSession: CameraSession, didReceiveFrame buffer: CMSampleBuffer) {
        guard case .ready = state,
            let imageBuffer = CMSampleBufferGetImageBuffer(buffer)
        else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        self.state = .ready(nsImage)
    }
}
