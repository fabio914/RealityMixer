import Foundation
import SwiftSocket

struct CameraPayload {
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
        let length = MemoryLayout<CameraPayload>.size

        var copy = self
        let data = Data(bytes: &copy, count: length)
        return data
    }
}

final class CameraExperiment {
    let port: Int32 = 1337
    let client: TCPClient

    init?(address: String) {
        let client = TCPClient(address: address, port: port)

        // FIXME: This is blocking the main thread.
        guard case .success = client.connect(timeout: 10) else {
            return nil
        }

        self.client = client
    }

    func sendCameraPoseUpdate(_ pose: Pose) {
        _ = client.send(data: CameraPayload(pose: pose).data)
    }

    deinit {
        client.close()
    }
}
