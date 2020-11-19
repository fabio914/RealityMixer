/*
Copyright (C) 2019-present, Facebook, Inc.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "OculusMRC.h"
#import "AudioDataHeader.h"
#include "frame.h"

#include <stdio.h>
#include <string>

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavcodec/videotoolbox.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libavutil/error.h"

AVAudioPCMBuffer * pcmBufferFrom(struct AudioDataHeader * audioDataHeader, double sampleRate, float * data);
}

#define OM_DEFAULT_WIDTH (1920*2)
#define OM_DEFAULT_HEIGHT 1080
#define OM_DEFAULT_AUDIO_SAMPLERATE 48000

// https://medium.com/liveop-x-team/accelerating-h264-decoding-on-ios-with-ffmpeg-and-videotoolbox-1f000cb6c549
static enum AVPixelFormat negotiate_pixel_format(struct AVCodecContext *s, const enum AVPixelFormat *fmt) {
    while (*fmt != AV_PIX_FMT_NONE) {
        if (*fmt == AV_PIX_FMT_VIDEOTOOLBOX) {
            if (s->hwaccel_context == NULL) {
                int result = av_videotoolbox_default_init(s);
                if (result < 0) {
                    return s->pix_fmt;
                }
            }
            return *fmt;
        }
        ++fmt;
    }
    return s->pix_fmt;
}

std::string GetAvErrorString(int errNum) {
    char buf[1024];
    std::string result = av_make_error_string(buf, 1024, errNum);
    return result;
}

@interface OculusMRC () {
    BOOL _enableAudio;
    uint32_t m_width;
    uint32_t m_height;
    uint32_t m_audioSampleRate;

    AVCodec * m_codec;
    AVCodecContext * m_codecContext;

    FrameCollection m_frameCollection;

    std::vector<std::pair<int, std::shared_ptr<Frame>>> m_cachedAudioFrames;
    int m_audioFrameIndex;
    int m_videoFrameIndex;
}

@end

@implementation OculusMRC

- (instancetype)initWithAudio:(BOOL)enableAudio {
    self = [super init];
    if (self) {
        _enableAudio = enableAudio;
        m_width = OM_DEFAULT_WIDTH;
        m_height = OM_DEFAULT_HEIGHT;
        m_audioSampleRate = OM_DEFAULT_AUDIO_SAMPLERATE;

        m_codec = avcodec_find_decoder(AV_CODEC_ID_H264);

        if (!m_codec) {
            fprintf(stderr, "Unable to find decoder\n");
        } else {
            fprintf(stdout, "Codec found. Capabilities 0x%x\n", m_codec->capabilities);
        }

        [self startDecoder];
    }
    return self;
}

- (void)addData:(const uint8_t *)data length:(int32_t)length {
    m_frameCollection.AddData(data, length);
}

- (void)startDecoder {
    if (m_codecContext != nullptr) {
        fprintf(stderr, "Decoder already started\n");
        return;
    }

    if (!m_codec) {
        fprintf(stderr, "m_codec not initalized\n");
        return;
    }

    m_codecContext = avcodec_alloc_context3(m_codec);
    if (!m_codecContext) {
        fprintf(stderr, "Unable to create codec context\n");
        return;
    }

    m_codecContext->get_format = negotiate_pixel_format;

    AVDictionary * dict = nullptr;
    int ret = avcodec_open2(m_codecContext, m_codec, &dict);
    av_dict_free(&dict);
    if (ret < 0)
    {
        fprintf(stderr, "Unable to open codec context\n");
        avcodec_free_context(&m_codecContext);
        return;
    }

    fprintf(stdout, "m_codecContext constructed and opened\n");
}

- (void)stopDecoder {
    if (m_codecContext) {

        // https://medium.com/liveop-x-team/accelerating-h264-decoding-on-ios-with-ffmpeg-and-videotoolbox-1f000cb6c549
        if (m_codecContext->hwaccel_context != NULL) {
            av_videotoolbox_default_free(m_codecContext);
        }

        avcodec_close(m_codecContext);
        avcodec_free_context(&m_codecContext);
        fprintf(stdout, "m_codecContext freed\n");
    }
}

- (void)update {

    while (m_frameCollection.HasCompletedFrame()) {

        auto frame = m_frameCollection.PopFrame();

        if (frame->m_type == Frame::PayloadType::VIDEO_DIMENSION) {
            struct FrameDimension
            {
                int w;
                int h;
            };
            const FrameDimension* dim = (const FrameDimension*)frame->m_payload.data();
            m_width = dim->w;
            m_height = dim->h;

            fprintf(stdout, "[VIDEO_DIMENSION] width %d height %d\n", m_width, m_height);

        } else if (frame->m_type == Frame::PayloadType::VIDEO_DATA) {

            AVPacket * packet = av_packet_alloc();
            AVFrame * picture = av_frame_alloc();

            av_new_packet(packet, (int)frame->m_payload.size());
            assert(packet->data);
            memcpy(packet->data, frame->m_payload.data(), frame->m_payload.size());

            int ret = avcodec_send_packet(m_codecContext, packet);
            if (ret < 0) {
                fprintf(stderr, "avcodec_send_packet error %s\n", GetAvErrorString(ret).c_str());
            } else {

                ret = avcodec_receive_frame(m_codecContext, picture);

                if (ret < 0) {
                    fprintf(stderr, "avcodec_receive_frame error %s\n", GetAvErrorString(ret).c_str());
                } else {
#if DEBUG
                    std::chrono::duration<double> timePassed = std::chrono::system_clock::now() - m_frameCollection.GetFirstFrameTime();
                    fprintf(stdout, "[%f][VIDEO_DATA] size %d width %d height %d format %d\n", timePassed.count(), packet->size, picture->width, picture->height, picture->format);
#endif

                    while (m_cachedAudioFrames.size() > 0 && m_cachedAudioFrames[0].first <= m_videoFrameIndex) {
                        std::shared_ptr<Frame> audioFrame = m_cachedAudioFrames[0].second;

                        AudioDataHeader * audioDataHeader = (AudioDataHeader *)(audioFrame->m_payload.data());

                        if (audioDataHeader->channels == 1 || audioDataHeader->channels == 2) {
                            float * data = (float *)((uint8_t *)audioFrame->m_payload.data() + sizeof(AudioDataHeader));
                            [_delegate oculusMRC: self didReceiveAudio: pcmBufferFrom(audioDataHeader, m_audioSampleRate, data)];
                        } else {
                            fprintf(stderr, "[AUDIO_DATA] unimplemented audio channels %d", audioDataHeader->channels);
                        }

                        m_cachedAudioFrames.erase(m_cachedAudioFrames.begin());
                    }
                    
                    ++m_videoFrameIndex;

                    // Assuming that the VideoToolbox integration is working and that this pixel buffer is available.
                    [_delegate oculusMRC:self didReceivePixelBuffer:(CVPixelBufferRef)picture->data[3]];
                }
            }

            av_frame_free(&picture);
            av_packet_free(&packet);

        } else if (frame->m_type == Frame::PayloadType::AUDIO_SAMPLERATE) {

            m_audioSampleRate = *(uint32_t*)(frame->m_payload.data());
            fprintf(stdout, "[AUDIO_SAMPLERATE] %d\n", m_audioSampleRate);

        } else if (frame->m_type == Frame::PayloadType::AUDIO_DATA) {

            m_cachedAudioFrames.push_back(std::make_pair(m_audioFrameIndex, frame));
            ++m_audioFrameIndex;
#if DEBUG
            std::chrono::duration<double> timePassed = std::chrono::system_clock::now() - m_frameCollection.GetFirstFrameTime();
            fprintf(stdout, "[%f][AUDIO_DATA] timestamp\n", timePassed.count());
#endif

        } else {
            fprintf(stderr, "Unknown payload type: %u\n", frame->m_type);
        }
    }
}

#pragma mark - Deinit

- (void)dealloc {
    [self stopDecoder];
}

@end
