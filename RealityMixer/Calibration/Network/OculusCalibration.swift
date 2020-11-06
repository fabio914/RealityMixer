//
//  OculusCalibration.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

protocol OculusCalibrationDelegate: AnyObject {
    func oculusCalibration(_ oculusCalibration: OculusCalibration, didReceiveCalibrationXMLString: String)
    func oculusCalibration(_ oculusCalibration: OculusCalibration, didUpdatePose: PoseUpdate)
    func oculusCalibrationDidPressPrimaryButton(_ oculusCalibration: OculusCalibration)
    func oculusCalibrationDidPressSecondaryButton(_ oculusCalibration: OculusCalibration)
    func oculusCalibrationDidPause(_ oculusCalibration: OculusCalibration)
}

final class OculusCalibration {
    weak var delegate: OculusCalibrationDelegate?
    private let frameCollection = CalibrationFrameCollection()
    private let dataVersion = 1

    init(delegate: OculusCalibrationDelegate? = nil) {
        self.delegate = delegate
    }

    func add(data: Data) {
        frameCollection.add(data: data)

        while let frame = frameCollection.next() {
            if let payload = Payload(from: frame) {
                process(payload)
            }
        }
    }

    private func process(_ payload: Payload) {
        switch payload {
        case .dataVersion(let version):
            if version != dataVersion {
                print("Unknown data version detected!")
            }
        case .calibrationData(let xmlString):
            delegate?.oculusCalibration(self, didReceiveCalibrationXMLString: xmlString)
        case .poseUpdate(let poseUpdate):
            delegate?.oculusCalibration(self, didUpdatePose: poseUpdate)
        case .primaryButtonPressed:
            delegate?.oculusCalibrationDidPressPrimaryButton(self)
        case .secondaryButtonPressed:
            delegate?.oculusCalibrationDidPressSecondaryButton(self)
        case .stateChangePause:
            delegate?.oculusCalibrationDidPause(self)
        default:
            break
        }
    }
}
