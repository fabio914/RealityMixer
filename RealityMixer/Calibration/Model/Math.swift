//
//  Math.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import SceneKit
import simd

typealias Vector3 = simd_double3

extension Vector3 {

    var norm: Double {
        sqrt(x*x + y*y + z*z)
    }

    var normalized: Vector3 {
        normalize(self)
    }

    func cross(_ other: Vector3) -> Vector3 {
        simd.cross(self, other)
    }
}

typealias Quaternion = simd_quatd

extension Quaternion {

    var x: Double { vector.x }
    var y: Double { vector.y }
    var z: Double { vector.z }
    var w: Double { vector.w }

    var eulerAngles: Vector3 {
        let sinr_cosp = 2.0 * (w * x + y * z)
        let cosr_cosp = 1.0 - 2.0 * (x * x + y * y)
        let roll = atan2(sinr_cosp, cosr_cosp)

        let sinp = 2.0 * (w * y - z * x)
        let pitch = abs(sinp) >= 1.0 ? copysign(.pi/2.0, sinp):asin(sinp)

        let siny_cosp = 2.0 * (w * z + x * y)
        let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
        let yaw = atan2(siny_cosp, cosy_cosp)

        return Vector3(x: roll, y: pitch, z: yaw)
    }

    static func * (_ lhs: Quaternion, _ rhs: Vector3) -> Vector3 {
        let num = lhs.x * 2.0
        let num2 = lhs.y * 2.0
        let num3 = lhs.z * 2.0
        let num4 = lhs.x * num
        let num5 = lhs.y * num2
        let num6 = lhs.z * num3
        let num7 = lhs.x * num2
        let num8 = lhs.x * num3
        let num9 = lhs.y * num3
        let num10 = lhs.w * num
        let num11 = lhs.w * num2
        let num12 = lhs.w * num3

        return .init(
            x: (1.0 - (num5 + num6)) * rhs.x + (num7 - num12) * rhs.y + (num8 + num11) * rhs.z,
            y: (num7 + num12) * rhs.x + (1.0 - (num4 + num6)) * rhs.y + (num9 - num10) * rhs.z,
            z: (num8 - num11) * rhs.x + (num9 + num10) * rhs.y + (1.0 - (num4 + num5)) * rhs.z
        )
    }

    init(rotationMatrix m: SCNMatrix4) {
        self.init(simd_double4x4(m))
    }

    init(x: Double, y: Double, z: Double, w: Double) {
        self.init(vector: .init(x: x, y: y, z: z, w: w))
    }
}

typealias Matrix3 = simd_double3x3

extension Matrix3 {
    var m11: Double { self[0, 0] }
    var m12: Double { self[0, 1] }
    var m13: Double { self[0, 2] }
    var m21: Double { self[1, 0] }
    var m22: Double { self[1, 1] }
    var m23: Double { self[1, 2] }
    var m31: Double { self[2, 0] }
    var m32: Double { self[2, 1] }
    var m33: Double { self[2, 2] }

    init(
        m11: Double,
        m12: Double,
        m13: Double,
        m21: Double,
        m22: Double,
        m23: Double,
        m31: Double,
        m32: Double,
        m33: Double
    ) {
      self.init([
          .init(x: m11, y: m12, z: m13),
          .init(x: m21, y: m22, z: m23),
          .init(x: m31, y: m32, z: m33)
      ])
    }
}

struct Size {
    let width: Int
    let height: Int

    static func * (_ lhs: Size, _ rhs: Double) -> Size {
        .init(width: Int(Double(lhs.width) * rhs), height: Int(Double(lhs.height) * rhs))
    }
}

struct Pose {
    let position: Vector3
    let rotation: Quaternion

    var inverse: Pose {
        let inverseRotation = rotation.inverse

        return .init(
            position: inverseRotation * (-1.0 * position),
            rotation: inverseRotation
        )
    }

    static func * (_ lhs: Pose, _ rhs: Pose) -> Pose {
        .init(
            position: lhs.position + (lhs.rotation * rhs.position),
            rotation: lhs.rotation * rhs.rotation
        )
    }
}
