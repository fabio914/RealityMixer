//
//  VideoDecoder.swift
//  RealityMixer
//
//  Created by Fabio Dela Antonio on 04/07/2022.
//

import Foundation
import VideoToolbox

// Based on the code from https://github.com/zerdzhong/SwfitH264Demo/blob/master/SwiftH264/ViewController.swift

protocol DecoderDelegate: AnyObject {
    func didDecodeFrame(_ buffer: CVPixelBuffer)
}

final class VideoDecoder {
    weak var delegate: DecoderDelegate?

    private var formatDesc: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?

    private var sps: [UInt8]?
    private var pps: [UInt8]?

    init(delegate: DecoderDelegate? = nil) {
        self.delegate = delegate
    }

    func process(_ data: Data) {
        let dataArray = [UInt8](data)
        guard dataArray.count > 4 else { return }

        // Assuming that the entire package is here

        var slices: [[UInt8]] = []
        var currentSlice: [UInt8] = []

        var index = 0

        repeat {
            if (index + 4) < dataArray.count,
                dataArray[index] == 0,
                dataArray[index + 1] == 0,
                dataArray[index + 2] == 0,
                dataArray[index + 3] == 1 {

                if currentSlice.count > 4 {
                    slices.append(currentSlice)
                }

                currentSlice = [0, 0, 0, 1]
                index += 4
            } else {
                currentSlice.append(dataArray[index])
                index += 1
            }
        } while index < dataArray.count

        if currentSlice.count > 4 {
            slices.append(currentSlice)
        }

        for slice in slices {
            receivedRawVideoFrame(slice)
        }
    }

    private func receivedRawVideoFrame(_ videoPacket: [UInt8]) {
        var copy = videoPacket

        // Replace start code with nal size
        var biglen = CFSwapInt32HostToBig(UInt32(videoPacket.count - 4))
        memcpy(&copy, &biglen, 4)

        let nalType = videoPacket[4] & 0x1F

        switch nalType {
        case 0x05:
            // IDR frame
            if createDecompSession() {
                decodeVideoPacket(copy)
            }
        case 0x07:
            // SPS
            sps = Array(videoPacket[4 ..< videoPacket.count])
        case 0x08:
            // PPS
            pps = Array(videoPacket[4 ..< videoPacket.count])
        default:
            // B/P frame
            decodeVideoPacket(copy)
            break;
        }
    }

    private func decodeVideoPacket(_ videoPacket: [UInt8]) {
        var copy = videoPacket
        var blockBuffer: CMBlockBuffer?

        var status = copy.withUnsafeMutableBytes {
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: $0.baseAddress,
                blockLength: videoPacket.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: videoPacket.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }

        if status != kCMBlockBufferNoErr {
            return
        }

        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = [videoPacket.count]

        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: sampleSizeArray,
            sampleBufferOut: &sampleBuffer
        )

        if let buffer = sampleBuffer, let session = decompressionSession, status == kCMBlockBufferNoErr {

            let attachments: CFArray? = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true)

            if let attachmentArray = attachments {
                let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachmentArray, 0), to: CFMutableDictionary.self)

                CFDictionarySetValue(
                    dic,
                    Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                    Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
                )
            }

            var flagOut = VTDecodeInfoFlags(rawValue: 0)

            status = VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: buffer,
                flags: [._EnableAsynchronousDecompression],
                infoFlagsOut: &flagOut,
                outputHandler: { [weak delegate] status, flags, imageBuffer, _, _ in
                    guard let imageBuffer = imageBuffer else { return }
                    DispatchQueue.main.async {
                        delegate?.didDecodeFrame(imageBuffer)
                    }
                }
            )

            if status == noErr {
                // print("OK")
            } else if status == kVTInvalidSessionErr {
                print("VideoDecoder: Invalid session, reset decoder session");
            } else if status == kVTVideoDecoderBadDataErr {
                print("VideoDecoder: decode failed status=\(status)(Bad data)");
            } else if status != noErr {
                print("VideoDecoder: decode failed status=\(status)");
            }
        }
    }

    private func createDecompSession() -> Bool{
        formatDesc = nil

        if let spsData = sps, let ppsData = pps {

            let status = spsData.withUnsafeBufferPointer { SPS -> OSStatus in
                ppsData.withUnsafeBufferPointer { PPS -> OSStatus in
                    let parameterSetPointers = [SPS.baseAddress, PPS.baseAddress].compactMap({ $0 })
                    let parameterSetSizes = [SPS.count, PPS.count]

                    return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: 2,
                        parameterSetPointers: parameterSetPointers,
                        parameterSetSizes: parameterSetSizes,
                        nalUnitHeaderLength: 4,
                        formatDescriptionOut: &formatDesc
                    )
                }
            }

            if let desc = formatDesc, status == noErr {

                if let session = decompressionSession {
                    VTDecompressionSessionInvalidate(session)
                    decompressionSession = nil
                }

                var videoSessionM : VTDecompressionSession?

                let decoderParameters = NSMutableDictionary()
                let destinationPixelBufferAttributes = NSMutableDictionary()
                destinationPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)

                let status = VTDecompressionSessionCreate(
                    allocator: kCFAllocatorDefault,
                    formatDescription: desc,
                    decoderSpecification: decoderParameters,
                    imageBufferAttributes: destinationPixelBufferAttributes,
                    outputCallback: nil,
                    decompressionSessionOut: &videoSessionM
                )

                if status != noErr {
                    print("\t\t VTD ERROR type: \(status)")
                }

                self.decompressionSession = videoSessionM
            } else {
                print("VideoDecoder: reset decoder session failed status=\(status)")
            }
        }

        return true
    }

    func displayDecodedFrame(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }

        delegate?.didDecodeFrame(imageBuffer)
    }
}
