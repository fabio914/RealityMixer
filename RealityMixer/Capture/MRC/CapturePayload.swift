//
//  CapturePayload.swift
//  RealityMixer
//
//  Created by Fabio Dela Antonio on 03/07/2022.
//

import Foundation

enum CapturePayloadType: UInt32, RawRepresentable {
    case videoDimension = 10
    case videoData = 11
    case audioSampleRate = 12
    case audioData = 13
}

enum CapturePayload {
    struct VideoDimension {
        let width: Int32
        let height: Int32
    }

    struct AudioDataHeader {
        let timestamp: UInt64
        let channels: Int32
        let dataLength: Int32
    }

    case videoDimension(VideoDimension)
    case videoData(Data)
    case audioSampleRate(UInt32)
    case audioData(AudioDataHeader, Data)

    init?(from frame: CaptureFrame) {
        guard let payloadType = CapturePayloadType(rawValue: frame.payloadType) else { return nil }

        switch payloadType {
        case .videoDimension:
            guard frame.data.count == MemoryLayout<VideoDimension>.size else { return nil }
            let dimension = frame.data.withUnsafeBytes({ $0.load(as: VideoDimension.self) })
            self = .videoDimension(dimension)
        case .videoData:
            self = .videoData(frame.data)
        case .audioSampleRate:
            guard frame.data.count == MemoryLayout<UInt32>.size else { return nil }
            let sampleRate = frame.data.withUnsafeBytes({ $0.load(as: UInt32.self) })
            self = .audioSampleRate(sampleRate)
        case .audioData:
            let headerLength = MemoryLayout<AudioDataHeader>.size
            guard frame.data.count >= headerLength else { return nil }
            let headerData = frame.data.subdata(in: 0 ..< headerLength)
            let header = headerData.withUnsafeBytes({ $0.load(as: AudioDataHeader.self) })

            let totalLength = headerLength + Int(header.dataLength)
            guard frame.data.count == totalLength else { return nil }
            let audioData = frame.data.subdata(in: headerLength ..< totalLength)
            self = .audioData(header, audioData)
        }
    }
}
