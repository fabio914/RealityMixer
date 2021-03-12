import Foundation

struct MixedRealityConfiguration {

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

    // Use magenta as the transparency color for the foreground plane
    let shouldUseMagentaAsTransparency: Bool

    let enableAudio: Bool
    let enableAutoFocus: Bool
    let shouldFlipOutput: Bool
    let backgroundVisibility: BackgroundVisibility
}
