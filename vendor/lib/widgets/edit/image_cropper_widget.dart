import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../common/eventor_image_cropper.dart';

class ImageCropperWidget {
  ImageCropperWidget._();
  static Future<File?> crop({
    required BuildContext context,
    required File image,
    double ratioX = 16,
    double ratioY = 9,
    String title = 'Crop Image',
  }) async {
    if (!await image.exists() || !context.mounted) return null;
    final cropped = await EventorImageCropper.crop(
      context,
      XFile(image.path),
      title: title,
      aspectRatio: ratioX / ratioY,
      maxDimension: 1800,
    );
    if (cropped == null) return null;
    final temp = await getTemporaryDirectory();
    return File(
      '${temp.path}/eventor_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
    ).writeAsBytes(await cropped.readAsBytes(), flush: true);
  }
}
