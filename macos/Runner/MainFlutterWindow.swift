import Cocoa
import FlutterMacOS
import AVFoundation

class AudioGenerator {
    private var audioEngine: AVAudioEngine?
    private var oscillatorNode: AVAudioSourceNode?
    private var phase: Double = 0
    private var phaseIncrement: Double = 0
    private var isPlaying = false
    private var stopTimer: Timer?
    
    init() {
        audioEngine = AVAudioEngine()
    }
    
    func playTone(frequency: Double, duration: Double) {
        // Stop any currently playing tone
        stopTone()
        
        guard let audioEngine = audioEngine else { return }
        
        do {
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

class MainFlutterWindow: NSWindow {
  private let audioGenerator = AudioGenerator()
  
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // Setup method channel for audio
    let channel = FlutterMethodChannel(
      name: "com.example.tuner2/audio",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "playTone":
        if let args = call.arguments as? [String: Any],
           let frequency = args["frequency"] as? Double {
          self?.audioGenerator.playTone(frequency: frequency, duration: 3.0)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing frequency", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
