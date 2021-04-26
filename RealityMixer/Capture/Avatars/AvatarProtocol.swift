//
//  AvatarProtocol.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 26/04/2021.
//

import ARKit

protocol AvatarProtocol: AnyObject {
    var mainNode: SCNNode { get }
    init?(bodyAnchor: ARBodyAnchor)
    func update(bodyAnchor: ARBodyAnchor)
}
