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
  String? _error;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.booking.review?.text ?? '');
    _rating = widget.booking.review?.rating ?? 0;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
      await widget.repository.submit(
        bookingId: widget.booking.bookingId,
        rating: _rating,
        text: _text.text,
        expectedVersion: widget.booking.review?.version ?? 0,
      );
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
      title: Text(
        widget.booking.review == null ? 'Write a review' : 'Edit review',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.booking.serviceName),
            Wrap(
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    tooltip: '$star stars',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _rating = star),
                    icon: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFF80152C),
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _text,
              enabled: !_saving,
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Your experience',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save review'),
        ),
      ],
    ),
  );
}
