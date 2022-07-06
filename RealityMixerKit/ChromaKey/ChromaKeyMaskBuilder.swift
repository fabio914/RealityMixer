//
//  ChromaKeyMaskBuilder.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 27/06/2021.
//

#if os(iOS)
import ARKit
#elseif os(macOS)
import AppKit
#endif

import SceneKit
import CoreImage.CIFilterBuiltins

// Consider replacing this with Metal (MTLComputeCommandEncoder)
// to reduce the SceneKit overhead.

public final class ChromaKeyMaskBuilder {

    static func buildMask(
        for capturedImage: CVPixelBuffer,
        size imageSize: CGSize,
        chromaConfiguration: ChromaKeyConfiguration
    ) -> CIImage? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let renderer = SCNRenderer(device: device, options: nil)

        var cache: CVMetalTextureCache?
        SceneKitHelpers.create(textureCache: &cache, forDevice: device)

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

        let planeNode = SceneKitHelpers.makePlane(size: planeSize, distance: 1)

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

        let luma = SceneKitHelpers.texture(from: capturedImage, format: .r8Unorm, planeIndex: 0, textureCache: textureCache)
        let chroma = SceneKitHelpers.texture(from: capturedImage, format: .rg8Unorm, planeIndex: 1, textureCache: textureCache)

        planeNode.geometry?.firstMaterial?.transparent.contents = luma
        planeNode.geometry?.firstMaterial?.diffuse.contents = chroma
        cameraNode.addChildNode(planeNode)

        renderer.scene = scene
        let initialMask = renderer.snapshot(atTime: 0, with: imageSize, antialiasingMode: SCNAntialiasingMode.none)

#if os(macOS)
        let ciImage = initialMask.ciImage()
#elseif os(iOS)
        let ciImage = CIImage(image: initialMask)
#endif

        // Eroding the white area
        let filter = CIFilter.morphologyMinimum()
        filter.inputImage = ciImage
        filter.radius = 10
        return filter.outputImage
    }

#if os(macOS)
    public static func buildMask(
        for capturedImage: CVPixelBuffer,
        size imageSize: CGSize,
        chromaConfiguration: ChromaKeyConfiguration
    ) -> NSImage? {
        let ciImage: CIImage? = buildMask(for: capturedImage, size: imageSize, chromaConfiguration: chromaConfiguration)
        return ciImage.flatMap(nsImage(from:))
    }

    static func nsImage(from inputImage: CIImage) -> NSImage {
        let rep = NSCIImageRep(ciImage: inputImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

#elseif os(iOS)
    public static func buildMask(for frame: ARFrame, chromaConfiguration: ChromaKeyConfiguration) -> UIImage? {
        let capturedImage = frame.capturedImage
        let imageSize = frame.camera.imageResolution

        let ciImage = buildMask(for: capturedImage, size: imageSize, chromaConfiguration: chromaConfiguration)
        return ciImage.flatMap(uiImage(from:))
    }

    static func uiImage(from inputImage: CIImage) -> UIImage? {
        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(inputImage, from: inputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
#endif
}


#if os(macOS)

private extension NSImage {

    func ciImage() -> CIImage? {
        guard let data = self.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: data)
        else {
            return nil
        }

        let ci = CIImage(bitmapImageRep: bitmap)
        return ci
    }
}

#endif
