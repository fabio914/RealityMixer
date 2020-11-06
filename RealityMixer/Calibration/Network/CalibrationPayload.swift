//
//  CalibrationPayload.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

enum PayloadType: Int32, RawRepresentable {
    case userId = 31
    case dataVersion = 32
    case poseUpdate = 33
    case primaryButtonPressed = 34
    case secondaryButtonPressed = 35
    case calibrationData = 36 // both ways
    case clearCalibration = 37 // from the app to the Quest
    case operationComplete = 38
    case stateChangePause = 39
    case adjustKey = 40
}

struct PoseUpdate {
    let frame: Int
    let time: TimeInterval

    let head: Pose
    let leftHand: Pose?
    let rightHand: Pose?
    let trackingTransformRaw: Pose

    init(string: String) throws {
        let parser = Parser(string: string)
        try parser.match(token: "frame")
        self.frame = try parser.parseInteger()
        try parser.match(token: "time")
        self.time = try parser.parseDouble()

        try parser.match(token: "head_pos")
        let headPosition = try parser.parseVector3()
        try parser.match(token: "head_rot")
        let headRotation = try parser.parseQuaternion()
        self.head = Pose(position: headPosition, rotation: headRotation)

        try parser.match(token: "left_hand_pos")
        let leftHandPosition = try parser.parseVector3()
        try parser.match(token: "left_hand_rot")
        let leftHandRotation = try parser.parseQuaternion()
        let leftHand = Pose(position: leftHandPosition, rotation: leftHandRotation)

        try parser.match(token: "right_hand_pos")
        let rightHandPosition = try parser.parseVector3()
        try parser.match(token: "right_hand_rot")
        let rightHandRotation = try parser.parseQuaternion()
        let rightHand = Pose(position: rightHandPosition, rotation: rightHandRotation)

        try parser.match(token: "raw_pos")
        let rawPosition = try parser.parseVector3()
        try parser.match(token: "raw_rot")
        let rawRotation = try parser.parseQuaternion()
        self.trackingTransformRaw = Pose(position: rawPosition, rotation: rawRotation)

        try parser.match(token: "lht")
        let isLeftControllerTracked = try parser.parseBool()

        try parser.match(token: "lhv")
        let isLeftControllerValid = try parser.parseBool()

        try parser.match(token: "rht")
        let isRightControllerTracked = try parser.parseBool()

        try parser.match(token: "rhv")
        let isRightControllerValid = try parser.parseBool()

        self.leftHand = (isLeftControllerValid && isLeftControllerTracked) ? leftHand:nil
        self.rightHand = (isRightControllerValid && isRightControllerTracked) ? rightHand:nil
    }
}

enum Payload {
    case userId(String)
    case dataVersion(Int32)
    case poseUpdate(PoseUpdate)
    case primaryButtonPressed(Int32)
    case secondaryButtonPressed(Int32)
    case calibrationData(String) // XML
    case operationComplete
    case stateChangePause
    case adjustKey//(Int32)

    init?(from frame: CalibrationFrame) {
        guard let payloadType = PayloadType(rawValue: frame.header.payloadType) else { return nil }

        switch payloadType {
        case .userId:
            guard let string = String(data: frame.data, encoding: .utf8) else { return nil }
            self = .userId(string)
        case .dataVersion:
            guard frame.data.count == MemoryLayout<Int32>.size else { return nil }
            let version = frame.data.withUnsafeBytes({ $0.load(as: Int32.self) })
            self = .dataVersion(version)
        case .poseUpdate:
            guard let string = String(data: frame.data, encoding: .utf8),
                let poseUpdate = try? PoseUpdate(string: string)
            else {
                return nil
            }

            self = .poseUpdate(poseUpdate)
        case .primaryButtonPressed:
            guard frame.data.count == MemoryLayout<Int32>.size else { return nil }
            let numberOfTimes = frame.data.withUnsafeBytes({ $0.load(as: Int32.self) })
            self = .primaryButtonPressed(numberOfTimes)
        case .secondaryButtonPressed:
            guard frame.data.count == MemoryLayout<Int32>.size else { return nil }
            let numberOfTimes = frame.data.withUnsafeBytes({ $0.load(as: Int32.self) })
            self = .secondaryButtonPressed(numberOfTimes)
        case .calibrationData:
            guard let string = String(data: frame.data, encoding: .utf8) else { return nil }
            self = .calibrationData(string)
        case .operationComplete:
            self = .operationComplete
        case .stateChangePause:
            self = .stateChangePause
        case .adjustKey:
            self = .adjustKey
        default:
            return nil
        }
    }
}
