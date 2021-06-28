//
//  ChromaKeyMaskBuilder.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 27/06/2021.
//

import UIKit
import ARKit
import SceneKit
import CoreImage.CIFilterBuiltins

// Consider replacing this with Metal (MTLComputeCommandEncoder)
// to reduce the SceneKit overhead.

final class ChromaKeyMaskBuilder {

    static func buildMask(for frame: ARFrame, chromaConfiguration: ChromaKeyConfiguration) -> UIImage? {

        let capturedImage = frame.capturedImage
        let imageSize = frame.camera.imageResolution

        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let renderer = SCNRenderer(device: device, options: nil)

        var cache: CVMetalTextureCache?
        ARKitHelpers.create(textureCache: &cache, forDevice: device)

        guard let textureCache = cache else { return nil }

        let scene = SCNScene()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = .init(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        let planeSize: CGSize = {
            if imageSize.width > imageSize.height {
                return CGSize(width: 2 * (imageSize.width/imageSize.height), height: 2)
            } else {
                return CGSize(width: 2, height: 2 * (imageSize.height/imageSize.width))
            }
        }()

        let planeNode = ARKitHelpers.makePlane(size: planeSize, distance: 1)

        planeNode.geometry?.firstMaterial?.transparencyMode = .rgbZero

        planeNode.geometry?.firstMaterial?.shaderModifiers = [
            .surface: Shaders.maskChromaKey()
        ]

        let color = chromaConfiguration.color

        planeNode.geometry?.firstMaterial?.setValue(
            SCNVector3(color.red, color.green, color.blue),
            forKey: "maskColor"
        )

        planeNode.geometry?.firstMaterial?.setValue(
            chromaConfiguration.sensitivity,
            forKey: "sensitivity"
        )

        let luma = ARKitHelpers.texture(from: capturedImage, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = ARKitHelpers.texture(from: capturedImage, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        planeNode.geometry?.firstMaterial?.transparent.contents = luma
        planeNode.geometry?.firstMaterial?.diffuse.contents = chroma
        cameraNode.addChildNode(planeNode)

        renderer.scene = scene
        let initialMask = renderer.snapshot(atTime: 0, with: imageSize, antialiasingMode: SCNAntialiasingMode.none)

        // Eroding the white area
        let ciImage = CIImage(image: initialMask)
        let filter = CIFilter.morphologyMinimum()
        filter.inputImage = ciImage
        filter.radius = 5 // TODO: Increase erosion
        return filter.outputImage.flatMap(uiImage(from:))
    }

    static func uiImage(from inputImage: CIImage) -> UIImage? {
        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(inputImage, from: inputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
