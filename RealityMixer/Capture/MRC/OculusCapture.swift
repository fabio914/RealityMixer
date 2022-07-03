//
//  OculusCapture.swift
//  RealityMixer
//
//  Created by Fabio Dela Antonio on 03/07/2022.
//

import Foundation

protocol OculusCaptureDelegate: AnyObject {

}

final class OculusCapture {
    weak var delegate: OculusCaptureDelegate?
    private let frameCollection = CaptureFrameCollection()

    init(delegate: OculusCaptureDelegate? = nil) {
        self.delegate = delegate
    }

    func add(data: Data) {
        frameCollection.add(data: data)
    }

    func update() {
        while let frame = frameCollection.next() {
            if let payload = CapturePayload(from: frame) {
                process(payload)
            } else {
                print("[NEW CAPTURE] Unknown payload type \(frame.payloadType)")
            }
        }
    }

    private func process(_ payload: CapturePayload) {
        switch payload {
        case .videoDimension(let videoDimension):
            print("[NEW CAPTURE] Received Video Dimension \(videoDimension.width) \(videoDimension.height)")
        case .videoData(let data):
            print("[NEW CAPTURE] Received Video Data \(data.count)")
        case .audioSampleRate(let samplerate):
            print("[NEW CAPTURE] Received Audio Sample rate \(samplerate)")
        case .audioData(let data):
            print("[NEW CAPTURE] Received Audio Data \(data.count)")
        }
    }
}
