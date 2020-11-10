//
//  CalibrationSceneNodeBuilder.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/6/20.
//

import Foundation
import SceneKit
import SceneKit.ModelIO

struct CalibrationSceneNodes {
    let main: SCNNode

    // Child nodes
    let rightController: SCNNode
    let leftController: SCNNode
    let headset: SCNNode
}

struct CalibrationSceneNodeBuilder {

    static func model(named name: String) -> SCNNode? {
        Bundle.main.url(forResource: name, withExtension: "stl")
            .flatMap(MDLAsset.init(url:))
            .flatMap({ asset -> MDLMesh? in
                guard asset.count > 0 else { return nil }
                return asset.object(at: 0) as? MDLMesh
            })
            .flatMap({ SCNNode(mdlObject: $0) })
    }

    static func build() -> CalibrationSceneNodes {
        let mainNode = SCNNode()

        let leftController: SCNNode! = model(named: "left")
        leftController.geometry?.firstMaterial?.lightingModel = .constant
        leftController.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        leftController.rotation = SCNVector4(1, 0, 0, 45.0 * .pi/180.0)

        let leftControllerNode = SCNNode()
        leftControllerNode.addChildNode(leftController)
        mainNode.addChildNode(leftControllerNode)

        let rightController: SCNNode! = model(named: "right")
        rightController.geometry?.firstMaterial?.lightingModel = .constant
        rightController.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        rightController.rotation = SCNVector4(1, 0, 0, 45.0 * .pi/180.0)

        let rightControllerNode = SCNNode()
        rightControllerNode.addChildNode(rightController)
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
