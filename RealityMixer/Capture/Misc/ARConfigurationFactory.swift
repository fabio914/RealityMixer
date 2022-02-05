//
//  ARConfigurationFactory.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 09/05/2021.
//

import Foundation
import ARKit

final class ARConfigurationFactory {
    private let mrConfiguration: MixedRealityConfiguration

    init(mrConfiguration: MixedRealityConfiguration) {
        self.mrConfiguration = mrConfiguration
    }

    func build() -> ARConfiguration {
        switch mrConfiguration.captureMode {
        case .personSegmentation:
            return buildPersonSegmentationConfiguration()
        case .bodyTracking:
            return buildBodyTrackingConfiguration()
        case .greenScreen, .raw:
            return buildWorldTrackingConfiguration()
        }
    }

    private func buildWorldTrackingConfiguration() -> ARConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
//        configuration.isAutoFocusEnabled = mrConfiguration.enableAutoFocus
        return configuration
    }

    private func buildPersonSegmentationConfiguration() -> ARConfiguration {
        let configuration = buildWorldTrackingConfiguration()

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        }

        return configuration
    }

    private func buildBodyTrackingConfiguration() -> ARConfiguration {
        guard ARBodyTrackingConfiguration.isSupported else {
            return buildWorldTrackingConfiguration()
        }

        let configuration = ARBodyTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = mrConfiguration.enableAutoFocus
        return configuration
    }

    func buildAvatar(bodyAnchor: ARBodyAnchor) -> AvatarProtocol? {
        guard case .bodyTracking(let avatarType) = mrConfiguration.captureMode else {
            return nil
        }

        switch avatarType {
        case .avatar1, .avatar2, .avatar3, .avatar4:
            return ReadyPlayerMeAvatar(bodyAnchor: bodyAnchor, avatarName: avatarType.rawValue)
        case .robot:
            return RobotAvatar(bodyAnchor: bodyAnchor)
        case .skeleton:
            return Skeleton(bodyAnchor: bodyAnchor)
        }
    }
}
