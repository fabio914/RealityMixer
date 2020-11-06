//
//  CGPoint+Extensions.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import UIKit

extension CGPoint {

    func distance(to other: CGPoint) -> CGFloat {
        CGFloat(sqrt(pow(Double(other.x - x), 2.0) + pow(Double(other.y - y), 2.0)))
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}
