//
//  AudioDataHeader.h
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 11/11/20.
//

#import <Foundation/Foundation.h>

@class AVAudioPCMBuffer;

struct AudioDataHeader {
    uint64_t timestamp;
    int channels;
    int dataLength;
};
