import AVFoundation

/// Short synthesized tone. No audio file is shipped with the app.
final class BeepPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat

    init() {
        let sampleFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        format = sampleFormat
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: sampleFormat)
    }

    func play() {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 0.14)
        guard frameCount > 1,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        let count = Int(frameCount)
        let frequency = 880.0
        for index in 0..<count {
            let time = Double(index) / sampleRate
            let window = 0.5 - 0.5 * cos((2 * Double.pi * Double(index)) / Double(count - 1))
            channel[index] = Float(sin(2 * Double.pi * frequency * time) * 0.9 * window)
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true, options: [])
        if !engine.isRunning {
            try? engine.start()
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        player.play()
    }

    func stop() {
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
    }
}
