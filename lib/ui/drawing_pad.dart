import 'package:flutter/material.dart';

import 'ui_contract.dart';

class DrawingPad extends StatefulWidget {
  const DrawingPad({
    super.key,
    required this.cells,
    required this.enabled,
    required this.onChanged,
  });
  final int cells;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<DrawingPad> createState() => DrawingPadState();
}

class DrawingPadState extends State<DrawingPad> {
  final List<InkStroke> _strokes = [];
  List<InkPoint>? _current;
  Size _size = Size.zero;

  InkSubmission get submission => InkSubmission(
    strokes: [for (final stroke in _strokes) InkStroke(List.of(stroke.points))],
    width: _size.width,
    height: _size.height,
  );

  void _begin(Offset point) {
    if (!widget.enabled) return;
    setState(() => _current = [_point(point)]);
  }

  InkPoint _point(Offset point) => InkPoint(
    point.dx.clamp(0, _size.width),
    point.dy.clamp(0, _size.height),
    DateTime.now().millisecondsSinceEpoch,
  );

  void _move(Offset point) {
    if (!widget.enabled || _current == null) return;
    setState(() => _current!.add(_point(point)));
  }

  void _finish() {
    if (_current == null) return;
    setState(() {
      _strokes.add(InkStroke(_current!));
      _current = null;
    });
    widget.onChanged(_strokes.isNotEmpty);
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
    widget.onChanged(false);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    widget.onChanged(_strokes.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final cells = widget.cells.clamp(1, 3);
          final width = constraints.maxWidth.clamp(
            0.0,
            cells == 1 ? 290.0 : 520.0,
          );
          final height = width / cells;
          _size = Size(width, height);
          return Semantics(
            label:
                'Handwriting area with $cells writing ${cells == 1 ? "cell" : "cells"}. Draw with your finger or stylus.',
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: widget.enabled
                      ? (event) => _begin(event.localPosition)
                      : null,
                  onPanUpdate: widget.enabled
                      ? (event) => _move(event.localPosition)
                      : null,
                  onPanEnd: widget.enabled ? (_) => _finish() : null,
                  onPanCancel: widget.enabled
                      ? () => setState(() => _current = null)
                      : null,
                  onTapUp: widget.enabled ? (_) => _finish() : null,
                  child: CustomPaint(
                    painter: _InkPainter(
                      strokes: _strokes,
                      current: _current,
                      cells: cells,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: widget.enabled && _strokes.isNotEmpty ? _undo : null,
            icon: const Icon(Icons.undo_rounded, size: 19),
            label: const Text('Undo'),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: widget.enabled && _strokes.isNotEmpty ? clear : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            label: const Text('Clear'),
          ),
        ],
      ),
      Text(
        'Write one character in each cell, at a natural size.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _InkPainter extends CustomPainter {
  const _InkPainter({
    required this.strokes,
    required this.current,
    required this.cells,
  });
  final List<InkStroke> strokes;
  final List<InkPoint>? current;
  final int cells;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfffffefb),
    );
    final guide = Paint()
      ..color = const Color(0xffe5e2dd)
      ..strokeWidth = 1;
    final border = Paint()
      ..color = const Color(0xffbcb9c5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final cellWidth = size.width / cells;
    for (var cell = 0; cell < cells; cell++) {
      final centerX = (cell + .5) * cellWidth;
      for (double y = 0; y < size.height; y += 12) {
        canvas.drawLine(
          Offset(centerX, y),
          Offset(centerX, (y + 6).clamp(0, size.height)),
          guide,
        );
      }
      for (double x = cell * cellWidth; x < (cell + 1) * cellWidth; x += 12) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset((x + 6).clamp(0, size.width), size.height / 2),
          guide,
        );
      }
      if (cell > 0) {
        canvas.drawLine(
          Offset(cell * cellWidth, 0),
          Offset(cell * cellWidth, size.height),
          border,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(.5),
        const Radius.circular(18),
      ),
      border,
    );
    final ink = Paint()
      ..color = const Color(0xff30314c)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final points in [
      ...strokes.map((stroke) => stroke.points),
      ?current,
    ]) {
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(
          Offset(points.first.x, points.first.y),
          2,
          Paint()..color = ink.color,
        );
        continue;
      }
      final path = Path()..moveTo(points.first.x, points.first.y);
      for (final point in points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}
