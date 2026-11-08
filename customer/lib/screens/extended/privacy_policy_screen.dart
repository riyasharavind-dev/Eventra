import '../../services/app_live_data.dart';
import '../../widgets/legal/legal_document_content.dart';

import 'package:flutter/material.dart';

import '../../models/legal_document_model.dart';
import '../../repositories/legal_document_repository.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({
    super.key,
    this.languageCode = 'en',
    this.repository,
  });

  final String languageCode;
  final LegalDocumentRepository? repository;

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with LiveDataState<PrivacyPolicyScreen> {
  @override
  Set<String> get liveDatasets => {'public:legal_documents'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

  static const _red = Color(0xFF80152C);
  late final LegalDocumentRepository _repository;
  LegalDocumentModel? _document;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LegalDocumentRepository();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      if (!liveRefreshing) _loading = true;
      _failed = false;
    });
    try {
      final document = await _repository.getCustomerPrivacyPolicy(
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _document = document;
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('Unable to load customer privacy policy: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  String _date(DateTime date) {
    // Legal dates use UTC, matching the timestamps stored in the database.
    final utc = date.toUtc();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${utc.day} ${months[utc.month - 1]} ${utc.year}';
  }

  Widget _message({required bool error}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? Icons.cloud_off_outlined : Icons.description_outlined,
              color: _red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              error
                  ? 'Unable to load privacy policy'
                  : 'Privacy policy is not available yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error ? 'Check your connection and try again.' : 'The latest customer privacy policy will appear here once published.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6F6F7A), height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(error ? 'Retry' : 'Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh privacy policy',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _red))
            : _failed
            ? _message(error: true)
            : document == null
            ? _message(error: false)
            : RefreshIndicator(
                color: _red,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'EVENTOR CUSTOMER',
                            style: TextStyle(
                              color: _red,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            document.title,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Version ${document.version}'
                            ' · ${document.languageCode.toUpperCase()}\n'
                            'Last published: ${_date(document.publishedAt)} (UTC)\n'
                            'Effective: ${_date(document.effectiveAt)} (UTC)',
                            style: const TextStyle(
                              color: Color(0xFF6F6F7A),
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFECECEC),
                              ),
                            ),
                            child: LegalDocumentContent(
                              text: document.contentMarkdown,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
