//
//  Shaders.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/20/20.
//

import Foundation

struct Shaders {

    static let yCrCbToRGB = """
    float BT709_nonLinearNormToLinear(float normV) {
        if (normV < 0.081) {
            normV *= (1.0 / 4.5);
        } else {
            float a = 0.099;
            float gamma = 1.0 / 0.45;
            normV = (normV + a) * (1.0 / (1.0 + a));
            normV = pow(normV, gamma);
        }
        return normV;
    }

    vec4 yCbCrToRGB(float luma, vec2 chroma) {
        float y = luma;
        float u = chroma.r - 0.5;
        float v = chroma.g - 0.5;

        const float yScale = 255.0 / (235.0 - 16.0); //(BT709_YMax-BT709_YMin)
        const float uvScale = 255.0 / (240.0 - 16.0); //(BT709_UVMax-BT709_UVMin)

        y = y - 16.0/255.0;
        float r = y*yScale + v*uvScale*1.5748;
        float g = y*yScale - u*uvScale*1.8556*0.101 - v*uvScale*1.5748*0.2973;
        float b = y*yScale + u*uvScale*1.8556;

        r = clamp(r, 0.0, 1.0);
        g = clamp(g, 0.0, 1.0);
        b = clamp(b, 0.0, 1.0);

        r = BT709_nonLinearNormToLinear(r);
        g = BT709_nonLinearNormToLinear(g);
        b = BT709_nonLinearNormToLinear(b);
        return vec4(r, g, b, 1.0);
    }

    """

    static let rgbToYCrCb = """
    vec3 rgbToYCrCb(vec3 c) {
        float y = 0.2989 * c.r + 0.5866 * c.g + 0.1145 * c.b;
        float cr = 0.7132 * (c.r - y);
        float cb = 0.5647 * (c.b - y);
        return vec3(y, cr, cb);
    }

    """

    static let smoothChromaKey = """
    \(rgbToYCrCb)

    float smoothChromaKey(vec3 c, vec3 maskColor, float sensitivity, float smoothness) {
        vec3 convertedMask = rgbToYCrCb(maskColor);
        float maskCr = convertedMask.g;
        float maskCb = convertedMask.b;

        vec3 convertedColor = rgbToYCrCb(c);
        float Cr = convertedColor.g;
        float Cb = convertedColor.b;

        return 1.0 - smoothstep(sensitivity, sensitivity + smoothness, distance(vec2(Cr, Cb), vec2(maskCr, maskCb)));
    }

    """

    static let backgroundSurface = """
    \(yCrCbToRGB)

    #pragma body

    vec2 backgroundCoords = vec2((_surface.diffuseTexcoord.x * 0.5), _surface.diffuseTexcoord.y);

    float luma = texture2D(u_transparentTexture, backgroundCoords).r;
    vec2 chroma = texture2D(u_diffuseTexture, backgroundCoords).rg;

    _surface.diffuse = yCbCrToRGB(luma, chroma);
    _surface.transparent = vec4(0.0, 0.0, 0.0, 1.0);
    """

    // Consider setting the smoothness
    static func backgroundSurfaceChromaKey(red: Float, green: Float, blue: Float) -> String {
        """
        \(yCrCbToRGB)
        \(smoothChromaKey)

        #pragma body

        vec2 backgroundCoords = vec2((_surface.diffuseTexcoord.x * 0.5), _surface.diffuseTexcoord.y);

        float luma = texture2D(u_transparentTexture, backgroundCoords).r;
        vec2 chroma = texture2D(u_diffuseTexture, backgroundCoords).rg;

        vec4 textureColor = yCbCrToRGB(luma, chroma);
        _surface.diffuse = textureColor;

        float blendValue = smoothChromaKey(textureColor.rgb, vec3(\(red), \(green), \(blue)), 0.18, 0.0);
        _surface.transparent = vec4(blendValue, blendValue, blendValue, 1.0);
        """
    }

    // FIXME: avoid converting from yCbCr to RGB and then back to yCbCr...
    static func surfaceChromaKey() -> String {
        """
        \(yCrCbToRGB)
        \(smoothChromaKey)

        #pragma arguments
        uniform vec3 maskColor;
        uniform float sensitivity;
        uniform float smoothness;

        #pragma body

        float luma = texture2D(u_transparentTexture, _surface.diffuseTexcoord).r;
        vec2 chroma = texture2D(u_diffuseTexture, _surface.diffuseTexcoord).rg;

        vec4 textureColor = yCbCrToRGB(luma, chroma);

        float blendValue = smoothChromaKey(textureColor.rgb, maskColor, sensitivity, smoothness);

        float maskTextureValue = texture2D(u_ambientTexture, _surface.diffuseTexcoord).r;
        _surface.ambient = vec4(1.0, 1.0, 1.0, 1.0);
        _surface.transparent = vec4(0.0, 0.0, 0.0, 1.0);

        if (maskTextureValue > 0.5) {
            if (blendValue > 0.5) {
                _surface.diffuse = vec4(1.0, 1.0, 0.0, 1.0);
            } else {
                if (luma > 0.82) {
                    _surface.diffuse = vec4(1.0, 1.0, 1.0, 1.0);
                } else {
                    _surface.diffuse = vec4(0.0, 0.0, 0.0, 1.0);
                }
            }
        } else {
            _surface.transparent = vec4(0.0, 0.0, 0.0, 1.0);
            _surface.diffuse = vec4(1.0, 1.0, 0.0, 1.0);
        }
        """
    }

