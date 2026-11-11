import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_settings_controller.dart';
import 'common/eventor_image_cropper.dart';

class ProfileImageCropper {
  const ProfileImageCropper._();
  static Future<XFile?> crop(BuildContext context, XFile image) =>
      EventorImageCropper.crop(
        context,
        image,
        title: AppSettingsScope.source(context, 'Crop profile photo'),
        aspectRatio: 1,
        circle: true,
        maxDimension: 1024,
        outputName: 'profile_photo.jpg',
      );
  static Future<XFile?> cropLogo(BuildContext context, XFile image) =>
      EventorImageCropper.crop(
        context,
        image,
        title: AppSettingsScope.source(context, 'Crop business logo'),
        aspectRatio: 1,
        maxDimension: 1024,
        outputName: 'business_logo.jpg',
      );
  static Future<XFile?> cropBanner(BuildContext context, XFile image) =>
      EventorImageCropper.crop(
        context,
        image,
        title: AppSettingsScope.source(context, 'Crop banner'),
        aspectRatio: 16 / 9,
        maxDimension: 1600,
        outputName: 'business_banner.jpg',
        banner: true,
      );
  static Future<XFile?> cropService(BuildContext context, XFile image) =>
      EventorImageCropper.crop(
        context,
        image,
        title: AppSettingsScope.source(context, 'Crop service photo'),
        allowRatios: true,
        maxDimension: 1800,
        outputName: 'service_photo.jpg',
      );
}
