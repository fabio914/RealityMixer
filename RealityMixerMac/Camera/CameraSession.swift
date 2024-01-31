//
//  CameraSession.swift
//  RealityMixerMac
//
//  Created by Fabio Dela Antonio on 06/07/2022.
//

import Foundation
import AVFoundation

enum CameraSessionError: Error {
    case notAuthorized
    case unableToAddVideoInput
}

protocol CameraSessionDelegate: AnyObject {
    func cameraSession(_ cameraSession: CameraSession, didReceiveFrame: CMSampleBuffer)
}

final class CameraSession: NSObject {

    let device: AVCaptureDevice
    private var captureSession: AVCaptureSession
    weak var delegate: CameraSessionDelegate?

    init(device: AVCaptureDevice, delegate: CameraSessionDelegate) throws {

        guard case .authorized = AVCaptureDevice.authorizationStatus(for: .video) else {
            throw CameraSessionError.notAuthorized
        }

        let captureSession = AVCaptureSession()
        self.captureSession = captureSession
        self.delegate = delegate
        self.device = device

        super.init()

        let videoInput = try AVCaptureDeviceInput(device: device)

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            throw CameraSessionError.unableToAddVideoInput
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: .main)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        } else {
            throw CameraSessionError.unableToAddVideoInput
        }
    }

    func startRunning() {
        captureSession.startRunning()
    }

    deinit {
        captureSession.stopRunning()
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        delegate?.cameraSession(self, didReceiveFrame: sampleBuffer)
    }
}
