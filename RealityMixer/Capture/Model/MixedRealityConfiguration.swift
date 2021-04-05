import Foundation

struct MixedRealityConfiguration {

    struct ForegroundLayerOptions {
        enum ForegroundVisibility {
            case visible(_ useMagentaAsTransparency: Bool)
            case hidden
        }

        let visibility: ForegroundVisibility
    }

    struct BackgroundLayerOptions {
        enum BackgroundVisibility {
            enum ChromaKey {
                case black
                case green
                case magenta
            }

            case visible
            case chromaKey(ChromaKey)
            case hidden
        }

        let visibility: BackgroundVisibility
    }

    let enableAudio: Bool
    let enableAutoFocus: Bool
    let enablePersonSegmentation: Bool
    let shouldFlipOutput: Bool

    let foregroundLayerOptions: ForegroundLayerOptions
    let backgroundLayerOptions: BackgroundLayerOptions
}