    static func surfaceChromaKeyConfiguration() -> String {
        """
        \(yCrCbToRGB)
        \(smoothChromaKey)

        #pragma arguments
        uniform vec3 maskColor;
        uniform float sensitivity;
        uniform float smoothness;

        #pragma body

        float luma = texture2D(u_transparentTexture, _surface.diffuseTexcoord).r;
        vec2 chroma = texture2D(u_diffuseTexture, _surface.diffuseTexcoord).rg;

        vec4 textureColor = yCbCrToRGB(luma, chroma);
        _surface.diffuse = textureColor;

        float blendValue = smoothChromaKey(textureColor.rgb, maskColor, sensitivity, smoothness);

        float maskTextureValue = texture2D(u_ambientTexture, _surface.diffuseTexcoord).r;
        _surface.ambient = vec4(1.0, 1.0, 1.0, 1.0);

        if (maskTextureValue > 0.5) {
            _surface.transparent = vec4(blendValue, blendValue, blendValue, 1.0);
        } else {
            _surface.diffuse = vec4(0.0, 0.0, 0.0, 1.0);
            _surface.transparent = vec4(0.75, 0.75, 0.75, 1.0);
        }
        """
    }

    static func maskChromaKey() -> String {
        """
        \(yCrCbToRGB)
        \(smoothChromaKey)

        #pragma arguments
        uniform vec3 maskColor;
        uniform float sensitivity;

        #pragma body

        float luma = texture2D(u_transparentTexture, _surface.diffuseTexcoord).r;
        vec2 chroma = texture2D(u_diffuseTexture, _surface.diffuseTexcoord).rg;
        vec4 textureColor = yCbCrToRGB(luma, chroma);

        float blendValue = smoothChromaKey(textureColor.rgb, maskColor, sensitivity, 0.0);
        _surface.diffuse = vec4(blendValue, blendValue, blendValue, 1.0);
        _surface.transparent = vec4(0.0, 0.0, 0.0, 1.0);
        """
    }

    static let backgroundSurfaceWithBlackChromaKey = """
    \(yCrCbToRGB)

    #pragma body

    vec2 backgroundCoords = vec2((_surface.diffuseTexcoord.x * 0.5), _surface.diffuseTexcoord.y);

    float luma = texture2D(u_transparentTexture, backgroundCoords).r;
    vec2 chroma = texture2D(u_diffuseTexture, backgroundCoords).rg;

    _surface.diffuse = yCbCrToRGB(luma, chroma);

    if (luma < 0.13) {
        _surface.transparent = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        _surface.transparent = vec4(0.0, 0.0, 0.0, 1.0);
    }

    """

    static let backgroundSurfaceWithGreenChromaKey = backgroundSurfaceChromaKey(red: 0, green: 1, blue: 0)
    static let backgroundSurfaceWithMagentaChromaKey = backgroundSurfaceChromaKey(red: 1, green: 0, blue: 1)

    static let foregroundSurfaceShared = """
    \(yCrCbToRGB)

    #pragma body

    vec2 foregroundCoords = vec2((_surface.diffuseTexcoord.x * 0.25) + 0.5, _surface.diffuseTexcoord.y);

    float luma = texture2D(u_transparentTexture, foregroundCoords).r;
    vec2 chroma = texture2D(u_diffuseTexture, foregroundCoords).rg;

    _surface.diffuse = yCbCrToRGB(luma, chroma);
    """

    static let foregroundSurface = """
    \(foregroundSurfaceShared)

    vec2 alphaCoords = vec2((_surface.transparentTexcoord.x * 0.25) + 0.75, _surface.transparentTexcoord.y);

    float luma2 = texture2D(u_transparentTexture, alphaCoords).r;
    vec2 chroma2 = texture2D(u_diffuseTexture, alphaCoords).rg;

    float alpha = yCbCrToRGB(luma2, chroma2).r;

    // Threshold to prevent glitches because of the video compression.
    float threshold = 0.25;
    float correctedAlpha = step(threshold, alpha) * alpha;

    float value = (1.0 - correctedAlpha);
    _surface.transparent = vec4(value, value, value, 1.0);
    """

    // Consider setting the smoothness
    static let magentaForegroundSurface = """
    \(smoothChromaKey)
    \(foregroundSurfaceShared)

    vec2 alphaCoords = vec2((_surface.transparentTexcoord.x * 0.25) + 0.5, _surface.transparentTexcoord.y);

    float luma2 = texture2D(u_transparentTexture, alphaCoords).r;
    vec2 chroma2 = texture2D(u_diffuseTexture, alphaCoords).rg;

    vec4 alphaColor = yCbCrToRGB(luma2, chroma2);

    float blendValue = smoothChromaKey(alphaColor.rgb, vec3(1.0, 0.0, 1.0), 0.18, 0.0);
    _surface.transparent = vec4(blendValue, blendValue, blendValue, 1.0);
    """
}
