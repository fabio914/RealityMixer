import Foundation
import ARKit
import SwiftSocket

struct CameraPosePayload {
    let protocolIdentifier: UInt32 = 13371337
    let px: Float32
    let py: Float32
    let pz: Float32
    let qx: Float32
    let qy: Float32
    let qz: Float32
    let qw: Float32

    init(pose: Pose) {
        self.px = .init(pose.position.x)
        self.py = .init(pose.position.y)
        self.pz = .init(pose.position.z)
        self.qx = .init(pose.rotation.x)
        self.qy = .init(pose.rotation.y)
        self.qz = .init(pose.rotation.z)
        self.qw = .init(pose.rotation.w)
    }

    var data: Data {
        let length = MemoryLayout<CameraPosePayload>.size

        var copy = self
        let data = Data(bytes: &copy, count: length)
        return data
    }
}

final class CameraPoseSender {
    private let port: Int32 = 1337
    private let client: TCPClient

    private struct InitialPose {
        let position: Vector3
        let inverseRotation: Quaternion
    }

    private var initialReliableCameraPose: InitialPose?

    init?(address: String) {
        let client = TCPClient(address: address, port: port)

        // FIXME: This is blocking the main thread.
        guard case .success = client.connect(timeout: 10) else {
            return nil
        }

        self.client = client
    }

    private func sendCameraPoseUpdate(_ pose: Pose) {
        _ = client.send(data: CameraPosePayload(pose: pose).data)
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

                sendCameraPoseUpdate(pose)
            default:
                break
            }
        } else {

            // Assuming there was no movement between the first ARFrame and the first reliable
            // camera position and orientation

            if case .normal = frame.camera.trackingState {
                let position = frame.camera.transform.columns.3

                initialReliableCameraPose = .init(
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

    deinit {
        client.close()
    }
}
