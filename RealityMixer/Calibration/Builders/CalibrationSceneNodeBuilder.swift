//
//  CalibrationSceneNodeBuilder.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import SceneKit

struct CalibrationSceneNodes {
    let main: SCNNode

    // Child nodes
    let rightController: SCNNode
    let leftController: SCNNode
    let headset: SCNNode
}

struct CalibrationSceneNodeBuilder {

    static func build() -> CalibrationSceneNodes {
        let radius = 0.0125
        let height = 0.12

        let mainNode = SCNNode()

        let leftController = SCNCylinder()
        leftController.radius = CGFloat(radius)
        leftController.height = CGFloat(height)

        leftController.firstMaterial?.lightingModel = .constant
        leftController.firstMaterial?.diffuse.contents = UIColor.red

        let leftControllerNode = SCNNode()
        leftControllerNode.geometry = leftController
        mainNode.addChildNode(leftControllerNode)

        let rightController = SCNCylinder()
        rightController.radius = CGFloat(radius)
        rightController.height = CGFloat(height)

        rightController.firstMaterial?.lightingModel = .constant
        rightController.firstMaterial?.diffuse.contents = UIColor.blue

        let rightControllerNode = SCNNode()
        rightControllerNode.geometry = rightController
        mainNode.addChildNode(rightControllerNode)

        // Using Quest 2 dimensions
        let headset = SCNBox(width: 0.1915, height: 0.102, length: 0.1425, chamferRadius: 0)
        headset.firstMaterial?.lightingModel = .constant
        headset.firstMaterial?.diffuse.contents = UIColor.gray

        let headsetNode = SCNNode()
        headsetNode.geometry = headset
        mainNode.addChildNode(headsetNode)

        return .init(
            main: mainNode,
            rightController: rightControllerNode,
            leftController: leftControllerNode,
            headset: headsetNode
        )
    }
}
