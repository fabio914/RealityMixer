//
//  SceneKitHelpers.swift
//  RealityMixerKit
//
//  Created by Fabio Dela Antonio on 06/07/2022.
//

import SceneKit

public struct SceneKitHelpers {

    public static func makePlane(size: CGSize, distance: Float) -> SCNNode {
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.cornerRadius = 0
        plane.firstMaterial?.lightingModel = .constant

#if os(macOS)
        plane.firstMaterial?.diffuse.contents = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
#elseif os(iOS)
        plane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
#endif

        let planeNode = SCNNode(geometry: plane)
        planeNode.position = .init(0, 0, -distance)
        return planeNode
    }

    @discardableResult
    public static func create(textureCache: inout CVMetalTextureCache?, for sceneView: SCNView) -> Bool {
        guard let metalDevice = sceneView.device else {
            return false
        }

        return create(textureCache: &textureCache, forDevice: metalDevice)
    }

    @discardableResult
    public static func create(textureCache: inout CVMetalTextureCache?, forDevice metalDevice: MTLDevice) -> Bool {
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            metalDevice,
            nil,
            &textureCache
        )

        return result == kCVReturnSuccess
    }

    public static func texture(
        from pixelBuffer: CVPixelBuffer,
        format: MTLPixelFormat,
        planeIndex: Int,
        textureCache: CVMetalTextureCache?
    ) -> MTLTexture? {
        guard let textureCache = textureCache,
            planeIndex >= 0, planeIndex < CVPixelBufferGetPlaneCount(pixelBuffer) //,
//          CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        else {
            return nil
        }

        var texture: MTLTexture?

        let width =  CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var textureRef : CVMetalTexture?

        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            format,
            width,
            height,
            planeIndex,
            &textureRef
        )

        if result == kCVReturnSuccess, let textureRef = textureRef {
            texture = CVMetalTextureGetTexture(textureRef)
        }

        return texture
    }
}
