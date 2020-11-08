//
//  Definitions.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/8/20.
//

import Foundation

struct Definitions {

    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    static var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
    }

    static let gitHubURL: URL! = URL(string: "https://github.com/fabio914/OculusQuestMixedRealityForiOS")

    static let twitterURL: URL! = URL(string: "https://twitter.com/reality_mixer")

    static let instructionsURL: URL! = URL(string: "https://github.com/fabio914/OculusQuestMixedRealityForiOS/blob/main/Instructions.md")

    static let oculusMRCapp: URL! = URL(string: "https://www.oculus.com/experiences/quest/2532132800176262/")
}
