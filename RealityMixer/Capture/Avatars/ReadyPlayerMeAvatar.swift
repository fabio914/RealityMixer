//
//  ReadyPlayerMeAvatar.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 26/04/2021.
//

import ARKit

final class ReadyPlayerMeAvatar: AvatarProtocol {

    static let nodes: [String: String] = [
//        "root": "Skeleton",
        "hips_joint": "Hips", // 2 nodes with this name...
        "left_upLeg_joint": "LeftUpLeg",
        "left_leg_joint": "LeftLeg",
        "left_foot_joint": "LeftFoot",
        "left_toes_joint": "LeftToeBase",
        "left_toesEnd_joint": "LeftToe_End",
        "right_upLeg_joint": "RightUpLeg",
        "right_leg_joint": "RightLeg",
        "right_foot_joint": "RightFoot",
        "right_toes_joint": "RightToeBase",
        "right_toesEnd_joint": "RightToe_End",
        "spine_1_joint": "Spine",
//        "spine_2_joint": "",
//        "spine_3_joint": "",
//        "spine_4_joint": "",
//        "spine_5_joint": "",
        "spine_6_joint": "Spine1",
        "spine_7_joint": "Spine2",
        "right_shoulder_1_joint": "RightShoulder",
        "right_arm_joint": "RightArm",
        "right_forearm_joint": "RightForeArm",
        "right_hand_joint": "RightHand",
        "right_handThumbStart_joint": "RightHandThumb1",
        "right_handThumb_1_joint": "RightHandThumb2",
        "right_handThumb_2_joint": "RightHandThumb3",
        "right_handThumbEnd_joint": "RightHandThumb4",
//        "right_handIndexStart_joint": "",
        "right_handIndex_1_joint": "RightHandIndex1",
        "right_handIndex_2_joint": "RightHandIndex2",
        "right_handIndex_3_joint": "RightHandIndex3",
        "right_handIndexEnd_joint": "RightHandIndex4",
//        "right_handMidStart_joint": "",
        "right_handMid_1_joint": "RightHandMiddle1",
        "right_handMid_2_joint": "RightHandMiddle2",
        "right_handMid_3_joint": "RightHandMiddle3",
        "right_handMidEnd_joint": "RightHandMiddle4",
//        "right_handRingStart_joint": "",
        "right_handRing_1_joint": "RightHandRing1",
        "right_handRing_2_joint": "RightHandRing2",
        "right_handRing_3_joint": "RightHandRing3",
        "right_handRingEnd_joint": "RightHandRing4",
//        "right_handPinkyStart_joint": "",
        "right_handPinky_1_joint": "RightHandPinky1",
        "right_handPinky_2_joint": "RightHandPinky2",
        "right_handPinky_3_joint": "RightHandPinky3",
        "right_handPinkyEnd_joint": "RightHandPinky4",
        "left_shoulder_1_joint": "LeftShoulder",
        "left_arm_joint": "LeftArm",
        "left_forearm_joint": "LeftForeArm",
        "left_hand_joint": "LeftHand",
        "left_handThumbStart_joint": "LeftHandThumb1",
        "left_handThumb_1_joint": "LeftHandThumb2",
        "left_handThumb_2_joint": "LeftHandThumb3",
        "left_handThumbEnd_joint": "LeftHandThumb4",
//        "left_handIndexStart_joint": "",
        "left_handIndex_1_joint": "LeftHandIndex1",
        "left_handIndex_2_joint": "LeftHandIndex2",
        "left_handIndex_3_joint": "LeftHandIndex3",
        "left_handIndexEnd_joint": "LeftHandIndex4",
//        "left_handMidStart_joint": "",
        "left_handMid_1_joint": "LeftHandMiddle1",
        "left_handMid_2_joint": "LeftHandMiddle2",
        "left_handMid_3_joint": "LeftHandMiddle3",
        "left_handMidEnd_joint": "LeftHandMiddle4",
//        "left_handRingStart_joint": "",
        "left_handRing_1_joint": "LeftHandRing1",
        "left_handRing_2_joint": "LeftHandRing2",
        "left_handRing_3_joint": "LeftHandRing3",
        "left_handRingEnd_joint": "LeftHandRing4",
//        "left_handPinkyStart_joint": "",
        "left_handPinky_1_joint": "LeftHandPinky1",
        "left_handPinky_2_joint": "LeftHandPinky2",
        "left_handPinky_3_joint": "LeftHandPinky3",
        "left_handPinkyEnd_joint": "LeftHandPinky4",
        "head_joint": "Head",
//        "jaw_joint": "",
//        "chin_joint": "",
//        "nose_joint": "",
        "right_eye_joint": "RightEye",
//        "right_eyeUpperLid_joint": "",
//        "right_eyeLowerLid_joint": "",
//        "right_eyeball_joint": "",
        "left_eye_joint": "LeftEye",
//        "left_eyeUpperLid_joint": "",
//        "left_eyeLowerLid_joint": "",
//        "left_eyeball_joint": "",
//        "neck_1_joint": "",
//        "neck_2_joint": "",
        "neck_3_joint": "Neck",
//        "neck_4_joint": ""
    ]

