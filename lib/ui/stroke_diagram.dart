import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// flutter_svg does not render SVG text nodes. Preserve KanjiVG's original
/// stroke labels as Flutter text positioned in the same view box.
class StrokeDiagram extends StatefulWidget {
  const StrokeDiagram({super.key, required this.rune});
  final int rune;

  @override
  State<StrokeDiagram> createState() => _StrokeDiagramState();
}

class _StrokeDiagramState extends State<StrokeDiagram> {
  static final _cache = <int, Future<_Diagram>>{};

  Future<_Diagram> get _diagram => _cache.putIfAbsent(widget.rune, () async {
    final source = await rootBundle.loadString(
      'assets/strokes/${widget.rune.toRadixString(16).padLeft(5, '0')}.svg',
    );
    final labels = <_StrokeNumber>[];
    final textNodes = RegExp(
      r'<text\b[^>]*transform="matrix\(([^\"]+)\)"[^>]*>(\d+)</text>',
    );
    for (final match in textNodes.allMatches(source)) {
      final values = match
          .group(1)!
          .trim()
          .split(RegExp(r'[\s,]+'))
          .map(double.parse)
          .toList();
      if (values.length == 6) {
        labels.add(_StrokeNumber(match.group(2)!, values[4], values[5]));
      }
    }
    final viewBox = RegExp(r'viewBox="([^"]+)"')
        .firstMatch(source)
        ?.group(1)
        ?.split(RegExp(r'\s+'))
        .map(double.parse)
        .toList();
    return _Diagram(
      source.replaceAll(RegExp(r'<text\b[^>]*>.*?</text>', dotAll: true), ''),
      labels,
      viewBox != null && viewBox.length == 4 ? viewBox[2] : 109,
      viewBox != null && viewBox.length == 4 ? viewBox[3] : 109,
    );
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<_Diagram>(
    future: _diagram,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text(
            String.fromCharCode(widget.rune),
            style: const TextStyle(color: Colors.black, fontSize: 78),
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) return const Center(child: CircularProgressIndicator());
      return Semantics(
        image: true,
        label:
            'Stroke-order diagram for ${String.fromCharCode(widget.rune)}, ${data.numbers.length} numbered strokes',
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: SvgPicture.string(
                  data.svg,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              ...data.numbers.map(
                (number) => Positioned(
                  left: number.x / data.width * constraints.maxWidth,
                  top: (number.y - 8) / data.height * constraints.maxHeight,
                  child: Text(
                    number.label,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 8 * constraints.maxHeight / data.height,
                      height: 1,
                      color: const Color(0xff6c667b),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Diagram {
  const _Diagram(this.svg, this.numbers, this.width, this.height);
  final String svg;
  final List<_StrokeNumber> numbers;
  final double width;
  final double height;
}

class _StrokeNumber {
  const _StrokeNumber(this.label, this.x, this.y);
  final String label;
  final double x;
  final double y;
}
