import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/support_repository.dart';

const _supportRed = Color(0xFF80152C);
const _supportBackground = Color(0xFFF8F8FA);
void _supportError(BuildContext context, Object error) {
  debugPrint('Support request failed: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppSettingsScope.translate(
          context,
          "customer.unable_to_send_your_request_check_your_connec.d8d1e38b",
        ),
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
            SnackBar(
              content: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.choose_a_jpg_png_or_webp_image_smaller_than_5.d78916c2",
                ),
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
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "customer.request_value0_submitted.6dbad8ac",
              args: {"value0": ticket.reference},
            ),
          ),
        ),
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
      appBar: AppBar(
        title: Text(
          AppSettingsScope.translate(
            context,
            "customer.contact_support.f8d47b82",
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              AppSettingsScope.translate(
                context,
                "customer.tell_us_what_happened.70ca7e3a",
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.a_few_details_will_help_our_team_understand_t.357d1cf1",
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF73737D),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.category.292c06f0",
                ),
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
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.subject.68971283",
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? AppSettingsScope.translate(
                      context,
                      "customer.enter_a_subject_with_at_least_3_characters.da3cf6a9",
                    )
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
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.description.526e0087",
                ),
                alignLabelWithHint: true,
                hintText: AppSettingsScope.translate(
                  context,
                  "customer.what_happened_what_did_you_expect_include_the.adac6381",
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? AppSettingsScope.translate(
                      context,
                      "customer.describe_the_issue_in_at_least_10_characters.2a2368f5",
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _supportRed,
                side: const BorderSide(color: Color(0xFFF0EDF0)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: _saving ? null : _pick,
              icon: const Icon(Icons.attach_file, color: Color(0xFF73737D)),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.attach_screenshot_optional.c47333b2",
                ),
              ),
            ),
            if (_screenshot != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E8EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.image_outlined, size: 18, color: _supportRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _screenshot!.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.private_attachment_max_5_mb.56cb78cc",
                            ),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF73737D)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppSettingsScope.translate(
                        context,
                        "customer.remove_screenshot.ed14fa72",
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _screenshot = null),
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF73737D)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.never_share_passwords_pins_full_card_numbers_.48ea9cf9",
              ),
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF73737D),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _supportRed,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
