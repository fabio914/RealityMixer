//
//  Math.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import SceneKit

struct Vector3 {
    let x: Double
    let y: Double
    let z: Double

    var norm: Double {
        sqrt(x*x + y*y + z*z)
    }

    var normalized: Vector3 {
        let norm = self.norm
        guard norm != 0 else { return .init(x: 0, y: 0, z: 0) }
        return self/norm
    }

    static func + (_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
        .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
        .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    func cross(_ other: Vector3) -> Vector3 {
        .init(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    static func * (_ lhs: Double, _ rhs: Vector3) -> Vector3 {
        .init(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }

    static func / (_ lhs: Vector3, _ rhs: Double) -> Vector3 {
        .init(x: lhs.x/rhs, y: lhs.y/rhs, z: lhs.z/rhs)
    }
}

struct Quaternion {
    let x: Double
    let y: Double
    let z: Double
    let w: Double

    var normSquared: Double {
        x * x + y * y + z * z + w * w
    }

    var inverse: Quaternion {
        .init(x: -x/normSquared, y: -y/normSquared, z: -z/normSquared, w: w/normSquared)
    }

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

    init(rotationMatrix m: simd_float4x4) {
        let tr: Float = m[0][0] + m[1][1] + m[2][2]

        if tr > 0 {
            let s: Float = sqrt(tr+1.0) * 2.0 // S=4*qw
            self.w = Double(0.25 * s)
            self.x = Double((m[1][2] - m[2][1])/s)
            self.y = Double((m[2][0] - m[0][2])/s)
            self.z = Double((m[0][1] - m[1][0])/s)
        } else if (m[0][0] > m[1][1]) && (m[0][0] > m[2][2]) {
            let s: Float = sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2.0 // S=4*qx
            self.w = Double((m[1][2] - m[2][1])/s)
            self.x = Double(0.25 * s)
            self.y = Double((m[1][0] + m[0][1])/s)
            self.z = Double((m[2][0] + m[0][2])/s)
        } else if m[1][1] > m[2][2] {
            let s: Float = sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2.0 // S=4*qy
            self.w = Double((m[2][0] - m[0][2])/s)
            self.x = Double((m[1][0] + m[0][1])/s)
            self.y = Double(0.25 * s)
            self.z = Double((m[2][1] + m[1][2])/s)
        } else {
            let s: Float = sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2.0 // S=4*qz
            self.w = Double((m[0][1] - m[1][0])/s)
            self.x = Double((m[2][0] + m[0][2])/s)
            self.y = Double((m[2][1] + m[1][2])/s)
            self.z = Double(0.25 * s)
        }
    }

    init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    init(roll: Double, pitch: Double, yaw: Double) {
        let cos_roll_2 = cos(roll/2.0)
        let sin_roll_2 = sin(roll/2.0)
        let cos_pitch_2 = cos(pitch/2.0)
        let sin_pitch_2 = sin(pitch/2.0)
        let cos_yaw_2 = cos(yaw/2.0)
        let sin_yaw_2 = sin(yaw/2.0)

        x = sin_roll_2 * cos_pitch_2 * cos_yaw_2 - cos_roll_2 * sin_pitch_2 * sin_yaw_2
        y = cos_roll_2 * sin_pitch_2 * cos_yaw_2 + sin_roll_2 * cos_pitch_2 * sin_yaw_2
        z = cos_roll_2 * cos_pitch_2 * sin_yaw_2 - sin_roll_2 * sin_pitch_2 * cos_yaw_2
        w = cos_roll_2 * cos_pitch_2 * cos_yaw_2 + sin_roll_2 * sin_pitch_2 * sin_yaw_2
    }

    static func * (_ lhs: Quaternion, _ rhs: Quaternion) -> Quaternion {
        .init(
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y + lhs.y * rhs.w + lhs.z * rhs.x - lhs.x * rhs.z,
            z: lhs.w * rhs.z + lhs.z * rhs.w + lhs.x * rhs.y - lhs.y * rhs.x,
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
        )
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
}

struct Matrix3 {
    let m11: Double
    let m12: Double
    let m13: Double
    let m21: Double
    let m22: Double
    let m23: Double
    let m31: Double
    let m32: Double
    let m33: Double
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
