//
//  Vector3+SceneKit.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import SceneKit

extension Vector3 {
    var sceneKitVector: SCNVector3 {
        .init(x, y, z)
    }
}
