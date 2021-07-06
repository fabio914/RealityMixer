//
//  MixedRealityConfiguration.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 12/01/2021.
//

import Foundation

struct MixedRealityConfiguration: Codable, Equatable {

    enum CaptureMode: Codable, Equatable {
        enum AvatarType: String, Codable, Equatable {
            case avatar1
            case avatar2
            case avatar3
            case avatar4
            case robot
            case skeleton
        }

        case personSegmentation
        case bodyTracking(avatar: AvatarType)
        case greenScreen
        case raw
    }

    struct ForegroundLayerOptions: Codable, Equatable {
        enum ForegroundVisibility: Codable, Equatable {
            case visible(useMagentaAsTransparency: Bool)
            case hidden
        }

        let visibility: ForegroundVisibility
    }

    struct BackgroundLayerOptions: Codable, Equatable {
        enum BackgroundVisibility: Codable, Equatable {
            enum ChromaKey: String, Codable, Equatable {
                case black
                case green
                case magenta
            }

            case visible
            case chromaKey(color: ChromaKey)
            case hidden
        }

        let visibility: BackgroundVisibility
    }

    let captureMode: CaptureMode
    let enableMovingCamera: Bool
    let enableAutoFocus: Bool
    let shouldFlipOutput: Bool

    enum FrameRate: Int, Codable, Equatable {
        case thirty = 30
        case sixty = 60
    }

    let frameRate: FrameRate

    let foregroundLayerOptions: ForegroundLayerOptions
    let backgroundLayerOptions: BackgroundLayerOptions

    static let defaultConfiguration = MixedRealityConfiguration(
        captureMode: CaptureMode.personSegmentation.isSupported ? .personSegmentation:.greenScreen,
        enableMovingCamera: false,
        enableAutoFocus: false,
        shouldFlipOutput: true,
        frameRate: .sixty,
        foregroundLayerOptions: .init(visibility: .visible(useMagentaAsTransparency: false)),
        backgroundLayerOptions: .init(visibility: .visible)
    )
}

// MARK: - Codable

extension MixedRealityConfiguration.CaptureMode {

    enum CodingKeys: String, CodingKey {
        case type
        case avatar
    }

    enum CaptureType: String, Codable {
        case personSegmentation
        case bodyTracking
        case greenScreen
        case raw
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(CaptureType.self, forKey: .type)

        switch type {
        case .personSegmentation:
            self = .personSegmentation
        case .bodyTracking:
            let avatarType = try values.decode(AvatarType.self, forKey: .avatar)
            self = .bodyTracking(avatar: avatarType)
        case .greenScreen:
            self = .greenScreen
        case .raw:
            self = .raw
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .personSegmentation:
            try container.encode(CaptureType.personSegmentation, forKey: .type)
        case .bodyTracking(let avatarType):
            try container.encode(CaptureType.bodyTracking, forKey: .type)
            try container.encode(avatarType, forKey: .avatar)
        case .greenScreen:
            try container.encode(CaptureType.greenScreen, forKey: .type)
        case .raw:
            try container.encode(CaptureType.raw, forKey: .type)
        }
    }
}

extension MixedRealityConfiguration.ForegroundLayerOptions.ForegroundVisibility {

    enum CodingKeys: String, CodingKey {
        case type
        case magentaAsTransparency
    }

    enum VisibilityType: String, Codable {
        case visible
        case hidden
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(VisibilityType.self, forKey: .type)

        switch type {
        case .visible:
            let magentaAsTransparency = try values.decode(Bool.self, forKey: .magentaAsTransparency)
            self = .visible(useMagentaAsTransparency: magentaAsTransparency)
        case .hidden:
            self = .hidden
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .visible(let magentaAsTransparency):
            try container.encode(VisibilityType.visible, forKey: .type)
            try container.encode(magentaAsTransparency, forKey: .magentaAsTransparency)
        case .hidden:
            try container.encode(VisibilityType.hidden, forKey: .type)
        }
    }
}

extension MixedRealityConfiguration.BackgroundLayerOptions.BackgroundVisibility {

    enum CodingKeys: String, CodingKey {
        case type
        case chromaColor
    }

    enum VisibilityType: String, Codable {
        case visible
        case chromaKey
        case hidden
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(VisibilityType.self, forKey: .type)

        switch type {
        case .visible:
            self = .visible
        case .chromaKey:
            let chromaColor = try values.decode(ChromaKey.self, forKey: .chromaColor)
            self = .chromaKey(color: chromaColor)
        case .hidden:
            self = .hidden
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .visible:
            try container.encode(VisibilityType.visible, forKey: .type)
        case .chromaKey(let chromaColor):
            try container.encode(VisibilityType.chromaKey, forKey: .type)
            try container.encode(chromaColor, forKey: .chromaColor)
        case .hidden:
            try container.encode(VisibilityType.hidden, forKey: .type)
        }
    }
}

// MARK: - Storage

final class MixedRealityConfigurationStorage {
    private let storage = UserDefaultsStorage<MixedRealityConfiguration>(key: "MRConfiguration")

    func save(configuration: MixedRealityConfiguration) throws {
        try storage.save(configuration)
    }

    var configuration: MixedRealityConfiguration {
        storage.object ?? .defaultConfiguration
    }
}

// MARK: - Support

import ARKit

extension MixedRealityConfiguration.CaptureMode {

    var isSupported: Bool {
        switch self {
        case .personSegmentation:
            return ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) ||
                ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation)
        case .bodyTracking:
            return ARBodyTrackingConfiguration.isSupported
        case .greenScreen, .raw:
            return true
        }
    }
}
