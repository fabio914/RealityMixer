//
//  Double+ScientificString.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation

private let sharedFormatter: NumberFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .scientific
    numberFormatter.positiveFormat = "0.###E+0"
    numberFormatter.decimalSeparator = "."
    numberFormatter.exponentSymbol = "e"
    numberFormatter.maximumFractionDigits = 16
    return numberFormatter
}()

extension Double {

    var scientific: String {
        sharedFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
