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

    private var spsSize: Int = 0
    private var ppsSize: Int = 0

    private var sps: Array<UInt8>?
    private var pps: Array<UInt8>?

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
            if (index + 4) < dataArray.count, dataArray[index ..< (index + 4)] == [0, 0, 0, 1] {
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
            spsSize = videoPacket.count - 4
            sps = Array(videoPacket[4 ..< videoPacket.count])
        case 0x08:
            // PPS
            ppsSize = videoPacket.count - 4
            pps = Array(videoPacket[4 ..< videoPacket.count])
        default:
            // B/P frame
            decodeVideoPacket(copy)
            break;
        }
    }

    private func decodeVideoPacket(_ videoPacket: [UInt8]) {

        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: videoPacket)

        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: bufferPointer,
            blockLength: videoPacket.count,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: videoPacket.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

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

            let attachments:CFArray? = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true)

            if let attachmentArray = attachments {
                let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachmentArray, 0), to: CFMutableDictionary.self)

                CFDictionarySetValue(dic,
                                     Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                     Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
            }

            var flagOut = VTDecodeInfoFlags(rawValue: 0)
            var outputBuffer = UnsafeMutablePointer<CVPixelBuffer>.allocate(capacity: 1)

            status = VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: buffer,
                flags: [._EnableAsynchronousDecompression],
                frameRefcon: &outputBuffer,
                infoFlagsOut: &flagOut
            )

            if status == noErr {
                print("OK")
            }else if(status == kVTInvalidSessionErr) {
                print("IOS8VT: Invalid session, reset decoder session");
            } else if(status == kVTVideoDecoderBadDataErr) {
                print("IOS8VT: decode failed status=\(status)(Bad data)");
            } else if(status != noErr) {
                print("IOS8VT: decode failed status=\(status)");
            }
        }
    }

    private func createDecompSession() -> Bool{
        formatDesc = nil

        if let spsData = sps, let ppsData = pps {

            let pointerSPS = UnsafePointer<UInt8>(spsData)
            let pointerPPS = UnsafePointer<UInt8>(ppsData)

            // make pointers array
            let dataParamArray = [pointerSPS, pointerPPS]
            let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(dataParamArray)

            // make parameter sizes array
            let sizeParamArray = [spsData.count, ppsData.count]
            let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)


            let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: 2,
                parameterSetPointers: parameterSetPointers,
                parameterSetSizes: parameterSetSizes,
                nalUnitHeaderLength: 4,
                formatDescriptionOut: &formatDesc
            )

            if let desc = formatDesc, status == noErr {

                if let session = decompressionSession {
                    VTDecompressionSessionInvalidate(session)
                    decompressionSession = nil
                }

                var videoSessionM : VTDecompressionSession?

                let decoderParameters = NSMutableDictionary()
                let destinationPixelBufferAttributes = NSMutableDictionary()
                destinationPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)

                var outputCallback = VTDecompressionOutputCallbackRecord()
                outputCallback.decompressionOutputCallback = decompressionSessionDecodeFrameCallback
                outputCallback.decompressionOutputRefCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

                let status = VTDecompressionSessionCreate(
                    allocator: kCFAllocatorDefault,
                    formatDescription: desc,
                    decoderSpecification: decoderParameters,
                    imageBufferAttributes: destinationPixelBufferAttributes,
                    outputCallback: &outputCallback,
                    decompressionSessionOut: &videoSessionM
                )

                if(status != noErr) {
                    print("\t\t VTD ERROR type: \(status)")
                }

                self.decompressionSession = videoSessionM
            } else {
                print("IOS8VT: reset decoder session failed status=\(status)")
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

private func decompressionSessionDecodeFrameCallback(
    _ decompressionOutputRefCon: UnsafeMutableRawPointer?,
    _ sourceFrameRefCon: UnsafeMutableRawPointer?,
    _ status: OSStatus,
    _ infoFlags: VTDecodeInfoFlags,
    _ imageBuffer: CVImageBuffer?,
    _ presentationTimeStamp: CMTime,
    _ presentationDuration: CMTime
) {

    let streamManager: VideoDecoder = unsafeBitCast(decompressionOutputRefCon, to: VideoDecoder.self)

    if status == noErr {
        streamManager.displayDecodedFrame(imageBuffer);
    }
}
