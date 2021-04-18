//
//  Skeleton.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 18/04/2021.
//

import UIKit
import ARKit

final class Skeleton {
    var mainNode: SCNNode
    private var joints: [String: SCNNode]
    private var cylindersNode: SCNNode

    static func lineBetweenNodes(positionA: SCNVector3, positionB: SCNVector3, mainNode: SCNNode) -> SCNNode {
        let vector = SCNVector3(positionA.x - positionB.x, positionA.y - positionB.y, positionA.z - positionB.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition = SCNVector3 (x:(positionA.x + positionB.x) / 2, y:(positionA.y + positionB.y) / 2, z:(positionA.z + positionB.z) / 2)

        let lineGeometry = SCNCylinder()
        lineGeometry.radius = 0.025
        lineGeometry.height = CGFloat(distance)
        lineGeometry.radialSegmentCount = 5
        lineGeometry.firstMaterial?.lightingModel = .constant
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.gray

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look (at: positionB, up: mainNode.worldUp, localFront: lineNode.worldUp)
        return lineNode
    }

    // Improve this.... We're rebuilding this all the time....
    static func buildCylinders(skeleton: ARSkeleton3D, mainNode: SCNNode) -> SCNNode {
        let jointModelTransforms = skeleton.jointModelTransforms

        let cylinderParent = SCNNode()

        for (i, jointModelTransform) in jointModelTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let modelPosition = SCNVector3(simd_make_float3(jointModelTransform.columns.3))

            guard parentIndex != -1 else { continue }

            let parentModelTransform = jointModelTransforms[parentIndex]
            let parentModelPosition = SCNVector3(simd_make_float3(parentModelTransform.columns.3))

            let lineNode = lineBetweenNodes(
                positionA: modelPosition,
                positionB: parentModelPosition,
                mainNode: mainNode
            )

            cylinderParent.addChildNode(lineNode)
        }

        return cylinderParent
    }

    init(bodyAnchor: ARBodyAnchor) {
        let mainNode = SCNNode()
        mainNode.transform = SCNMatrix4(bodyAnchor.transform)
        mainNode.geometry = SCNSphere(radius: 0.1)
        mainNode.geometry?.firstMaterial?.lightingModel = .constant
        mainNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        self.mainNode = mainNode

        let skeleton = bodyAnchor.skeleton
        let jointLocalTransforms = skeleton.jointLocalTransforms

        var nodes: [String: SCNNode] = [:]

        // Assuming that this is sorted topologically
        for (i, jointLocalTransform) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            // Root
            if parentIndex == -1 {
                nodes[jointName] = mainNode
            } else {
                let currentNode = SCNNode()
                currentNode.transform = SCNMatrix4(jointLocalTransform)
                currentNode.geometry = SCNSphere(radius: 0.05)
                currentNode.geometry?.firstMaterial?.lightingModel = .constant
                currentNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green

                // This can be `nil` if this is not sorted topologically
                let parentNode = nodes[skeleton.definition.jointNames[parentIndex]]
                parentNode?.addChildNode(currentNode)

                nodes[jointName] = currentNode
            }
        }

        self.cylindersNode = Skeleton.buildCylinders(skeleton: skeleton, mainNode: mainNode)
        mainNode.addChildNode(cylindersNode)

        self.mainNode = mainNode
        self.joints = nodes
    }

    func update(bodyAnchor: ARBodyAnchor) {
        mainNode.transform = SCNMatrix4(bodyAnchor.transform)

        let skeleton = bodyAnchor.skeleton
        let jointLocalTransforms = skeleton.jointLocalTransforms

        for (i, jointLocalTransform) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            if parentIndex != -1 {
                joints[jointName]?.transform = SCNMatrix4(jointLocalTransform)
            }
        }

        // Improve this.... We're rebuilding this all the time...
        cylindersNode.removeFromParentNode()
        cylindersNode = Skeleton.buildCylinders(skeleton: skeleton, mainNode: mainNode)
        mainNode.addChildNode(cylindersNode)
    }
}
