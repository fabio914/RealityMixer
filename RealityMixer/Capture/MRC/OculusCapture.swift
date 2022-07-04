//
//  OculusCapture.swift
//  RealityMixer
//
//  Created by Fabio Dela Antonio on 03/07/2022.
//

import Foundation
import AVFoundation

protocol OculusCaptureDelegate: AnyObject {
    func oculusCapture(_ oculusCapture: OculusCapture, didReceive pixelBuffer: CVPixelBuffer)
    func oculusCapture(_ oculusCapture: OculusCapture, didReceiveAudio audio: AVAudioPCMBuffer, timestamp: UInt64)
}

final class OculusCapture {
    weak var delegate: OculusCaptureDelegate?
    private let frameCollection = CaptureFrameCollection()

    private var audioSampleRate: UInt32 = 48000
    private var videoWidth: Int32 = 1920
    private var videoHeight: Int32 = 1080

    private lazy var decoder: VideoDecoder = {
        VideoDecoder(delegate: self)
    }()

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
            self.videoWidth = videoDimension.width
            self.videoHeight = videoDimension.height
            print("[NEW CAPTURE] Received Video Dimension \(videoDimension.width) \(videoDimension.height)")
        case .videoData(let data):
            print("[NEW CAPTURE] Received Video Data \(data.count)")
            decoder.process(data)
        case .audioSampleRate(let samplerate):
            print("[NEW CAPTURE] Received Audio Sample rate \(samplerate)")
            self.audioSampleRate = samplerate
        case .audioData(let audioHeader, let audioData):
            print("[NEW CAPTURE] Received Audio Data \(audioHeader.channels) \(audioData.count)")
            processAudio(audioHeader, data: audioData)
        }
    }

    private func processAudio(_ header: CapturePayload.AudioDataHeader, data: Data) {
        guard (header.channels == 1 || header.channels == 2), data.count > 0 else { return }

        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: .init(audioSampleRate),
            channels: .init(header.channels),
            interleaved: false
        ) else {
            return
        }

        let frameCount = Int(header.dataLength) / MemoryLayout<Float32>.size / Int(header.channels)

        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: .init(frameCount)) else {
            return
        }

        audioBuffer.frameLength = audioBuffer.frameCapacity

        data.withUnsafeBytes {
            let floatPtr = $0.bindMemory(to: Float32.self)
            for channel in 0 ..< Int(header.channels) {
                for index in 0 ..< frameCount {
                    audioBuffer.floatChannelData?[channel][index] = floatPtr[index + channel + (index * Int(header.channels - 1))]
                }
            }
        }

        delegate?.oculusCapture(self, didReceiveAudio: audioBuffer, timestamp: header.timestamp)
    }
}

extension OculusCapture: DecoderDelegate {

    func didDecodeFrame(_ buffer: CVPixelBuffer) {
        delegate?.oculusCapture(self, didReceive: buffer)
    }
}
