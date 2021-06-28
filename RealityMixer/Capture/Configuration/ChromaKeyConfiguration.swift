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
            UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
    }

    let color: Color
    let sensitivity: Float // 0 .. 1
    let smoothness: Float // 0 .. 1

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

final class ChromaKeyMaskStorage {
    private let manager = FileManager.default

    var maskURL: URL? {
        manager
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("mask.png")
    }

    func update(mask: UIImage?) throws {
        guard let maskURL = maskURL else { return }

        if let mask = mask {
            try mask.pngData()?.write(to: maskURL)
        } else {
            try manager.removeItem(at: maskURL)
        }
    }

    func load() -> UIImage? {
        maskURL.flatMap({ try? Data(contentsOf: $0) }).flatMap(UIImage.init(data:))
    }
}
