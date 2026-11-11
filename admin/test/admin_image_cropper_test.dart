import 'dart:ui' as ui;

import 'package:eventor_admin/widgets/eventor_image_cropper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imaging;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Category icons preserve alpha and banners export at 16:9', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(50, 20, 100, 60),
      Paint()..color = Colors.red,
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(200, 100);
    addTearDown(source.dispose);
    addTearDown(picture.dispose);

    final icon = imaging.decodePng(
      await renderCropImage(
        image: source,
        frame: const Size(100, 100),
        transform: Matrix4.identity(),
        turns: 0,
        maxDimension: 100,
        preserveTransparency: true,
      ),
    )!;
    expect((icon.width, icon.height), (100, 100));
    expect(icon.getPixel(50, 0).a, 0);
    expect(icon.getPixel(50, 50).a, 255);

    final banner = imaging.decodeJpg(
      await renderCropImage(
        image: source,
        frame: const Size(160, 90),
        transform: Matrix4.identity(),
        turns: 0,
        maxDimension: 160,
      ),
    )!;
    expect((banner.width, banner.height), (160, 90));
  });
}
