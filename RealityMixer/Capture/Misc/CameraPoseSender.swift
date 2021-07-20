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
    let unknown1: UInt32 = 100 // Timestamp? Delay?
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
    let unknown1: UInt32 = 100 // Timestamp? Delay?
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
    let unknown1: UInt32 = 100 // Timestamp? Delay?
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
    private let initialCalibrationPose: Pose

    init?(client: TCPClient) {
        guard let pose = TemporaryCalibrationStorage.shared.calibrationPose else {
            return nil
        }

        self.initialCalibrationPose = pose
        self.client = client
    }

    private func sendCameraUpdate(pose: Pose/*, intrinsics: CameraIntrinsicsPayload*/) {
//        _ = client?.send(data: intrinsics.data)
        _ = client?.send(data: CameraPositionPayload(position: pose.position).data)
        _ = client?.send(data: CameraRotationPayload(rotation: pose.rotation).data)
    }

    private func updateCached(pose: Pose) {
        TemporaryCalibrationStorage.shared.update(pose: pose)
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

                let poseResult = initialCalibrationPose * pose
                sendCameraUpdate(pose: poseResult /*, intrinsics: intrinsics*/)
                updateCached(pose: poseResult)
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

    // Ideally, we should be tracking the current orientation all the
    // time, so that the user just needs to calibrate once and so that
    // they can move the device between sessions.
    //
    // This won't work if the user has moved the camera between Mixed Reality
    // sessions.
//    private(set) var calibration: CalibrationResult?
    private(set) var calibrationPose: Pose?

    var hasCalibration: Bool {
        calibrationPose != nil
    }

    func save(calibration: CalibrationResult) {
//        self.calibration = calibration
        self.calibrationPose = calibration.pose
    }

    func update(pose: Pose) {
        self.calibrationPose = pose
    }
}

final class ParallaxCamera {
    private weak var client: TCPClient?

    private let rightEyePosition: Vector3
    private let leftEyePosition: Vector3
    private let rotation: Quaternion

    private var count = 0

    init?(client: TCPClient) {
        guard let pose = TemporaryCalibrationStorage.shared.calibrationPose else {
            return nil
        }

        let ipd = 0.06 // meters

        let rotationMatrix = SCNMatrix4(simd_double4x4(pose.rotation))
        let rightVector = Vector3(
            Double(rotationMatrix.m11), Double(rotationMatrix.m12), Double(rotationMatrix.m13)
        ).normalized

        self.rightEyePosition = pose.position + (0.5 * ipd) * rightVector
        self.leftEyePosition = pose.position - (0.5 * ipd) * rightVector
        self.rotation = pose.rotation
        self.client = client
    }

    private func sendCameraUpdate(pose: Pose) {
        _ = client?.send(data: CameraPositionPayload(position: pose.position).data)
        _ = client?.send(data: CameraRotationPayload(rotation: pose.rotation).data)
    }

    func update(elapsedTime: TimeInterval) {
        if count == 0 {
            sendCameraUpdate(
                pose: .init(position: rightEyePosition, rotation: rotation)
            )
        } else {
            sendCameraUpdate(
                pose: .init(position: leftEyePosition, rotation: rotation)
            )
        }

        count = (count + 1) % 2
     }
}

/*

 ffmpeg -y -i test.mov -c copy -f h264 test.h264

 ffmpeg -y -r 45 -i test.h264 -c copy test.mp4



 ffmpeg -i test.mp4 -an -vcodec rawvideo -pix_fmt yuv420p rawbitstream.yuv

 ffmpeg -r 2 -s 1718x1200 -i rawbitstream.yuv -filter:v select="mod(n-1\,2)" -c:v rawvideo -r 1 -format rawvideo -pix_fmt yuv420p -an odd.yuv

 ffmpeg -r 2 -s 1718x1200 -i rawbitstream.yuv -filter:v select="not(mod(n-1\,2))" -c:v rawvideo -r 1 -format rawvideo -pix_fmt yuv420p -an even.yuv

 ffmpeg -f rawvideo -vcodec rawvideo -s 1718x1200 -r 22.5 -pix_fmt yuv420p -i odd.yuv -c:v libx264 -preset fast -qp 0 odd.mp4

 ffmpeg -f rawvideo -vcodec rawvideo -s 1718x1200 -r 22.5 -pix_fmt yuv420p -i even.yuv -c:v libx264 -preset fast -qp 0 even.mp4

 */
