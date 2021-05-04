import Foundation

struct MixedRealityConfiguration: Codable, Equatable {

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

    let shouldRecord: Bool
    let enableAudio: Bool
    let enableAutoFocus: Bool
    let enablePersonSegmentation: Bool
    let shouldFlipOutput: Bool

    let foregroundLayerOptions: ForegroundLayerOptions
    let backgroundLayerOptions: BackgroundLayerOptions

    static let defaultConfiguration = MixedRealityConfiguration(
        shouldRecord: true,
        enableAudio: true,
        enableAutoFocus: true,
        enablePersonSegmentation: true,
        shouldFlipOutput: true,
        foregroundLayerOptions: .init(visibility: .visible(useMagentaAsTransparency: false)),
        backgroundLayerOptions: .init(visibility: .visible)
    )
}

// MARK: - Codable

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

final class ConfigurationStorage {
    private let defaults: UserDefaults
    private let key = "MRConfiguration"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(configuration: MixedRealityConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        let string = data.base64EncodedString()
        defaults.setValue(string, forKey: key)
    }

    var configuration: MixedRealityConfiguration {
        defaults.string(forKey: key)
            .flatMap({ Data(base64Encoded: $0) })
            .flatMap({ try? JSONDecoder().decode(MixedRealityConfiguration.self, from: $0) })
        ?? .defaultConfiguration
    }
}
