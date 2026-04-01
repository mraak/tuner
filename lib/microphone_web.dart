import 'dart:js_interop';

@JS('startMicrophoneCapture')
external JSPromise startMicrophoneCapture(JSFunction onUpdate);

@JS('stopMicrophoneCapture')
external void stopMicrophoneCapture();

void startWebMicrophone(void Function(double freq, double amp) onUpdate) {
  final jsCallback = ((JSNumber freq, JSNumber amp) {
    onUpdate(freq.toDartDouble(), amp.toDartDouble());
  }).toJS;
  startMicrophoneCapture(jsCallback);
}

void stopWebMicrophone() {
  stopMicrophoneCapture();
}
