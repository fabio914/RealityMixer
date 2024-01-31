//
//  ARKitHelpers.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 24/05/2021.
//

import ARKit
import RealityMixerKit

struct ARKitHelpers {

    // FIXME: Check this.
    static func planeSizeForDistance(_ distance: Float, frame: ARFrame) -> CGSize {
        let projection = frame.camera.projectionMatrix
        let yScale = projection[1,1]
        let imageResolution = frame.camera.imageResolution
        let width = (2.0 * distance) * tan(atan(1/yScale) * Float(imageResolution.width / imageResolution.height))
        let height = width * Float(imageResolution.height / imageResolution.width)
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    static func makePlaneNodeForDistance(_ distance: Float, frame: ARFrame) -> SCNNode {
        SceneKitHelpers.makePlane(size: planeSizeForDistance(distance, frame: frame), distance: distance)
    }
}
