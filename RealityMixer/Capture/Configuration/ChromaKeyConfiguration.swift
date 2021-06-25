//
//  ChromaKeyConfiguration.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 23/05/2021.
//

import UIKit

struct ChromaKeyConfiguration: Codable {

    struct Color: Codable {
        let red: Float // 0 .. 1
        let green: Float // 0 .. 1
        let blue: Float // 0 .. 1

        init(uiColor: UIColor) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
            self.red = Float(red)
            self.green = Float(green)
            self.blue = Float(blue)
        }

        var uiColor: UIColor {
            UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 0)
        }
    }

    enum ChromaKeyMode: Codable {
        case smooth(
            sensitivity: Float, // 0 .. 1
            smoothness: Float // 0 .. 1
        )
        case threshold(Float) // 0 .. 1
    }

    let color: Color
    let mode: ChromaKeyMode

    // TODO: Add support for a Mask texture to allow the users
    // to hide parts of the video outside of the green screen.
}

// MARK: - Codable

extension ChromaKeyConfiguration.Color {

    enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.red = max(0.0, min(1.0, try values.decode(Float.self, forKey: .red)))
        self.green = max(0.0, min(1.0, try values.decode(Float.self, forKey: .green)))
        self.blue = max(0.0, min(1.0, try values.decode(Float.self, forKey: .blue)))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
    }
}

extension ChromaKeyConfiguration.ChromaKeyMode {

    enum CodingKeys: String, CodingKey {
        case type
        case sensitivity
        case smoothness
        case threshold
    }

    enum ChromaKeyType: String, Codable {
        case smooth
        case threshold
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(ChromaKeyType.self, forKey: .type)

        switch type {
        case .smooth:
            let sensitivity = max(0.0, min(1.0, try values.decode(Float.self, forKey: .sensitivity)))
            let smoothness = max(0.0, min(1.0, try values.decode(Float.self, forKey: .smoothness)))
            self = .smooth(sensitivity: sensitivity, smoothness: smoothness)
        case .threshold:
            let threshold = max(0.0, min(1.0, try values.decode(Float.self, forKey: .threshold)))
            self = .threshold(threshold)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .smooth(let sensitivity, let smoothness):
            try container.encode(ChromaKeyType.smooth, forKey: .type)
            try container.encode(sensitivity, forKey: .sensitivity)
            try container.encode(smoothness, forKey: .smoothness)
        case .threshold(let value):
            try container.encode(ChromaKeyType.threshold, forKey: .type)
            try container.encode(value, forKey: .threshold)
        }
    }
}

// MARK: - Storage

final class ChromaKeyConfigurationStorage {
    private let storage = UserDefaultsStorage<ChromaKeyConfiguration>(key: "ChromaConfiguration")

    func save(configuration: ChromaKeyConfiguration) throws {
        try storage.save(configuration)
    }

    var configuration: ChromaKeyConfiguration? {
        storage.object
    }
}
