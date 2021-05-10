//
//  RobotAvatar.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 26/04/2021.
//

import ARKit

final class RobotAvatar: AvatarProtocol {
    private(set) var mainNode: SCNNode

    init?(bodyAnchor: ARBodyAnchor) {
        let maybeAvatarReferenceNode = Bundle.main
            .url(forResource: "robot", withExtension: "usdz")
            .flatMap(SCNReferenceNode.init(url:))

        guard let avatarNode = maybeAvatarReferenceNode else {
            return nil
        }

        avatarNode.load()
        avatarNode.transform = SCNMatrix4(bodyAnchor.transform)
        mainNode = avatarNode
    }

    func update(bodyAnchor: ARBodyAnchor) {
        mainNode.transform = SCNMatrix4(bodyAnchor.transform)

        let skeleton = bodyAnchor.skeleton
        let jointLocalTransforms = skeleton.jointLocalTransforms

        for (i, jointLocalTransform) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            guard parentIndex != -1,
                let node = mainNode.childNode(withName: jointName, recursively: true)
            else {
                continue
            }

            node.transform = .init(jointLocalTransform)
        }
    }
}
