import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the crop editor without uploading or changing the current photo.
/// Cancellation returns null, so callers can leave the existing DP untouched.
class ProfileImageCropper {
  const ProfileImageCropper._();

  static Future<XFile?> crop(BuildContext context, XFile image) =>
      _crop(context, image, banner: false);

  static Future<XFile?> cropBanner(BuildContext context, XFile image) =>
      _crop(context, image, banner: true);

  static Future<XFile?> cropLogo(BuildContext context, XFile image) =>
      _crop(context, image, banner: false, logo: true);

  static Future<XFile?> cropService(BuildContext context, XFile image) =>
      _crop(context, image, banner: false, service: true);

  static Future<XFile?> _crop(
    BuildContext context,
    XFile image, {
    required bool banner,
    bool service = false,
    bool logo = false,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: CropAspectRatio(
        ratioX: service ? 4 : (banner ? 16 : 1),
        ratioY: service ? 3 : (banner ? 9 : 1),
      ),
      maxWidth: service ? 1800 : (banner ? 1600 : 1024),
      maxHeight: service ? 1350 : (banner ? 900 : 1024),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: logo
              ? 'Crop business logo'
              : service
              ? 'Crop service photo'
              : (banner ? 'Crop banner' : 'Crop profile photo'),
          toolbarColor: const Color(0xFF80152C),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF80152C),
          lockAspectRatio: true,
          cropStyle: banner || service || logo
              ? CropStyle.rectangle
              : CropStyle.circle,
          showCropGrid: false,
        ),
        IOSUiSettings(
          title: logo
              ? 'Crop business logo'
              : service
              ? 'Crop service photo'
              : (banner ? 'Crop banner' : 'Crop profile photo'),
          doneButtonTitle: banner ? 'Use banner' : 'Use photo',
          cancelButtonTitle: 'Cancel',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          cropStyle: banner || service || logo
              ? CropStyle.rectangle
              : CropStyle.circle,
        ),
        WebUiSettings(context: context, presentStyle: WebPresentStyle.page),
      ],
    );
    if (cropped == null) return null;
    final bytes = await cropped.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Unable to crop this photo. Try another image.');
    }
    return XFile.fromData(
      bytes,
      name: logo
          ? 'business_logo.jpg'
          : service
          ? 'service_photo.jpg'
          : (banner ? 'profile_banner.jpg' : 'profile_photo.jpg'),
      mimeType: 'image/jpeg',
    );
  }
}
