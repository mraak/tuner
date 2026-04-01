import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'microphone_native.dart' if (dart.library.js_interop) 'microphone_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuner2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class GuitarNote {
  final String name;
  final double frequency;

  GuitarNote({required this.name, required this.frequency});
}

class GuitarTuning {
  final String name;
  final List<GuitarNote> notes;

  GuitarTuning({required this.name, required this.notes});
}

final Map<String, GuitarTuning> guitarTunings = {
  'Standard': GuitarTuning(
    name: 'Standard',
    notes: [
      GuitarNote(name: 'E', frequency: 82.41),
      GuitarNote(name: 'A', frequency: 110.00),
      GuitarNote(name: 'D', frequency: 146.83),
      GuitarNote(name: 'G', frequency: 196.00),
      GuitarNote(name: 'B', frequency: 246.94),
      GuitarNote(name: 'High E', frequency: 329.63),
    ],
  ),
  'Drop D': GuitarTuning(
    name: 'Drop D',
    notes: [
      GuitarNote(name: 'D', frequency: 73.42),
      GuitarNote(name: 'A', frequency: 110.00),
      GuitarNote(name: 'D', frequency: 146.83),
      GuitarNote(name: 'G', frequency: 196.00),
      GuitarNote(name: 'B', frequency: 246.94),
      GuitarNote(name: 'High E', frequency: 329.63),
    ],
  ),
  'Open G': GuitarTuning(
    name: 'Open G',
    notes: [
      GuitarNote(name: 'D', frequency: 73.42),
      GuitarNote(name: 'G', frequency: 98.00),
      GuitarNote(name: 'D', frequency: 146.83),
      GuitarNote(name: 'G', frequency: 196.00),
      GuitarNote(name: 'B', frequency: 246.94),
      GuitarNote(name: 'High D', frequency: 293.66),
    ],
  ),
  'Ukulele': GuitarTuning(
    name: 'Ukulele',
    notes: [
      GuitarNote(name: 'G', frequency: 392.00),
      GuitarNote(name: 'C', frequency: 261.63),
      GuitarNote(name: 'E', frequency: 329.63),
      GuitarNote(name: 'A', frequency: 440.00),
    ],
  ),
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedTuning = 'Standard';
  late List<GuitarNote> guitarNotes;
  static const audioChannel = MethodChannel('com.example.tuner2/audio');
  double detectedFrequency = 0.0;
  double detectedAmplitude = 0.0;
  bool isMicListening = false;

  @override
  void initState() {
    super.initState();
    guitarNotes = guitarTunings[selectedTuning]!.notes;
    audioChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'frequencyUpdate') {
      final double frequency = call.arguments['frequency'] as double;
      final double amplitude = call.arguments['amplitude'] as double;
      setState(() {
        detectedFrequency = frequency;
        detectedAmplitude = amplitude;
      });
    }
  }

  void updateTuning(String tuning) {
    setState(() {
      selectedTuning = tuning;
      guitarNotes = guitarTunings[tuning]!.notes;
    });
  }

  void playNote(double frequency) {
    try {
      audioChannel.invokeMethod('playTone', {'frequency': frequency});
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
    }
  }

  void toggleMicrophone() async {
    if (kIsWeb) {
      if (isMicListening) {
        stopWebMicrophone();
        setState(() {
          isMicListening = false;
          detectedFrequency = 0.0;
          detectedAmplitude = 0.0;
        });
      } else {
        setState(() { isMicListening = true; });
        startWebMicrophone((freq, amp) {
          if (mounted) {
            setState(() {
              detectedFrequency = freq;
              detectedAmplitude = amp;
            });
          }
        });
      }
      return;
    }

    try {
      final bool success =
          await audioChannel.invokeMethod('toggleMicrophone') as bool;
      setState(() {
        isMicListening = success;
      });
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guitar Tuner'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Microphone frequency display
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMicListening ? Colors.green : Colors.grey.shade700,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detected Frequency',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detectedFrequency > 0
                              ? '${detectedFrequency.toStringAsFixed(2)} Hz'
                              : '-- Hz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Amplitude',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detectedAmplitude > 0
                              ? '${detectedAmplitude.toStringAsFixed(2)}'
                              : '--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: toggleMicrophone,
                  icon: Icon(isMicListening ? Icons.mic : Icons.mic_none),
                  label: Text(isMicListening ? 'Stop Listening' : 'Start Listening'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isMicListening ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          // Tuning dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade400, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DropdownButton<String>(
                  value: selectedTuning,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      updateTuning(newValue);
                    }
                  },
                  items: guitarTunings.keys
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          // Small buttons below dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: guitarNotes.map((note) {
                return SizedBox(
                  width: 70,
                  child: TunerNoteButton(
                    note: note,
                    onPressed: () => playNote(note.frequency),
                  ),
                );
              }).toList(),
            ),
          ),
          // Empty space below
          Expanded(
            child: Container(),
          ),
        ],
      ),
    );
  }
}

class TunerButton extends StatelessWidget {
  final GuitarNote note;
  final VoidCallback onPressed;

  const TunerButton({
    required this.note,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              note.name,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${note.frequency.toStringAsFixed(2)} Hz',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TunerNoteButton extends StatefulWidget {
  final GuitarNote note;
  final VoidCallback onPressed;

  const TunerNoteButton({
    required this.note,
    required this.onPressed,
    super.key,
  });

  @override
  State<TunerNoteButton> createState() => _TunerNoteButtonState();
}

class _TunerNoteButtonState extends State<TunerNoteButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        widget.onPressed();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 5,
              offset: _isPressed ? const Offset(0, 1) : const Offset(0, 2),
            ),
          ],
        ),
        transform: Matrix4.identity()..translate(0.0, _isPressed ? 2.0 : 0.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.note.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.note.frequency.toStringAsFixed(1)} Hz',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
