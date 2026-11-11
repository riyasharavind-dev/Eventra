import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imaging;
import 'package:image_picker/image_picker.dart';

const cropWine = Color(0xFF80152C);

/// Shared app-styled editor. It returns cropped JPEG or PNG bytes; upload stays with callers.
class EventorImageCropper {
  static Future<XFile?> crop(
    BuildContext context,
    XFile source, {
    required String title,
    double? aspectRatio,
    bool circle = false,
    bool allowRatios = false,
    int maxDimension = 1800,
    String outputName = 'cropped_photo.jpg',
    bool banner = false,
    bool preserveTransparency = false,
  }) async {
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw StateError('Unable to crop image.');
    final image = await decodeCropPhoto(bytes);
    if (!context.mounted) {
      image.dispose();
      return null;
    }
    try {
      final route = DialogRoute<Uint8List>(
        context: context,
        useSafeArea: false,
        barrierDismissible: false,
        builder: (_) => Dialog.fullscreen(
          child: EventorCropEditor(
            image: image,
            title: title,
            initialRatio: aspectRatio,
            circle: circle,
            allowRatios: allowRatios,
            maxDimension: maxDimension,
            banner: banner,
            preserveTransparency: preserveTransparency,
          ),
        ),
      );
      final result = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      // Keep the decoded photo alive during the closing route transition.
      await route.completed;
      if (result == null) return null;
      return XFile.fromData(
        result,
        name: outputName,
        mimeType: preserveTransparency ? 'image/png' : 'image/jpeg',
      );
    } finally {
      image.dispose();
    }
  }
}

Future<ui.Image> decodeCropPhoto(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final factor = math.min(
      1.0,
      2400 / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * factor).round()),
      targetHeight: math.max(1, (descriptor.height * factor).round()),
    );
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

void paintCropPhoto(Canvas canvas, ui.Image image, Size frame, int turns) {
  final odd = turns.isOdd;
  final width = odd ? image.height : image.width;
  final height = odd ? image.width : image.height;
  final scale = math.max(frame.width / width, frame.height / height);
  canvas.save();
  canvas.translate(frame.width / 2, frame.height / 2);
  canvas.rotate(turns * math.pi / 2);
  final destination = Rect.fromCenter(
    center: Offset.zero,
    width: image.width * scale,
    height: image.height * scale,
  );
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    destination,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
}

Uint8List _encodeCropJpeg(Map<String, Object> data) => Uint8List.fromList(
  imaging.encodeJpg(
    imaging.Image.fromBytes(
      width: data['width'] as int,
      height: data['height'] as int,
      bytes: (data['bytes'] as Uint8List).buffer,
      numChannels: 4,
    ),
    quality: 88,
  ),
);

