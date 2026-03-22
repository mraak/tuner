import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  var audioGenerator: AudioGenerator?
  var audioChannel: FlutterMethodChannel?
  var isMicListening = false
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    audioGenerator = AudioGenerator()
    
    // Get the binary messenger from the plugin registry
    let registry = engineBridge.pluginRegistry
    let binaryMessenger = registry as? FlutterBinaryMessenger
    
    guard let messenger = binaryMessenger else {
      print("Failed to get binary messenger")
      return
    }
    
    audioChannel = FlutterMethodChannel(
      name: "com.example.tuner2/audio",
      binaryMessenger: messenger
    )
    
    // Set up frequency callback
    audioGenerator?.setFrequencyCallback { [weak self] frequency, amplitude in
      self?.audioChannel?.invokeMethod("frequencyUpdate", arguments: [
        "frequency": frequency,
        "amplitude": amplitude
      ])
    }
    
    audioChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "playTone":
        if let args = call.arguments as? [String: Any],
           let frequency = args["frequency"] as? Double {
          self?.audioGenerator?.playTone(frequency: frequency, duration: 3.0)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
        }
      case "toggleMicrophone":
        do {
          if let audioGenerator = self?.audioGenerator {
            self?.isMicListening = !(self?.isMicListening ?? false)
            if self?.isMicListening ?? false {
              try audioGenerator.startMicrophoneCapture()
            } else {
              audioGenerator.stopMicrophoneCapture()
            }
            result(self?.isMicListening ?? false)
          } else {
            result(false)
          }
        } catch {
          result(FlutterError(code: "MIC_ERROR", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
