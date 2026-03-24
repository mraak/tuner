import AVFoundation
import Accelerate

class RecordingEngine {
    private var recordingAudioEngine: AVAudioEngine?
    private var frequencyCallback: ((Double, Double) -> Void)?
    private var isListening = false
    
    init() {
        recordingAudioEngine = AVAudioEngine()
    }
    
    func setFrequencyCallback(_ callback: @escaping (Double, Double) -> Void) {
        self.frequencyCallback = callback
    }
    
    func startRecording() throws {
        guard let engine = recordingAudioEngine else { throw AudioError.noAudioEngine }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, options: [])
        try audioSession.setActive(true)
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0) ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.analyzeBuffer(buffer)
        }
        
        if !engine.isRunning {
            try engine.start()
        }
        
        isListening = true
    }
    
    func stopRecording() {
        guard let engine = recordingAudioEngine else { return }
        
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        
        do {
            try engine.stop()
        } catch {
            print("Error stopping recording engine: \(error)")
        }
        
        isListening = false
    }
    
    private func analyzeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
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
}
