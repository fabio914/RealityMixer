//
//  Preference.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

struct Preference: Codable {
    let address: String
}

final class PreferenceStorage {
    private let defaults: UserDefaults
    private let key = "preference"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(preference: Preference) throws {
        let data = try JSONEncoder().encode(preference)
        let string = data.base64EncodedString()
        defaults.setValue(string, forKey: key)
    }

    var preference: Preference? {
        defaults.string(forKey: key)
            .flatMap({ Data(base64Encoded: $0) })
            .flatMap({ try? JSONDecoder().decode(Preference.self, from: $0) })
    }
}
