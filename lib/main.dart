import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late web.AudioContext audioContext;
  web.OscillatorNode? currentOscillator;
  String selectedTuning = 'Standard';

  late List<GuitarNote> guitarNotes;

  @override
  void initState() {
    super.initState();
    audioContext = web.AudioContext();
    guitarNotes = guitarTunings[selectedTuning]!.notes;
  }

  void updateTuning(String tuning) {
    setState(() {
      selectedTuning = tuning;
      guitarNotes = guitarTunings[tuning]!.notes;
    });
  }

  void playNote(double frequency) {
    // Stop any currently playing note
    currentOscillator?.stop();

    final oscillator = audioContext.createOscillator();
    final gainNode = audioContext.createGain();

    oscillator.type = 'sine';
    oscillator.frequency.value = frequency;

    // Connect oscillator to gain to audio context
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    // Set gain (volume)
    gainNode.gain.value = 0.3;

    // Play the note
    oscillator.start();
    currentOscillator = oscillator;

    // Stop after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (currentOscillator == oscillator) {
        gainNode.gain
            .linearRampToValueAtTime(0, audioContext.currentTime + 0.5);
        oscillator.stop(audioContext.currentTime + 0.5);
        currentOscillator = null;
      }
    });
  }

  @override
  void dispose() {
    currentOscillator?.stop();
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
                  child: GestureDetector(
                    onTap: () => playNote(note.frequency),
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
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            note.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${note.frequency.toStringAsFixed(1)} Hz',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
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
