import Foundation
import ARKit
import SwiftSocket

private let protocolIdentifier: UInt32 = 0x2877AF94

struct CameraIntrinsicsPayload {
    // Frame Header
    let magic: UInt32 = protocolIdentifier
    let totalDataLengthExcludingMagic: UInt32 = 0x40
    let payloadType: UInt32 = 14
    let payloadLength: UInt32 = 0x34

    // Payload
    let unknown1: UInt32 = 100 // Timestamp?
    let unknown2: UInt32 = 0
    let unknown3: UInt32 = 0 // type = intrinsics?
    let length: UInt32 = 0x24

    /* column row */
    let m11: Float
    let m21: Float
    let m31: Float
    let m12: Float
    let m22: Float
    let m32: Float
    let m13: Float
    let m23: Float
    let m33: Float

    init(
        m11: Float,
        m12: Float,
        m13: Float,
        m21: Float,
        m22: Float,
        m23: Float,
        m31: Float,
        m32: Float,
        m33: Float
    ) {
        self.m11 = m11
        self.m12 = m12
        self.m13 = m13
        self.m21 = m21
        self.m22 = m22
        self.m23 = m23
        self.m31 = m31
        self.m32 = m32
        self.m33 = m33
    }

    init(
        yFov: Float,
        imageSize: Size,
        scaleFactor: Float = 1.0
    ) {
        let halfWidth = (Float(imageSize.width) * 0.5)
        let halfHeight = (Float(imageSize.height) * 0.5)

        let focalLength = halfHeight/tanf(yFov/2.0)

        self.init(
            m11: focalLength * scaleFactor,
            m12: 0.0,
            m13: 0.0,
            m21: 0.0,
            m22: focalLength * scaleFactor,
            m23: 0.0,
            m31: halfWidth * scaleFactor,
            m32: halfHeight * scaleFactor,
            m33: 1.0
        )
    }

    var data: Data {
        let length = MemoryLayout<CameraIntrinsicsPayload>.size
        var copy = self
        let data = Data(bytes: &copy, count: length)
        return data
    }
}

struct CameraPositionPayload {
    // Frame Header
    let magic: UInt32 = protocolIdentifier
    let totalDataLengthExcludingMagic: UInt32 = 0x28
    let payloadType: UInt32 = 14
    let payloadLength: UInt32 = 0x1c

    // Payload
    let unknown1: UInt32 = 100 // Timestamp?
    let unknown2: UInt32 = 0
    let unknown3: UInt32 = 2 // type = position?
    let length: UInt32 = 0x0c

    let x: Float
    let y: Float
    let z: Float

    init(position: Vector3) {
        self.x = Float(position.x)
        self.y = Float(position.y)
        self.z = Float(position.z)
    }

    var data: Data {
        let length = MemoryLayout<CameraPositionPayload>.size
        var copy = self
        let data = Data(bytes: &copy, count: length)
        return data
    }
}

struct CameraRotationPayload {
    // Frame Header
    let magic: UInt32 = protocolIdentifier
    let totalDataLengthExcludingMagic: UInt32 = 0x2c
    let payloadType: UInt32 = 14
    let payloadLength: UInt32 = 0x20

    // Payload
    let unknown1: UInt32 = 100 // Timestamp?
    let unknown2: UInt32 = 0
    let unknown3: UInt32 = 3 // type = position?
    let length: UInt32 = 0x10

    let x: Float
    let y: Float
    let z: Float
    let w: Float

    init(rotation: Quaternion) {
        self.x = Float(rotation.x)
        self.y = Float(rotation.y)
        self.z = Float(rotation.z)
        self.w = Float(rotation.w)
    }

    var data: Data {
        let length = MemoryLayout<CameraRotationPayload>.size
        var copy = self
        let data = Data(bytes: &copy, count: length)
        return data
    }
}

final class CameraPoseSender {
    private weak var client: TCPClient?

    private struct InitialPose {
        let position: Vector3
        let inverseRotation: Quaternion
    }

    private var initialReliableCameraPose: InitialPose?
    private let initialCalibration: CalibrationResult

    init?(client: TCPClient) {
        guard let calibration = TemporaryCalibrationStorage.shared.calibration else {
            return nil
        }

        self.initialCalibration = calibration
        self.client = client
    }

