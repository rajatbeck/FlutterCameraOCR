import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';

late List<CameraDescription> _cameras;


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Gemini.init(apiKey: <YOUR_API_KEY>);
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterTts flutterTts = FlutterTts();
  late CameraController controller;
  bool _isLoading = false;
  String _responseText = '';

  @override
  void initState() {
    super.initState();
    controller = CameraController(_cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) {
        // TODO: process image frames here
      });
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
          // Handle access errors here.
            break;
          default:
          // Handle other errors here.
            break;
        }
      }
    });
  }

  Future<void> _captureImage() async {
    try {
      setState(() {
        _isLoading = true; // Show loader
      });
      // Capture image
      XFile imageFile = await controller.takePicture();
      File image = File(imageFile.path);

      // Read image bytes
      Uint8List imageBytes = await image.readAsBytes();

      // Send image to Gemini with text
      await _sendImageToGemini(imageBytes);
    } catch (e) {
      print('Error capturing image: $e');
    } finally {
      setState(() {
        _isLoading = false; // Hide loader
      });
    }
  }

  Future<void> _sendImageToGemini(Uint8List imageBytes) async {
    try {
      // Set TTS configurations
      await flutterTts.setVolume(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.0);
      await flutterTts.setLanguage("en-US");

      final response = await Gemini.instance.textAndImage(
        text: "What is this picture?",
        images: [imageBytes],
      );
      setState(() {
        _responseText = response?.content?.parts?.last.text ?? '';
      });
      _speakResponse(_responseText);
    } catch (e) {
      print('Failed to send image to Gemini: $e');
      setState(() {
        _responseText = 'Failed to send image to Gemini: $e';
      });
    }
  }

  Future<void> _speakResponse(String text) async {
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          if (controller.value.isInitialized)
            Expanded(
              child: Stack(
                children: [
                  CameraPreview(controller),
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            )
          else
            Expanded(child: Center(child: CircularProgressIndicator())),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _captureImage,
              child: Text('Capture Image'),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[200],
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _responseText,
                  style: TextStyle(fontSize: 16.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
