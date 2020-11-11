//
//  AudioDataHeader.m
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/11/20.
//

#import "AudioDataHeader.h"
#import <AVFoundation/AVFoundation.h>

AVAudioPCMBuffer * pcmBufferFrom(struct AudioDataHeader * audioDataHeader, double sampleRate, float * data) {
    AVAudioFormat * format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                  sampleRate:sampleRate channels:audioDataHeader->channels interleaved:NO];

    uint32_t frames = audioDataHeader->dataLength / sizeof(float) / audioDataHeader->channels;

    AVAudioPCMBuffer * buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frames];
    buffer.frameLength = buffer.frameCapacity;

    for(int ch = 0; ch < audioDataHeader->channels; ch++) {
        for(int i = 0; i < frames; i++) {
            buffer.floatChannelData[ch][i] = data[i + ch + (i * (audioDataHeader->channels - 1))];
        }
    }

    return buffer;
}
