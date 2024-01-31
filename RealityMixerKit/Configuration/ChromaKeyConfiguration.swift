//
//  ChromaKeyConfiguration.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 23/05/2021.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public struct ChromaKeyConfiguration: Codable {

    public struct Color: Codable {
        public let red: Float // 0 .. 1
        public let green: Float // 0 .. 1
        public let blue: Float // 0 .. 1

#if os(macOS)
        public init(nsColor: NSColor) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            nsColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
            self.red = Float(red)
            self.green = Float(green)
            self.blue = Float(blue)
        }

        public var nsColor: NSColor {
            NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
#elseif os(iOS)
        public init(uiColor: UIColor) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
            self.red = Float(red)
            self.green = Float(green)
            self.blue = Float(blue)
        }

        public var uiColor: UIColor {
            UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
#endif
    }

    public let color: Color
    public let sensitivity: Float // 0 .. 1
    public let smoothness: Float // 0 .. 1

    public init(color: Color, sensitivity: Float, smoothness: Float) {
        self.color = color
        self.sensitivity = sensitivity
        self.smoothness = smoothness
    }
}

// MARK: - Codable

public extension ChromaKeyConfiguration.Color {

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

public final class ChromaKeyConfigurationStorage {
    private let storage: UserDefaultsStorage<ChromaKeyConfiguration>

    public init(_ deviceId: String? = nil) {
        if let deviceId = deviceId {
            self.storage = .init(key: "ChromaConfiguration-\(deviceId)")
        } else {
            self.storage = .init(key: "ChromaConfiguration")
        }
    }

    public func save(configuration: ChromaKeyConfiguration) throws {
        try storage.save(configuration)
    }

    public var configuration: ChromaKeyConfiguration? {
        storage.object
    }
}

public final class ChromaKeyMaskStorage {
    private let manager = FileManager.default
    private let maskFileName: String

    public init(_ deviceId: String? = nil) {
        if let deviceId = deviceId {
            let sanitized = deviceId.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            self.maskFileName = "\(sanitized)-mask.png"
        } else {
            self.maskFileName = "mask.png"
        }
    }

    var maskURL: URL? {
        manager
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(maskFileName)
    }

#if os(macOS)
    public func update(mask: NSImage?) throws {
        guard let maskURL = maskURL else { return }

        if let mask = mask {
            try mask.pngData()?.write(to: maskURL)
        } else {
            try manager.removeItem(at: maskURL)
        }
    }

    public func load() -> NSImage? {
        maskURL.flatMap(NSImage.init(contentsOf:))
    }

#elseif os(iOS)
    public func update(mask: UIImage?) throws {
        guard let maskURL = maskURL else { return }

        if let mask = mask {
            try mask.pngData()?.write(to: maskURL)
        } else {
            try manager.removeItem(at: maskURL)
        }
    }

    public func load() -> UIImage? {
        maskURL.flatMap({ try? Data(contentsOf: $0) }).flatMap(UIImage.init(data:))
    }
#endif
}

#if os(macOS)

private extension NSImage {

    func pngData() -> Data? {
        let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let bitmapRep = cgImage.flatMap(NSBitmapImageRep.init(cgImage:))
        bitmapRep?.size = self.size
        return bitmapRep?.representation(using: .png, properties: [:])
    }
}

#endif
