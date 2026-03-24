import AVFoundation
import Accelerate

class AudioGenerator {
    private var audioEngine: AVAudioEngine?
    private var oscillatorNode: AVAudioSourceNode?
    private var phase: Double = 0
    private var phaseIncrement: Double = 0
    private var isPlaying = false
    private var stopTimer: Timer?
    
    private var recordingEngine: RecordingEngine?
    private var frequencyCallback: ((Double, Double) -> Void)?
    
    init() {
        audioEngine = AVAudioEngine()
        recordingEngine = RecordingEngine()
    }
    
    func setFrequencyCallback(_ callback: @escaping (Double, Double) -> Void) {
        self.frequencyCallback = callback
        recordingEngine?.setFrequencyCallback(callback)
    }
    
    func startMicrophoneCapture() throws {
        try recordingEngine?.startRecording()
    }
    
    func stopMicrophoneCapture() {
        recordingEngine?.stopRecording()
    }
    
    func playTone(frequency: Double, duration: Double) {
        // Stop any currently playing tone
        stopTone()
        
        guard let audioEngine = audioEngine else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("Playing tone at frequency: \(frequency) Hz")
            
            let sampleRate = 44100.0
            phaseIncrement = (frequency * 2 * .pi) / sampleRate
            phase = 0
            isPlaying = true
            
            // Create oscillator node
            let oscillator = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self, self.isPlaying else {
                    return noErr
                }
                
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let buffer = buffers[0]
                let floatData = buffer.mData!.assumingMemoryBound(to: Float.self)
                
                // Generate sine wave
                for i in 0 ..< Int(frameCount) {
                    let sample = Float(sin(self.phase)) * 0.8
                    floatData[i] = sample
                    self.phase += self.phaseIncrement
                    if self.phase > 2 * .pi {
                        self.phase -= 2 * .pi
                    }
                }
                
                return noErr
            }
            
            audioEngine.attach(oscillator)
            
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            audioEngine.connect(oscillator, to: audioEngine.mainMixerNode, format: format)
            
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            oscillatorNode = oscillator
            
            // Stop after duration
            stopTimer?.invalidate()
            stopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.stopTone()
            }
            
        } catch {
            print("Audio error: \(error)")
        }
    }
    
    func stopTone() {
        stopTimer?.invalidate()
        stopTimer = nil
        
        isPlaying = false
        if let oscillator = oscillatorNode, let audioEngine = audioEngine {
            audioEngine.detach(oscillator)
            oscillatorNode = nil
        }
    }
}

enum AudioError: Error {
    case noAudioEngine
    case noInputNode
}
