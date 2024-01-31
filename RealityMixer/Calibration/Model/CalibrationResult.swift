//
//  CalibrationResult.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

struct CalibrationResult {
    let imageSize: Size
    let camera: Matrix3
    let pose: Pose
    let rawPose: Pose
}

extension CalibrationResult {

    var xmlString: String {
        """
        <?xml version="1.0"?>
        <opencv_storage>
            <camera_id>1</camera_id>
            <camera_name>Reality Mixer Camera</camera_name>
            <image_width>1920</image_width>
            <image_height>1080</image_height>
            <camera_matrix type_id="opencv-matrix">
                <rows>3</rows>
                <cols>3</cols>
                <dt>d</dt>
                <data>7.667418047615e+2 0e+0 9.6e+2 0e+0 7.667418047615e+2 5.4e+2 0e+0 0e+0 1e+0</data>
            </camera_matrix>
            <distortion_coefficients type_id="opencv-matrix">
                <rows>8</rows>
                <cols>1</cols>
                <dt>d</dt>
                <data>0. 0. 0. 0. 0. 0. 0. 0.</data>
            </distortion_coefficients>
            <translation type_id="opencv-matrix">
                <rows>3</rows>
                <cols>1</cols>
                <dt>d</dt>
                <data>\(pose.position.x.scientific) \(pose.position.y.scientific) \(pose.position.z.scientific)</data>
            </translation>
            <rotation type_id="opencv-matrix">
                <rows>4</rows>
                <cols>1</cols>
                <dt>d</dt>
                <data>\(pose.rotation.x.scientific) \(pose.rotation.y.scientific) \(pose.rotation.z.scientific) \(pose.rotation.w.scientific)</data>
            </rotation>
            <attachedDevice>3</attachedDevice>
            <camDelayMs>0</camDelayMs>
            <chromaKeyColorRed>0</chromaKeyColorRed>
            <chromaKeyColorGreen>255</chromaKeyColorGreen>
            <chromaKeyColorBlue>0</chromaKeyColorBlue>
            <chromaKeySimilarity>6.0000002384185791e-01</chromaKeySimilarity>
            <chromaKeySmoothRange>2.9999999329447746e-02</chromaKeySmoothRange>
            <chromaKeySpillRange>5.9999998658895493e-02</chromaKeySpillRange>
            <raw_translation type_id="opencv-matrix">
                <rows>3</rows>
                <cols>1</cols>
                <dt>d</dt>
                <data>\(rawPose.position.x.scientific) \(rawPose.position.y.scientific) \(rawPose.position.z.scientific)</data>
            </raw_translation>
            <raw_rotation type_id="opencv-matrix">
                <rows>4</rows>
                <cols>1</cols>
                <dt>d</dt>
                <data>\(rawPose.rotation.x.scientific) \(rawPose.rotation.y.scientific) \(rawPose.rotation.z.scientific) \(rawPose.rotation.w.scientific)</data>
            </raw_rotation>
        </opencv_storage>
        """
    }

    func toFrame() -> CalibrationFrame? {
        xmlString.data(using: .utf8).flatMap({ CalibrationFrame(payloadType: PayloadType.calibrationData.rawValue, data: $0) })
    }
}
