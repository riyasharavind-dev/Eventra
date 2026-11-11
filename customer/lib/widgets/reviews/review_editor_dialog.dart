import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';

class ReviewEditorDialog extends StatefulWidget {
  const ReviewEditorDialog({
    super.key,
    required this.booking,
    required this.repository,
  });
  final BookingReviewContext booking;
  final ReviewRepository repository;
  @override
  State<ReviewEditorDialog> createState() => _ReviewEditorDialogState();
}

class _ReviewEditorDialogState extends State<ReviewEditorDialog> {
  late final TextEditingController _text;
  late int _rating;
  bool _saving = false;
  late List<String> paths;
  final newPhotos = <XFile>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.booking.review?.text ?? '');
    _rating = widget.booking.review?.rating ?? 0;
    paths = [...?widget.booking.review?.photoPaths];
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final chosen = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (!mounted) return;
      final capacity = 5 - paths.length - newPhotos.length;
      setState(() {
        newPhotos.addAll(chosen.take(capacity));
        if (chosen.length > capacity) {
          _error = 'Maximum 5 photos per review.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to select photos. Please try again.');
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_rating < 1) {
      setState(() => _error = 'Choose a star rating.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (paths.isEmpty &&
          newPhotos.isEmpty &&
          (widget.booking.review?.photoPaths.isEmpty ?? true)) {
        await widget.repository.submit(
          bookingId: widget.booking.bookingId,
          rating: _rating,
          text: _text.text,
          expectedVersion: widget.booking.review?.version ?? 0,
        );
      } else {
        await widget.repository.submitWithPhotos(
          bookingId: widget.booking.bookingId,
          rating: _rating,
          text: _text.text,
          expectedVersion: widget.booking.review?.version ?? 0,
          existingPaths: paths,
          newPhotos: newPhotos,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save. Refresh and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        widget.booking.review == null ? 'Write a review' : 'Edit review',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF17171B),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.booking.serviceName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF73737D),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: AppSettingsScope.translate(
                        context,
                        "customer.value0_stars.0dc50f1e",
                        args: {"value0": star},
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _rating = star),
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 32,
                        color: star <= _rating
                            ? const Color(0xFFFFCB48)
                            : const Color(0xFFD6D6DC),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              enabled: !_saving,
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.your_experience.52aae266",
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            if (paths.isNotEmpty || newPhotos.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < paths.length; i++)
                    Chip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: const Color(0xFFF5E8EC),
                      side: const BorderSide(color: Color(0xFFF0EDF0)),
                      label: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.photo_value0.95bf9db9",
                          args: {"value0": i + 1},
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF80152C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      avatar: const Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: Color(0xFF80152C),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => paths.removeAt(i)),
                    ),
                  for (var i = 0; i < newPhotos.length; i++)
                    Chip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: const Color(0xFFF5E8EC),
                      side: const BorderSide(color: Color(0xFFF0EDF0)),
                      label: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.new_photo_value0.964068c6",
                          args: {"value0": i + 1},
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF80152C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => newPhotos.removeAt(i)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF80152C),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _saving || paths.length + newPhotos.length >= 5
                  ? null
                  : _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.add_service_photos_value0_5.cf40b400",
                  args: {"value0": paths.length + newPhotos.length},
                ),
              ),
            ),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.upload_photos_from_your_experience_jpg_png_or.c46e1879",
              ),
              style: const TextStyle(fontSize: 11, color: Color(0xFF73737D)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF73737D),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(
            AppSettingsScope.translate(context, "customer.cancel.19766ed6"),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF80152C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save review'),
        ),
      ],
    ),
  );
}
