import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// All the text ML Kit can read in the photo, or null if it can't.
Future<String?> readTextFromImage(String filePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(filePath));
    return result.text;
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}

const canReadIds = true;