    static func node(forJoint jointName: String) -> String? {
        nodes[jointName]
    }

    private(set) var mainNode: SCNNode
    private var hipsNode: SCNNode
    private let corrections: [String: Quaternion]

    init?(bodyAnchor: ARBodyAnchor) {

        let skeleton = bodyAnchor.skeleton

        let maybeAvatarReferenceNode = Bundle.main
            .url(forResource: "tpose", withExtension: "usdz")
            .flatMap(SCNReferenceNode.init(url:))

        guard let avatarNode = maybeAvatarReferenceNode,
            let neutralBodySkeleton = skeleton.definition.neutralBodySkeleton3D
        else {
            return nil
        }

        avatarNode.load()

        guard let skeletonNode = avatarNode.childNode(withName: "Skeleton", recursively: true),
            let hipsNode = skeletonNode.childNode(withName: "Hips", recursively: false)
        else {
            return nil
        }

        hipsNode.transform = SCNMatrix4(bodyAnchor.transform)

        let jointLocalTransforms = skeleton.jointLocalTransforms

        var corrections: [String: Quaternion] = [:]

        for (i, _) in jointLocalTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            guard parentIndex != -1,
                jointName != "root",
                jointName != "hips_joint",
//                let nodeName = Avatar.node(forJoint: jointName),
//                let node = hipsNode.childNode(withName: nodeName, recursively: true),
                let referenceTransform = neutralBodySkeleton.localTransform(for: .init(rawValue: jointName))
            else {
                continue
            }

            // Assuming that this is sorted topologically
            let parentName = skeleton.definition.jointNames[parentIndex]
            let parentCorrection = corrections[parentName] ?? Quaternion(x: 0, y: 0, z: 0, w: 1)

            corrections[jointName] = parentCorrection * Quaternion(rotationMatrix: .init(referenceTransform)) /* * Quaternion(rotationMatrix: node.transform) */
        }

        self.corrections = corrections
        self.hipsNode = hipsNode
        mainNode = avatarNode
    }

    func update(bodyAnchor: ARBodyAnchor) {
        hipsNode.transform = SCNMatrix4(bodyAnchor.transform)

        let skeleton = bodyAnchor.skeleton
        let jointModelTransforms = skeleton.jointModelTransforms

        var parentOrientations = [String: Quaternion]()

        for (i, jointModelTransform) in jointModelTransforms.enumerated() {
            let parentIndex = skeleton.definition.parentIndices[i]
            let jointName = skeleton.definition.jointNames[i]

            guard parentIndex != -1,
                jointName != "root",
                jointName != "hips_joint",
                let correction = corrections[jointName]
            else {
                continue
            }

            let parentName = skeleton.definition.jointNames[parentIndex]
            let parentOrientation = parentOrientations[parentName] ?? Quaternion(x: 0, y: 0, z: 0, w: 1)
            parentOrientations[jointName] = Quaternion(rotationMatrix: SCNMatrix4(jointModelTransform)) * correction.inverse

            guard let nodeName = ReadyPlayerMeAvatar.node(forJoint: jointName),
                let node = hipsNode.childNode(withName: nodeName, recursively: true)
            else {
                continue
            }

            let correctedOrientation = parentOrientation.inverse * Quaternion(rotationMatrix: SCNMatrix4(jointModelTransform)) * correction.inverse
            node.orientation = SCNQuaternion(correctedOrientation.x, correctedOrientation.y, correctedOrientation.z, correctedOrientation.w)

            // FIXME: Set positions
//            node.position = SCNVector3(simd_make_float3(jointLocalTransform.columns.3))
        }
    }
}
