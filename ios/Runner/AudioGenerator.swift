import AVFoundation
import Accelerate

class AudioGenerator {
    private var audioEngine: AVAudioEngine?
    private var oscillatorNode: AVAudioSourceNode?
    private var phase: Double = 0
    private var phaseIncrement: Double = 0
    private var isPlaying = false
    private var stopTimer: Timer?
    
    // Microphone capture
    private var inputNode: AVAudioInputNode?
    private var isListening = false
    private var frequencyCallback: ((Double, Double) -> Void)?
    
    init() {
        audioEngine = AVAudioEngine()
    }
    
    func setFrequencyCallback(_ callback: @escaping (Double, Double) -> Void) {
        self.frequencyCallback = callback
    }
    
    func startMicrophoneCapture() throws {
        guard let audioEngine = audioEngine else { throw AudioError.noAudioEngine }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else { throw AudioError.noInputNode }
        
        let format = inputNode.outputFormat(forBus: 0) ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.analyzeBuffer(buffer)
        }
        
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        
        isListening = true
    }
    
    func stopMicrophoneCapture() {
        guard let audioEngine = audioEngine, let inputNode = inputNode else { return }
        
        inputNode.removeTap(onBus: 0)
        
        do {
            try audioEngine.stop()
        } catch {
            print("Error stopping audio engine: \(error)")
        }
        
        isListening = false
    }
    
    private func analyzeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Simple FFT-based frequency detection
        let (frequency, amplitude) = detectFrequency(data: data, length: frameLength)
        
        DispatchQueue.main.async {
            self.frequencyCallback?(frequency, amplitude)
        }
    }
    
    private func detectFrequency(data: UnsafeMutablePointer<Float>, length: Int) -> (frequency: Double, amplitude: Double) {
        // Perform FFT
        let fftSize = vDSP_Length(length)
        let halfSize = Int(fftSize) / 2
        
        var input = [Float](repeating: 0, count: length)
        var output = [Float](repeating: 0, count: length)
        
        // Copy input data
        memcpy(&input, data, length * MemoryLayout<Float>.stride)
        
        // Create FFT setup
        guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), Int32(kFFTRadix2)) else {
            return (frequency: 0, amplitude: 0)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Convert to complex format
        var complexBuffer = [DSPComplex](repeating: DSPComplex(real: 0, imag: 0), count: halfSize)
        input.withUnsafeBytes { inputBytes in
            var splitComplex = DSPSplitComplex(
                realp: UnsafeMutablePointer<Float>(mutating: [Float](repeating: 0, count: halfSize)),
                imagp: UnsafeMutablePointer<Float>(mutating: [Float](repeating: 0, count: halfSize))
            )
            
            for i in 0..<halfSize {
                if i < length {
                    complexBuffer[i].real = input[i]
                }
            }
        }
        
        // Simple peak detection in magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: halfSize)
        for i in 0..<halfSize {
            let real = complexBuffer[i].real
            let imag = complexBuffer[i].imag
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // Find peak
        var maxMagnitude: Float = 0
        var peakBin = 0
        for i in 20..<halfSize { // Skip very low frequencies (below ~44Hz at 44.1kHz)
            if magnitudes[i] > maxMagnitude {
                maxMagnitude = magnitudes[i]
                peakBin = i
            }
        }
        
        // Convert bin to frequency (44.1kHz sample rate)
        let frequency = Double(peakBin) * 44100.0 / Double(length)
        let amplitude = Double(maxMagnitude)
        
        return (frequency: frequency, amplitude: amplitude)
    }
    
    func playTone(frequency: Double, duration: Double) {
        // Stop any currently playing tone
        stopTone()
        
        guard let audioEngine = audioEngine else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
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
