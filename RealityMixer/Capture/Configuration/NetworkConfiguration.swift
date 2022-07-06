//
//  Preference.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import RealityMixerKit

struct NetworkConfiguration: Codable {
    let address: String
}

final class NetworkConfigurationStorage {
    private let storage = UserDefaultsStorage<NetworkConfiguration>(key: "preference")

    func save(configuration: NetworkConfiguration) throws {
        try storage.save(configuration)
    }

    var configuration: NetworkConfiguration? {
        storage.object
    }
}
