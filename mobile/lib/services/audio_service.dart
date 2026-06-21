import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;
  AudioService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<String?> startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentPath = path;

      final recordResult = await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _isRecording = true;
      return path;
    } catch (e) {
      debugPrint('AudioService start error: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path != null && File(path).existsSync()) {
        return path;
      }
      return _currentPath;
    } catch (e) {
      _isRecording = false;
      debugPrint('AudioService stop error: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