    private func sendCameraUpdate(pose: Pose/*, intrinsics: CameraIntrinsicsPayload*/) {
//        _ = client?.send(data: intrinsics.data)
        _ = client?.send(data: CameraPositionPayload(position: pose.position).data)
        _ = client?.send(data: CameraRotationPayload(rotation: pose.rotation).data)
    }

    func didUpdate(frame: ARFrame) {
        if let initialReliableCameraPose = initialReliableCameraPose {
            switch frame.camera.trackingState {
            case .normal, .limited:
                let position = frame.camera.transform.columns.3

                let positionVector = Vector3(
                    x: .init(position.x),
                    y: .init(position.y),
                    z: .init(position.z)
                )

                let positionDelta = positionVector - initialReliableCameraPose.position
                let rotationDelta = initialReliableCameraPose.inverseRotation * Quaternion(rotationMatrix: SCNMatrix4(frame.camera.transform))

                let pose = Pose(
                    position: positionDelta,
                    rotation: rotationDelta
                )

                let poseResult = initialCalibration.pose * pose
                sendCameraUpdate(pose: poseResult /*, intrinsics: intrinsics*/)
            default:
                break
            }
        } else {

            // Assuming there was no movement between the first ARFrame and the first reliable
            // camera position and orientation

            if case .normal = frame.camera.trackingState {
                let position = frame.camera.transform.columns.3

                initialReliableCameraPose = InitialPose(
                    position: .init(
                        x: .init(position.x),
                        y: .init(position.y),
                        z: .init(position.z)
                    ),
                    inverseRotation: Quaternion(
                        rotationMatrix: SCNMatrix4(frame.camera.transform)
                    ).inverse
                )
            }
        }
    }
}

// TODO: Improve this...
final class TemporaryCalibrationStorage {
    static let shared = TemporaryCalibrationStorage()

    // We could update the stored calibration at the end of a session
    // so that the user doesn't need to calibrate again when starting a
    // new session (if they've moved the camera).
    //
    // Ideally, we should be tracking the current orientation all the
    // time, so that the user just needs to calibrate once and so that
    // they can move the device between sessions.
    private(set) var calibration: CalibrationResult?

    func save(calibration: CalibrationResult) {
        self.calibration = calibration
    }
}

final class RotatingCamera {

    private weak var client: TCPClient?

    private let radiansPerSecond = .pi/12.0
    private let radius = 3.0
    private let height = 2.0
    private let center = Vector3(x: 0, y: 1.5, z: 0)

    private var currentAngle = 0.0

    private var currentPosition: Vector3 {
        .init(x: cos(currentAngle) * radius, y: height, z: sin(currentAngle) * radius)
    }

    init(client: TCPClient) {
        self.client = client
    }

    private func sendCameraUpdate(pose: Pose) {
        _ = client?.send(data: CameraPositionPayload(position: pose.position).data)
        _ = client?.send(data: CameraRotationPayload(rotation: pose.rotation).data)
    }

    private func lookAt(_ cameraPosition: Vector3, center: Vector3, up: Vector3 = Vector3(x: 0, y: 1, z: 0)) -> SCNMatrix4 {
        let forward = (center - cameraPosition).normalized
        let right = forward.cross(up).normalized
        let updatedUp = right.cross(forward)

        return SCNMatrix4(
            m11: Float(right.x),
            m12: Float(right.y),
            m13: Float(right.z),
            m14: 0.0,
            m21: Float(updatedUp.x),
            m22: Float(updatedUp.y),
            m23: Float(updatedUp.z),
            m24: 0.0,
            m31: Float(-forward.x),
            m32: Float(-forward.y),
            m33: Float(-forward.z),
            m34: 0.0,
            m41: 0.0,
            m42: 0.0,
            m43: 0.0,
            m44: 1.0
        )
    }

    func update(elapsedTime: TimeInterval) {
        currentAngle += elapsedTime * radiansPerSecond
        let currentPosition = self.currentPosition
        sendCameraUpdate(
            pose: .init(position: currentPosition, rotation: Quaternion(rotationMatrix: lookAt(currentPosition, center: center)))
        )
    }
}
