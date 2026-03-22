import AVFoundation
import Accelerate

class AudioGenerator {
    private var audioEngine: AVAudioEngine?
    private var oscillatorNode: AVAudioSourceNode?
    private var phase: Double = 0
    private var phaseIncrement: Double = 0
    private var isPlaying = false
    private var stopTimer: Timer?
    
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
        try audioSession.setCategory(.record, options: [])
        try audioSession.setActive(true)
        
        let inputNode = audioEngine.inputNode
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
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
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
        // Apply Hann window to reduce spectral leakage
        var window = [Float](repeating: 0, count: length)
        vDSP_hann_window(&window, vDSP_Length(length), Int32(vDSP_HANN_NORM))
        
        var windowed = [Float](repeating: 0, count: length)
        vDSP_vmul(data, 1, window, 1, &windowed, 1, vDSP_Length(length))
        
        // Calculate RMS to determine if there's enough signal
        var rmsValue: Float = 0
        vDSP_rmsqv(windowed, 1, &rmsValue, vDSP_Length(length))
        
        // If signal is too quiet, return 0
        if rmsValue < 0.001 {
            return (0, 0)
        }
        
        // Use autocorrelation for more robust pitch detection
        let maxLag = length / 2
        var autocorr = [Float](repeating: 0, count: maxLag)
        
        // Calculate autocorrelation
        for lag in 0..<maxLag {
            var sum: Float = 0
            for i in 0..<(length - lag) {
                sum += windowed[i] * windowed[i + lag]
            }
            autocorr[lag] = sum
        }
        
        // Find the first peak after the initial zero lag (which is the strongest)
        let minPeriod = Int(44100 / 400) // Minimum frequency ~400Hz
        let maxPeriod = Int(44100 / 50)  // Maximum frequency ~50Hz
        
        var maxValue: Float = 0
        var peakLag = minPeriod
        
        for lag in minPeriod..<min(maxPeriod, maxLag) {
            // Look for peaks in autocorrelation
            if lag > minPeriod && lag < maxLag - 1 {
                if autocorr[lag] > autocorr[lag - 1] && 
                   autocorr[lag] > autocorr[lag + 1] &&
                   autocorr[lag] > maxValue {
                    maxValue = autocorr[lag]
                    peakLag = lag
                }
            }
        }
        
        // Convert lag to frequency
        let frequency = 44100.0 / Double(peakLag)
        let amplitude = Double(maxValue) / Double(length)
        
        // Only return if confidence is reasonably high
        let confidence = maxValue / autocorr[0]
        if confidence > 0.1 {
            return (frequency, amplitude)
        } else {
            return (0, 0)
        }
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
