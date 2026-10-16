import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

typedef InkSample = ({double x, double y, int milliseconds});

/// Native recognition is isolated so lesson tests never need a device model.
abstract interface class HandwritingService {
  Future<bool> isReady();
  Future<void> download();
  Future<List<String>> recognize({
    required List<List<InkSample>> strokes,
    required double width,
    required double height,
  });
  Future<void> close();
}

class MlKitHandwritingService implements HandwritingService {
  final _modelManager = DigitalInkRecognizerModelManager();
  final _recognizer = DigitalInkRecognizer(languageCode: 'ja');

  @override
  Future<bool> isReady() => _modelManager.isModelDownloaded('ja');

  @override
  Future<void> download() async {
    final downloaded = await _modelManager.downloadModel('ja');
    if (!downloaded || !await isReady()) {
      throw StateError(
        'The Japanese handwriting model could not be downloaded.',
      );
    }
  }

  @override
  Future<List<String>> recognize({
    required List<List<InkSample>> strokes,
    required double width,
    required double height,
  }) async {
    if (!await isReady()) {
      throw StateError('Download the Japanese handwriting model first.');
    }
    if (width <= 0 ||
        height <= 0 ||
        strokes.every((stroke) => stroke.isEmpty)) {
      return const [];
    }
    final ink = Ink();
    ink.strokes = strokes.where((points) => points.isNotEmpty).map((points) {
      final stroke = Stroke();
      stroke.points = points
          .map((p) => StrokePoint(x: p.x, y: p.y, t: p.milliseconds))
          .toList();
      return stroke;
    }).toList();
    final candidates = await _recognizer
        .recognize(
          ink,
          context: DigitalInkRecognitionContext(
            writingArea: WritingArea(width: width, height: height),
          ),
        )
        .timeout(const Duration(seconds: 20));
    return candidates.map((candidate) => candidate.text).toList();
  }

  @override
  Future<void> close() async => _recognizer.close();
}
