//
//  OculusMRC.h
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class OculusMRC;

enum speaker_layout {
    SPEAKERS_MONO,
    SPEAKERS_STEREO
};

enum audio_format {
    AUDIO_FORMAT_FLOAT
};
struct SourceAudio {
    const uint8_t *data;
    uint32_t frames;

    enum speaker_layout speakers;
    enum audio_format format;
    uint32_t samples_per_sec;

    uint64_t timestamp;
};

@protocol OculusMRCDelegate <NSObject>
- (void)oculusMRC:(OculusMRC *)oculusMRC didReceiveImage:(UIImage *)image;
- (void)oculusMRC:(OculusMRC *)oculusMRC didReceiveAudio:(struct SourceAudio *)audio;
@end

@interface OculusMRC : NSObject

@property (nonatomic, weak) id<OculusMRCDelegate> delegate;

- (instancetype)initWithHardwareDecoder:(BOOL)useHardwareDecoder;
- (void)addData:(const uint8_t *)data length:(int32_t)length;
- (void)update;

@end

NS_ASSUME_NONNULL_END