/// Export uses the same painting and transform as the preview, without UI/grid.
Future<Uint8List> renderCropImage({
  required ui.Image image,
  required Size frame,
  required Matrix4 transform,
  required int turns,
  required int maxDimension,
  bool preserveTransparency = false,
}) async {
  final edge = math.min(maxDimension, math.max(image.width, image.height));
  final scale = edge / math.max(frame.width, frame.height);
  final width = math.max(1, (frame.width * scale).round());
  final height = math.max(1, (frame.height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (!preserveTransparency) canvas.drawColor(Colors.white, BlendMode.src);
  canvas.scale(width / frame.width, height / frame.height);
  canvas.clipRect(Offset.zero & frame);
  canvas.transform(transform.storage);
  paintCropPhoto(canvas, image, frame, turns);
  final picture = recorder.endRecording();
  ui.Image? output;
  try {
    output = await picture.toImage(width, height);
    final data = await output.toByteData(
      format: preserveTransparency
          ? ui.ImageByteFormat.png
          : ui.ImageByteFormat.rawRgba,
    );
    if (data == null) throw StateError('Unable to crop image.');
    if (preserveTransparency) {
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    return await compute(_encodeCropJpeg, <String, Object>{
      'width': width,
      'height': height,
      'bytes': data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    });
  } finally {
    output?.dispose();
    picture.dispose();
  }
}

class EventorCropEditor extends StatefulWidget {
  const EventorCropEditor({
    super.key,
    required this.image,
    required this.title,
    this.initialRatio,
    this.circle = false,
    this.allowRatios = false,
    this.maxDimension = 1800,
    this.banner = false,
    this.preserveTransparency = false,
  });
  final ui.Image image;
  final String title;
  final double? initialRatio;
  final bool circle, allowRatios, banner, preserveTransparency;
  final int maxDimension;
  @override
  State<EventorCropEditor> createState() => _EventorCropEditorState();
}

class _EventorCropEditorState extends State<EventorCropEditor> {
  final transform = TransformationController();
  late double? ratio = widget.initialRatio;
  int turns = 0;
  bool grid = false, saving = false;
  String? failure;
  Size frame = Size.zero;
  double get aspect =>
      ratio ??
      (turns.isOdd
          ? widget.image.height / widget.image.width
          : widget.image.width / widget.image.height);
  String get ratioLabel {
    if (ratio == null) return 'Original';
    if ((ratio! - 1).abs() < .001) return '1:1';
    if ((ratio! - 16 / 9).abs() < .001) return '16:9';
    if ((ratio! - 4 / 3).abs() < .001) return '4:3';
    if ((ratio! - 3 / 4).abs() < .001) return '3:4';
    return '${ratio!.toStringAsFixed(2)}:1';
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void reset({bool all = true}) {
    if (saving) return;
    setState(() {
      if (all) {
        turns = 0;
        ratio = widget.initialRatio;
      }
      transform.value = Matrix4.identity();
      failure = null;
    });
  }

  void rotate(int delta) {
    setState(() {
      turns = (turns + delta) % 4;
      transform.value = Matrix4.identity();
    });
  }

  void zoom(double value) {
    final old = transform.value;
    final scale = old.getMaxScaleOnAxis();
    final center = Offset(frame.width / 2, frame.height / 2);
    final x = center.dx - (center.dx - old.entry(0, 3)) / scale * value;
    final y = center.dy - (center.dy - old.entry(1, 3)) / scale * value;
    final photoWidth = (turns.isOdd ? widget.image.height : widget.image.width)
        .toDouble();
    final photoHeight = (turns.isOdd ? widget.image.width : widget.image.height)
        .toDouble();
    final fit = math.max(frame.width / photoWidth, frame.height / photoHeight);
    final marginX = math.max(0.0, (photoWidth * fit - frame.width) / 2);
    final marginY = math.max(0.0, (photoHeight * fit - frame.height) / 2);
    final safeX = x.clamp(
      frame.width - (frame.width + marginX) * value,
      marginX * value,
    );
    final safeY = y.clamp(
      frame.height - (frame.height + marginY) * value,
      marginY * value,
    );
    transform.value = Matrix4.identity()
      ..setEntry(0, 0, value)
      ..setEntry(1, 1, value)
      ..setEntry(0, 3, safeX)
      ..setEntry(1, 3, safeY);
  }

  Future<void> save() async {
    if (saving || frame.isEmpty) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      final bytes = await renderCropImage(
        image: widget.image,
        frame: frame,
        transform: transform.value.clone(),
        turns: turns,
        maxDimension: widget.maxDimension,
        preserveTransparency: widget.preserveTransparency,
      );
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          failure = 'Unable to crop image.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: saving ? null : () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Crop grid',
            isSelected: grid,
            selectedIcon: const Icon(Icons.grid_on, color: cropWine),
            icon: const Icon(Icons.grid_off),
            onPressed: saving ? null : () => setState(() => grid = !grid),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight * aspect,
                  );
                  frame = Size(width, width / aspect);
                  final odd = turns.isOdd;
                  final photoW =
                      (odd ? widget.image.height : widget.image.width)
                          .toDouble();
                  final photoH =
                      (odd ? widget.image.width : widget.image.height)
                          .toDouble();
                  final fit = math.max(
                    frame.width / photoW,
                    frame.height / photoH,
                  );
                  return Center(
                    child: SizedBox.fromSize(
                      size: frame,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController: transform,
                              panEnabled: !saving,
                              scaleEnabled: !saving,
                              minScale: 1,
                              maxScale: 4,
                              boundaryMargin: EdgeInsets.symmetric(
                                horizontal: math.max(
                                  0,
                                  (photoW * fit - frame.width) / 2,
                                ),
                                vertical: math.max(
                                  0,
                                  (photoH * fit - frame.height) / 2,
                                ),
                              ),
                              child: SizedBox.fromSize(
                                size: frame,
                                child: CustomPaint(
                                  painter: _CropPhotoPainter(
                                    widget.image,
                                    turns,
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _CropGuidePainter(
                                  circle: widget.circle,
                                  grid: grid,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .4,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  Text(
                    'Drag to position. Pinch or use the slider to zoom.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF73737D),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.allowRatios)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final option in <(String, double?)>[
                          ('Original', null),
                          ('1:1', 1),
                          ('4:3', 4 / 3),
                          ('3:4', 3 / 4),
                          ('16:9', 16 / 9),
                        ])
                          ChoiceChip(
                            label: Text(option.$1),
                            selected: ratio == option.$2,
                            selectedColor: const Color(0xFFF5E8EC),
                            labelStyle: const TextStyle(color: cropWine),
                            onSelected: saving
                                ? null
                                : (_) => setState(() {
                                    ratio = option.$2;
                                    transform.value = Matrix4.identity();
                                  }),
                          ),
                      ],
                    )
                  else
                    Text(
                      widget.circle ? '1:1' : ratioLabel,
                      style: const TextStyle(
                        color: cropWine,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Rotate left',
                        onPressed: saving ? null : () => rotate(-1),
                        icon: const Icon(Icons.rotate_left),
                      ),
                      IconButton(
                        tooltip: 'Rotate right',
                        onPressed: saving ? null : () => rotate(1),
                        icon: const Icon(Icons.rotate_right),
                      ),
                      TextButton.icon(
                        onPressed: saving ? null : reset,
                        icon: const Icon(Icons.restart_alt),
                        label: Text('Reset'),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<Matrix4>(
                    valueListenable: transform,
                    builder: (_, value, child) => Row(
                      children: [
                        const Icon(Icons.zoom_out, size: 20),
                        Expanded(
                          child: Slider(
                            value: value.getMaxScaleOnAxis().clamp(1.0, 4.0),
                            min: 1,
                            max: 4,
                            activeColor: cropWine,
                            semanticFormatterCallback: (v) =>
                                '${v.toStringAsFixed(1)}x',
                            label: 'Zoom',
                            onChanged: saving ? null : zoom,
                          ),
                        ),
                        const Icon(Icons.zoom_in, size: 20),
                      ],
                    ),
                  ),
                  if (failure != null)
                    Text(
                      failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: saving ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: cropWine,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white),
            label: Text(
              saving
                  ? 'Preparing image...'
                  : widget.banner
                  ? 'Use banner'
                  : 'Use image',
            ),
          ),
        ),
      ),
    ),
  );
}

class _CropPhotoPainter extends CustomPainter {
  final ui.Image image;
  final int turns;
  _CropPhotoPainter(this.image, this.turns);
  @override
  void paint(Canvas canvas, Size size) =>
      paintCropPhoto(canvas, image, size, turns);
  @override
  bool shouldRepaint(_CropPhotoPainter old) =>
      old.image != image || old.turns != turns;
}

class _CropGuidePainter extends CustomPainter {
  final bool circle, grid;
  _CropGuidePainter({required this.circle, required this.grid});
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    if (circle) {
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds)
        ..addOval(bounds.deflate(1));
      canvas.drawPath(
        outside,
        Paint()..color = Colors.black.withValues(alpha: .45),
      );
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (circle) {
      canvas.drawOval(bounds.deflate(1), line);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.deflate(1), const Radius.circular(15)),
        line,
      );
    }
    if (grid) {
      for (var i = 1; i < 3; i++) {
        canvas.drawLine(
          Offset(size.width * i / 3, 0),
          Offset(size.width * i / 3, size.height),
          line..strokeWidth = .5,
        );
        canvas.drawLine(
          Offset(0, size.height * i / 3),
          Offset(size.width, size.height * i / 3),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CropGuidePainter old) =>
      old.circle != circle || old.grid != grid;
}
