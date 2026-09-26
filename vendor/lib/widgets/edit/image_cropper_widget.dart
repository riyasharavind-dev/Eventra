import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageCropperWidget {
  ImageCropperWidget._();

  static Future<File?> crop({
    required File image,
    double ratioX = 16,
    double ratioY = 9,
    String title = 'Crop Image',
  }) async {
    try {
      debugPrint(
        'CROPPER: Starting crop',
      );

      debugPrint(
        'CROPPER: Source = ${image.path}',
      );

      if (!await image.exists()) {
        debugPrint(
          'CROPPER: Source file does not exist',
        );

        return null;
      }

      final CroppedFile? result =
          await ImageCropper().cropImage(
        sourcePath: image.path,

        aspectRatio:
            CropAspectRatio(
          ratioX: ratioX,
          ratioY: ratioY,
        ),

        compressFormat:
            ImageCompressFormat.jpg,

        compressQuality: 90,

        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: Colors.white,
            toolbarWidgetColor: Colors.black,
            backgroundColor: Colors.black,

            lockAspectRatio: true,

            showCropGrid: true,
          ),

          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      debugPrint(
        'CROPPER: Result = $result',
      );

      if (result == null) {
        debugPrint(
          'CROPPER: User cancelled',
        );

        return null;
      }

      final File croppedFile =
          File(result.path);

      if (!await croppedFile.exists()) {
        debugPrint(
          'CROPPER: Output file does not exist',
        );

        return null;
      }

      debugPrint(
        'CROPPER: Crop successful',
      );

      debugPrint(
        'CROPPER: Output = ${croppedFile.path}',
      );

      return croppedFile;
    } catch (e, stackTrace) {
      debugPrint(
        'CROPPER ERROR: $e',
      );

      debugPrint(
        'CROPPER STACKTRACE: $stackTrace',
      );

      return null;
    }
  }
}