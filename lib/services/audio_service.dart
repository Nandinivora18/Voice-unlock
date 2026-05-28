// audio_service.dart
// Handles microphone access, recording (WAV, 16 kHz mono), and file I/O.
// Uses the `record` package (v5) and `path_provider` for temp storage.

import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  AudioService._();

  static final AudioRecorder _recorder = AudioRecorder();

  /// Request microphone permission at runtime.
  /// Returns true if granted.
  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// Start recording to a temporary WAV file.
  /// Returns the file path if started successfully, null otherwise.
  static Future<String?> startRecording() async {
    final hasPermission = await requestMicPermission();
    if (!hasPermission) return null;

    // Use the system temp directory — no sensitive data written to SD card.
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/cw_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,   // uncompressed WAV for accurate MFCCs
        sampleRate: 16000,           // 16 kHz — standard for speech
        numChannels: 1,              // mono
        bitRate: 256000,
      ),
      path: path,
    );
    return path;
  }

  /// Stop the active recording.
  /// Returns the recorded [File] or null if nothing was recorded.
  static Future<File?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file;
  }

  /// True while a recording session is active.
  static Future<bool> get isRecording => _recorder.isRecording();

  /// Release native recorder resources (call from dispose()).
  static void dispose() {
    _recorder.dispose();
  }
}
