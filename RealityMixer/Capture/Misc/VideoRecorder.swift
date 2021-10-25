import UIKit
import AVFoundation
import VideoToolbox

// Small workaround to keep the recorder in memory until we've finished
private var recorders: [String: VideoRecorder] = [:]

final class VideoRecorder {

    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private var compressionSession: VTCompressionSession
    private let fileName: String

    private var finalized = false

    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init?(size: CGSize) {
        do {
            let fileName = "\(UUID().uuidString).mp4"
            self.fileName = fileName
            let outputUrl = Self.documentsDirectory().appendingPathComponent(fileName)
            assetWriter = try AVAssetWriter(outputURL: outputUrl, fileType: .mp4)

            let format = try CMFormatDescription(videoCodecType: .mpeg4Video, width: Int(size.width), height: Int(size.height), extensions: nil)
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
            videoWriterInput.expectsMediaDataInRealTime = true
            self.videoInput = videoWriterInput

            assetWriter.add(videoWriterInput)

            var session: VTCompressionSession?

            VTCompressionSessionCreate(
                allocator: nil,
                width: Int32(size.width),
                height: Int32(size.height),
                codecType: kCMVideoCodecType_H264,
                encoderSpecification: nil,
                imageBufferAttributes: nil,
                compressedDataAllocator: nil,
                outputCallback: nil,
                refcon: nil,
                compressionSessionOut: &session
            )

            guard let session = session else {
                return nil
            }

            self.compressionSession = session
            
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: .zero)
        } catch {
            return nil
        }
    }

    // TODO: Add audio

    func encodeFrame(_ frame: CVImageBuffer, presentationTime: Double, duration: Double) {
        guard !finalized else { return }

        let presentationCMTime = CMTime(value: Int64(presentationTime * 1000), timescale: 1000)
        let durationCMTime = CMTime(value: Int64(duration * 1000), timescale: 1000)

        VTCompressionSessionEncodeFrame(
            compressionSession,
            imageBuffer: frame,
            presentationTimeStamp: presentationCMTime,
            duration: durationCMTime,
            frameProperties: nil,
            infoFlagsOut: nil,
            outputHandler: { [weak self] status, infoFlags, sampleBuffer in
                if let sampleBuffer = sampleBuffer {
                    self?.videoInput.append(sampleBuffer)
                }
            }
        )
    }

    func finalize() {
        guard !finalized else { return }
        finalized = true
        recorders[fileName] = self

        // Consider finishing remaining frames
        VTCompressionSessionInvalidate(compressionSession)
        videoInput.markAsFinished()
        assetWriter.finishWriting(completionHandler: { [fileName] in
            // Consider showing feedback to the user...
            recorders[fileName] = nil
        })
    }
}
