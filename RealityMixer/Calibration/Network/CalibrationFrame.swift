//
//  CalibrationFrame.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

struct CalibrationFrame {
    private static let protocolIdentifier: UInt32 = 1384359787

    struct FrameHeader {
        let protocolIdentifier: UInt32
        let payloadType: Int32
        let payloadLength: Int32
    }

    let header: FrameHeader
    let data: Data
    let length: Int

    init?(from data: Data) {
        let headerLength = MemoryLayout<FrameHeader>.size
        guard data.count >= headerLength else { return nil }

        let headerData = data.subdata(in: 0 ..< headerLength)
        let header = headerData.withUnsafeBytes({ $0.load(as: FrameHeader.self) })
        let totalLength = (headerLength + Int(header.payloadLength))

        guard header.protocolIdentifier == CalibrationFrame.protocolIdentifier,
            data.count >= totalLength
        else {
            return nil
        }

        self.header = header
        self.data = data.subdata(in: headerLength ..< totalLength)
        self.length = totalLength
    }

    init(payloadType: Int32, data: Data) {
        self.header = .init(
            protocolIdentifier: CalibrationFrame.protocolIdentifier,
            payloadType: payloadType,
            payloadLength: Int32(data.count)
        )

        self.data = data
        let headerLength = MemoryLayout<FrameHeader>.size
        self.length = (headerLength + Int(header.payloadLength))
    }

    func toData() -> Data {
        var result = Data()
        let headerLength = MemoryLayout<FrameHeader>.size

        var headerCopy = header
        let headerData = Data(bytes: &headerCopy, count: headerLength)

        result.append(headerData)
        result.append(data)
        return result
    }
}

final class CalibrationFrameCollection {
    private var data = Data()
    private var frames: [CalibrationFrame] = []

    func add(data: Data) {
        self.data.append(data)

        while let frame = CalibrationFrame(from: self.data) {
            frames.append(frame)

            if self.data.count > frame.length {
                self.data = self.data.advanced(by: frame.length)
            } else {
                self.data = .init()
            }
        }
    }

    func next() -> CalibrationFrame? {
        frames.isEmpty ? nil:frames.removeFirst()
    }
}
