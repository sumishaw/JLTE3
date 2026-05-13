import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver {

  static const platform = MethodChannel('overlay_channel');

  bool isRunning = false;

  String sourceLanguage = 'Auto';
  String targetLanguage = 'English';

  final Map<String, String> sourceLanguages = {
    'Auto': 'auto',
    'Japanese': 'ja',
    'English': 'en',
    'Chinese': 'zh',
    'Korean': 'ko',
    'German': 'de',
    'Spanish': 'es',
    'Turkish': 'tr',
  };

  final Map<String, String> targetLanguages = {
    'English': 'en',
    'Hindi': 'hi',
  };

  Future<void> start() async {
    await platform.invokeMethod('setLanguages', {
      'source': sourceLanguages[sourceLanguage],
      'target': targetLanguages[targetLanguage],
    });

    await platform.invokeMethod('startOverlay');

    setState(() {
      isRunning = true;
    });
  }

  Future<void> stop() async {
    await platform.invokeMethod('stopOverlay');

    setState(() {
      isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Nihongo Lens',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              DropdownButtonFormField<String>(
                value: sourceLanguage,
                decoration: const InputDecoration(
                  labelText: 'Caption Language',
                ),
                items: sourceLanguages.keys.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      sourceLanguage = v;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: targetLanguage,
                decoration: const InputDecoration(
                  labelText: 'Translate To',
                ),
                items: targetLanguages.keys.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      targetLanguage = v;
                    });
                  }
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isRunning ? stop : start,
                  child: Text(
                    isRunning ? 'STOP' : 'START',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
