import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imaging;
import 'package:eventor_vendor/widgets/common/eventor_image_cropper.dart';

Future<ui.Image> sample() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 100, 100),
    Paint()..color = Colors.red,
  );
  canvas.drawRect(
    const Rect.fromLTWH(100, 0, 100, 100),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 100);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'JPEG export matches preview crop and rotation, without editor overlays',
    () async {
      final image = await sample();
      final bytes = await renderCropJpeg(
        image: image,
        frame: const Size(100, 100),
        transform: Matrix4.identity(),
        turns: 0,
        maxDimension: 100,
      );
      expect(bytes.take(3), [255, 216, 255]);
      final decoded = imaging.decodeJpg(bytes)!;
      expect(decoded.width, 100);
      expect(decoded.height, 100);
      expect(decoded.getPixel(10, 50).r, greaterThan(200));
      expect(decoded.getPixel(90, 50).b, greaterThan(200));
      final rotated = imaging.decodeJpg(
        await renderCropJpeg(
          image: image,
          frame: const Size(100, 200),
          transform: Matrix4.identity(),
          turns: 1,
          maxDimension: 200,
        ),
      )!;
      expect(rotated.width, 100);
      expect(rotated.height, 200);
      expect(rotated.getPixel(50, 10).r, greaterThan(200));
      expect(rotated.getPixel(50, 190).b, greaterThan(200));
      final zoomed = imaging.decodeJpg(
        await renderCropJpeg(
          image: image,
          frame: const Size(100, 100),
          transform: Matrix4.identity()
            ..setEntry(0, 0, 2)
            ..setEntry(1, 1, 2),
          turns: 0,
          maxDimension: 100,
        ),
      )!;
      expect(zoomed.getPixel(80, 50).r, greaterThan(200));
      image.dispose();
    },
  );
  testWidgets(
    'editor fits narrow/landscape layouts and controls ratios, rotation, zoom and reset',
    (tester) async {
      final image = await sample();
      for (final size in [const Size(320, 640), const Size(700, 360)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(1.4),
              ),
              child: EventorCropEditor(
                image: image,
                title: 'Crop service photo',
                allowRatios: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Original'), findsOneWidget);
        await tester.tap(find.text('3:4'));
        await tester.pumpAndSettle();
        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
        await tester.pump();
        expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);
        await tester.ensureVisible(find.byTooltip('Rotate right'));
        await tester.tap(find.byTooltip('Rotate right'));
        await tester.pumpAndSettle();
        expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(
                find.ancestor(
                  of: find.text('Original'),
                  matching: find.byType(ChoiceChip),
                ),
              )
              .selected,
          true,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      image.dispose();
    },
  );
  testWidgets('cancelling editor returns no replacement photo', (tester) async {
    final image = await sample();
    Object? result = 'not returned';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog(
                  context: context,
                  builder: (_) => Dialog.fullscreen(
                    child: EventorCropEditor(
                      image: image,
                      title: 'Crop profile photo',
                      circle: true,
                      initialRatio: 1,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    image.dispose();
  });
}
