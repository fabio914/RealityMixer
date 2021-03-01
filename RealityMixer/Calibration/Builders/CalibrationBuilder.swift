//
//  CalibrationBuilder.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import ARKit

struct CalibrationBuilder {

    static func fov(from frame: ARFrame) -> (Float, Float) {
        let projection = frame.camera.projectionMatrix
        let yScale = projection[1,1]
        let yFov = 2 * atan(1/yScale)

        let imageResolution = frame.camera.imageResolution
        let xFov = yFov * Float(imageResolution.width / imageResolution.height)
        return (xFov, yFov)
    }

    static func makeCameraMatrix(yFov: Double, imageSize: Size, scaleFactor: Double = 1.0) -> Matrix3 {
        let halfWidth = (Double(imageSize.width) * 0.5)
        let halfHeight = (Double(imageSize.height) * 0.5)

        let focalLength = halfHeight/tan(yFov/2.0)

        return .init(
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

//    static func makeCameraMatrix(frame: ARFrame) -> Matrix3 {
//        let intrinsics = frame.camera.intrinsics
//
//        return .init(
//            m11: Double(intrinsics.columns.0.x),
//            m12: Double(intrinsics.columns.0.y),
//            m13: Double(intrinsics.columns.0.z),
//            m21: Double(intrinsics.columns.1.x),
//            m22: Double(intrinsics.columns.1.y),
//            m23: Double(intrinsics.columns.1.z),
//            m31: Double(intrinsics.columns.2.x),
//            m32: Double(intrinsics.columns.2.y),
//            m33: Double(intrinsics.columns.2.z)
//        )
//    }

    static func buildCalibration(
        scaleFactor: Double,
        cameraOrigin: Vector3,
        rightControllerPosition: Vector3,
        rightControllerScreenCoordinates: CGPoint,
        centerPose: Pose,
        frame: ARFrame
    ) -> (SCNMatrix4, CalibrationResult) {
        let imageResolution = frame.camera.imageResolution
        let (xFov, yFov) = fov(from: frame)

        let anglePerVerticalPixel = yFov/Float(imageResolution.height)
        let anglePerHorizontalPixel = xFov/Float(imageResolution.width)

        let centerVerticalAngle = yFov/2.0
        let centerHorizontalAngle = xFov/2.0

        let rightControllerDeltaVerticalAngle = (Float(rightControllerScreenCoordinates.y) * anglePerVerticalPixel) - centerVerticalAngle
        let rightControllerDeltaHorizontalAngle = (Float(rightControllerScreenCoordinates.x) * anglePerHorizontalPixel) - centerHorizontalAngle

        let forwardVector = (rightControllerPosition - cameraOrigin).normalized
        let tempUpVector = Vector3(x: 0, y: 1, z: 0)

        // Right vector and up vector for the direction of the right controller

        let rightVector = forwardVector.cross(tempUpVector).normalized
        let upVector = rightVector.cross(forwardVector)

        // Rotate right vector rightControllerDeltaHorizontalAngle around up vector

        let right2 = (Double(cos(rightControllerDeltaHorizontalAngle)) * rightVector) + (Double(sin(rightControllerDeltaHorizontalAngle)) * (upVector.cross(rightVector)))

        // Rotate up vector rightControllerDeltaVerticalAngle around the new right vector

        let up2 = (Double(cos(rightControllerDeltaVerticalAngle)) * upVector) + (Double(sin(rightControllerDeltaVerticalAngle)) * (right2.cross(upVector)))

        let forward2 = up2.cross(right2)

        let lookAt = SCNMatrix4(
            m11: Float(right2.x),
            m12: Float(up2.x),
            m13: Float(-forward2.x),
            m14: 0.0,
            m21: Float(right2.y),
            m22: Float(up2.y),
            m23: Float(-forward2.y),
            m24: 0.0,
            m31: Float(right2.z),
            m32: Float(up2.z),
            m33: Float(-forward2.z),
            m34: 0.0,
            m41: 0.0,
            m42: 0.0,
            m43: 0.0,
            m44: 1.0
        )

        let translation = SCNMatrix4MakeTranslation(Float(-cameraOrigin.x), Float(-cameraOrigin.y), Float(-cameraOrigin.z))
        let transform = SCNMatrix4Mult(translation, lookAt)

        // Transposing to get the inverse rotation

        let transposed = SCNMatrix4(
            m11: Float(right2.x),
            m12: Float(right2.y),
            m13: Float(right2.z),
            m14: 0.0,
            m21: Float(up2.x),
            m22: Float(up2.y),
            m23: Float(up2.z),
            m24: 0.0,
            m31: Float(-forward2.x),
            m32: Float(-forward2.y),
            m33: Float(-forward2.z),
            m34: 0.0,
            m41: 0.0,
            m42: 0.0,
            m43: 0.0,
            m44: 1.0
        )

        let cameraPose = Pose(
            position: cameraOrigin,
            rotation: Quaternion(rotationMatrix: transposed)
        )

        let imageSize = Size(width: Int(imageResolution.width), height: Int(imageResolution.height))

        return (
            transform,
            CalibrationResult(
                imageSize: imageSize * scaleFactor,
                camera: makeCameraMatrix(yFov: Double(yFov), imageSize: imageSize, scaleFactor: scaleFactor),
                pose: cameraPose,
                rawPose: centerPose
            )
        )
    }
}

