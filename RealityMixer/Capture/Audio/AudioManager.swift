//
//  AudioManager.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 16/08/2021.
//

import Foundation
import AVFoundation

final class AudioManager {
    private var currentAudioFormat: AVAudioFormat?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?

    private func configureAudio(with audioFormat: AVAudioFormat) {
        let audioEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let mainMixerNode = audioEngine.mainMixerNode

        audioEngine.attach(player)
        audioEngine.connect(player, to: mainMixerNode, format: audioFormat)
        audioEngine.prepare()

        do {
            try audioEngine.start()
            player.play()

            audioEngine.mainMixerNode.outputVolume = 1.0
            self.audioEngine = audioEngine
            self.audioPlayer = player
        } catch {
            print("Unable to start audio: \(error)")
        }
    }

    func play(audio: AVAudioPCMBuffer, timestamp: UInt64) {

        if currentAudioFormat == nil {
            // We'll just try to initialize it once (even if it fails)
            self.currentAudioFormat = audio.format
            configureAudio(with: audio.format)
        }

        guard let currentAudioFormat = currentAudioFormat,
            audio.format.sampleRate == currentAudioFormat.sampleRate,
            audio.format.channelCount == currentAudioFormat.channelCount
        else {
            print("Unexpected audio format")
            return
        }

        let sampleTime = AVAudioFramePosition(Double(timestamp)/1_000_000 * currentAudioFormat.sampleRate)

        let audioTime = AVAudioTime(
            sampleTime: sampleTime,
            atRate: currentAudioFormat.sampleRate
        )

        audioPlayer?.scheduleBuffer(audio, at: audioTime, options: .interruptsAtLoop, completionHandler: nil)
    }

    func invalidate() {
        audioPlayer?.stop()
        audioEngine?.stop()
    }

    deinit {
        invalidate()
    }
}
