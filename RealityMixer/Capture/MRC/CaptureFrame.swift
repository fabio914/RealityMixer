//
//  CaptureFrame.swift
//  RealityMixer
//
//  Created by Fabio Dela Antonio on 03/07/2022.
//

import Foundation

struct CaptureFrame {
    static let protocolIdentifier: UInt32 = 0x2877AF94

    struct FrameHeader {
        let protocolIdentifier: UInt32
        let totalDataLengthExcludingIdentifier: UInt32
        let payloadType: UInt32
        let payloadLength: UInt32
    }

    let payloadType: UInt32
    let data: Data
    let length: Int

    init?(from data: Data) {
        let headerLength = MemoryLayout<FrameHeader>.size
        guard data.count >= headerLength else { return nil }

        let headerData = data.subdata(in: 0 ..< headerLength)
        let header = headerData.withUnsafeBytes({ $0.load(as: FrameHeader.self) })
        let totalLength = (headerLength + Int(header.payloadLength))

        guard header.protocolIdentifier == CaptureFrame.protocolIdentifier else {
            // Error....
            return nil
        }

        guard totalLength == MemoryLayout<UInt32>.size + Int(header.totalDataLengthExcludingIdentifier) else {
            // Error....
            return nil
        }

        guard data.count >= totalLength else {
            return nil
        }

        self.payloadType = header.payloadType
        self.data = data.subdata(in: headerLength ..< totalLength)
        self.length = totalLength
    }
}

final class CaptureFrameCollection {
    private let semaphore = DispatchSemaphore(value: 1)
    private var data = Data()
    private var frames: [CaptureFrame] = []

    func add(data: Data) {
        semaphore.wait()
        self.data.append(data)

        while let frame = CaptureFrame(from: self.data) {
            frames.append(frame)

            if self.data.count > frame.length {
                self.data = self.data.advanced(by: frame.length)
            } else {
                self.data = .init()
            }
        }
        semaphore.signal()
    }

    func next() -> CaptureFrame? {
        semaphore.wait()
        let nextFrame = frames.isEmpty ? nil:frames.removeFirst()
        semaphore.signal()
        return nextFrame
    }
}
