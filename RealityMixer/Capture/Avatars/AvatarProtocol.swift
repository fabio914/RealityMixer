//
//  AvatarProtocol.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 26/04/2021.
//

import ARKit

protocol AvatarProtocol: AnyObject {
    var mainNode: SCNNode { get }
    func update(bodyAnchor: ARBodyAnchor)
}
