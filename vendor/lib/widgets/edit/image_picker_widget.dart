import '../common/app_shimmer.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_cropper_widget.dart';

class ImagePickerWidget extends StatefulWidget {
  final List<XFile> images;
  final ValueChanged<List<XFile>> onChanged;

  final int maxImages;

  final double cropRatioX;
  final double cropRatioY;

  final String cropTitle;

  const ImagePickerWidget({
    super.key,
    required this.images,
    required this.onChanged,
    this.maxImages = 8,
    this.cropRatioX = 16,
    this.cropRatioY = 9,
    this.cropTitle = 'Crop Image',
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();

  bool _isPicking = false;

  // ============================================================
  // PICK IMAGES
  // ============================================================

  Future<void> _pickImages() async {
    if (_isPicking) {
      return;
    }

    final int remaining = widget.maxImages - widget.images.length;

    if (remaining <= 0) {
      _showMessage('Maximum ${widget.maxImages} images allowed.');
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      // --------------------------------------------------------
      // OPEN GALLERY
      // --------------------------------------------------------

      final List<XFile> picked = await _picker.pickMultiImage(imageQuality: 90);

      if (!mounted) {
        return;
      }

      if (picked.isEmpty) {
        setState(() {
          _isPicking = false;
        });
        return;
      }

      final List<XFile> selected = picked.take(remaining).toList();

      final List<XFile> croppedImages = List<XFile>.from(widget.images);

      // --------------------------------------------------------
      // PROCESS ONE IMAGE AT A TIME
      // --------------------------------------------------------

      for (int i = 0; i < selected.length; i++) {
        if (!mounted) {
          return;
        }

        final XFile selectedImage = selected[i];

        final File originalFile = File(selectedImage.path);

        // ------------------------------------------------------
        // CHECK FILE
        // ------------------------------------------------------

        if (!await originalFile.exists()) {
          _showMessage('Selected image could not be accessed.');
          continue;
        }

        // ------------------------------------------------------
        // OPEN CROPPER
        // ------------------------------------------------------

        final File? croppedFile = await ImageCropperWidget.crop(
          image: originalFile,
          ratioX: widget.cropRatioX,
          ratioY: widget.cropRatioY,
          title: '${widget.cropTitle} ${i + 1}/${selected.length}',
        );

        if (!mounted) {
          return;
        }

        // User cancelled crop
        if (croppedFile == null) {
          continue;
        }

        // ------------------------------------------------------
        // CHECK CROPPED FILE
        // ------------------------------------------------------

        if (!await croppedFile.exists()) {
          _showMessage('Cropped image could not be created.');
          continue;
        }

        // ------------------------------------------------------
        // ADD CROPPED IMAGE
        // ------------------------------------------------------

        croppedImages.add(XFile(croppedFile.path));

        widget.onChanged(List<XFile>.from(croppedImages));

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, stackTrace) {
      debugPrint('IMAGE PICKER ERROR: $e');

      debugPrint('IMAGE PICKER STACKTRACE: $stackTrace');

      if (mounted) {
        _showMessage('Unable to process image.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  // ============================================================
  // RE-CROP
  // ============================================================

  Future<void> _recropImage(int index) async {
    if (_isPicking) {
      return;
    }

    if (index < 0 || index >= widget.images.length) {
      return;
    }

    final XFile current = widget.images[index];

    final File file = File(current.path);

    if (!await file.exists()) {
      _showMessage('Image file no longer exists.');
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final File? cropped = await ImageCropperWidget.crop(
        image: file,
        ratioX: widget.cropRatioX,
        ratioY: widget.cropRatioY,
        title: 'Adjust Image',
      );

      if (!mounted) {
        return;
      }

      if (cropped == null) {
        return;
      }

      if (!await cropped.exists()) {
        _showMessage('Cropped image could not be created.');
        return;
      }

      final List<XFile> updated = List<XFile>.from(widget.images);

      updated[index] = XFile(cropped.path);

      widget.onChanged(updated);

      setState(() {});
    } catch (e, stackTrace) {
      debugPrint('RECROP ERROR: $e');

      debugPrint('RECROP STACKTRACE: $stackTrace');

      if (mounted) {
        _showMessage('Unable to crop image.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  void _deleteImage(int index) {
    if (index < 0 || index >= widget.images.length) {
      return;
    }

    final List<XFile> updated = List<XFile>.from(widget.images);

    updated.removeAt(index);

    widget.onChanged(updated);

    setState(() {});
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ======================================================
        // PICK BUTTON
        // ======================================================

        InkWell(
          onTap: _isPicking ? null : _pickImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.grey.shade50,
            ),
            child: Column(
              children: [
                if (_isPicking)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: AppShimmerIndicator(strokeWidth: 2.5),
                  )
                else
                  const Icon(Icons.add_photo_alternate_outlined, size: 34),

                const SizedBox(height: 8),

                Text(
                  _isPicking ? 'Processing image...' : 'Select Images',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 4),

                Text(
                  'Images will be cropped to 16:9',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),

        // ======================================================
        // SELECTED IMAGES
        // ======================================================
        if (widget.images.isNotEmpty) ...[
          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Selected Images',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),

              Text(
                '${widget.images.length}/${widget.maxImages}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),

          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 16 / 9,
            ),
            itemBuilder: (BuildContext context, int index) {
              return _buildImageCard(widget.images[index], index);
            },
          ),

          const SizedBox(height: 10),

          if (widget.images.length < widget.maxImages)
            OutlinedButton.icon(
              onPressed: _isPicking ? null : _pickImages,
              icon: const Icon(Icons.add),
              label: const Text('Add More Images'),
            ),
        ],
      ],
    );
  }

  // ============================================================
  // IMAGE CARD
  // ============================================================

  Widget _buildImageCard(XFile image, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(image.path),
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                },
          ),
        ),

        // ------------------------------------------------------
        // BOTTOM ACTION BAR
        // ------------------------------------------------------
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Image ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                _imageActionButton(
                  icon: Icons.crop,
                  tooltip: 'Crop again',
                  onTap: _isPicking
                      ? null
                      : () {
                          _recropImage(index);
                        },
                ),

                const SizedBox(width: 6),

                _imageActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Remove',
                  onTap: _isPicking
                      ? null
                      : () {
                          _deleteImage(index);
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _imageActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
