import AVFoundation
import Accelerate

class AudioGenerator {
    private var audioEngine: AVAudioEngine?
    private var oscillatorNode: AVAudioSourceNode?
    private var phase: Double = 0
    private var phaseIncrement: Double = 0
    private var isPlaying = false
    
    init() {
        audioEngine = AVAudioEngine()
    }
    
    func playTone(frequency: Double, duration: Double) {
        guard let audioEngine = audioEngine else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let sampleRate = audioEngine.mainMixerNode.outputFormat(forBus: 0)?.sampleRate ?? 44100
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
                    let sample = Float(sin(self.phase)) * 0.3
                    floatData[i] = sample
                    self.phase += self.phaseIncrement
                    if self.phase > 2 * .pi {
                        self.phase -= 2 * .pi
                    }
                }
                
                return noErr
            }
            
            audioEngine.attach(oscillator)
            let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)!
            audioEngine.connect(oscillator, to: audioEngine.mainMixerNode, format: format)
            
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            oscillatorNode = oscillator
            
            // Stop after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.stopTone()
            }
            
        } catch {
            print("Audio error: \(error)")
        }
    }
    
    func stopTone() {
        isPlaying = false
        if let oscillator = oscillatorNode, let audioEngine = audioEngine {
            audioEngine.detach(oscillator)
            oscillatorNode = nil
        }
    }
}
