//
//  UserDefaultsStorage.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 23/05/2021.
//

import Foundation

final class UserDefaultsStorage<T: Codable> {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    func save(_ object: T) throws {
        let data = try JSONEncoder().encode(object)
        let string = data.base64EncodedString()
        defaults.setValue(string, forKey: key)
    }

    var object: T? {
        defaults.string(forKey: key)
            .flatMap({ Data(base64Encoded: $0) })
            .flatMap({ try? JSONDecoder().decode(T.self, from: $0) })
    }
}
