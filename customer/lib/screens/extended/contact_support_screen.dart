import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/support_repository.dart';

const _supportRed = Color(0xFF80152C);
const _supportBackground = Color(0xFFF8F8FA);
void _supportError(BuildContext context, Object error) {
  debugPrint('Support request failed: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Unable to send your request. Check your connection and try again.',
      ),
    ),
  );
}

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key, this.repository});
  final SupportRepository? repository;
  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  late final String _requestId;
  late final SupportRepository _repository;
  String _category = SupportRepository.categories.first;
  XFile? _screenshot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupportRepository();
    _requestId = _repository.newRequestId();
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final extension = file.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension) ||
          await file.length() > 5242880) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Choose a JPG, PNG or WebP image smaller than 5 MB.',
              ),
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _screenshot = file);
    } catch (error) {
      if (mounted) _supportError(context, error);
    }
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ticket = await _repository.createTicket(
        requestId: _requestId,
        category: _category,
        subject: _subject.text,
        description: _description.text,
        screenshot: _screenshot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${ticket.reference} submitted.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _supportError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: _supportBackground,
      appBar: AppBar(title: const Text('Contact Support')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tell us what happened',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'A few details will help our team understand the issue.',
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: SupportRepository.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('support-subject'),
              controller: _subject,
              enabled: !_saving,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter a subject with at least 3 characters.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('support-description'),
              controller: _description,
              enabled: !_saving,
              maxLength: 2000,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                hintText: 'What happened? What did you expect? Include the steps to reproduce it.',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Describe the issue in at least 10 characters.'
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pick,
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach screenshot (optional)'),
            ),
            if (_screenshot != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_screenshot!.name, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Private attachment · Max 5 MB'),
                trailing: IconButton(
                  tooltip: 'Remove screenshot',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _screenshot = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            const SizedBox(height: 14),
            const Text(
              'Never share passwords, PINs, full card numbers or unrelated personal documents.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF6F6F7A),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _supportRed,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_saving ? 'Submitting…' : 'Submit request'),
            ),
          ],
        ),
      ),
    ),
  );
}
