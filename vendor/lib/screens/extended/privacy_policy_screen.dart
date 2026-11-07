import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

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

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const _red = Color(0xFF9F0101);
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
      _loading = true;
      _failed = false;
    });
    try {
      final document = await _repository.getVendorPrivacyPolicy(
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _document = document;
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('Unable to load vendor privacy policy: $error');
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
              error ? 'Check your connection and try again.' : 'The latest vendor privacy policy will appear here once published.',
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
    return VendorPageScaffold(
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
            ? const Center(
                child: AppContentSkeleton(layout: SkeletonLayout.document),
              )
            : _failed
            ? _message(error: true)
            : document == null
            ? _message(error: false)
            : AppShimmerRefreshIndicator(
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
                            'EVENTOR VENDOR',
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
                            child: _LegalContent(
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

// Dependency-free basic Markdown: #/##/### headings, paragraphs, -/* bullets,
// and **bold**. HTML, links, images and tables are not interpreted.
class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.text});

  final String text;

  List<InlineSpan> _inline(String text) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in RegExp(r'\*\*(.+?)\*\*').allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final paragraph = <String>[];

    void addText(String value, {int heading = 0, bool bullet = false}) {
      final style = TextStyle(
        fontSize: heading == 0
            ? 15
            : heading == 1
            ? 23
            : 18,
        height: 1.65,
        color: const Color(0xFF25252B),
        fontWeight: heading == 0 ? FontWeight.w400 : FontWeight.w700,
      );
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 12, top: heading == 0 ? 0 : 8),
          child: SelectableText.rich(
            TextSpan(
              children: [
                if (bullet) const TextSpan(text: '• '),
                ..._inline(value),
              ],
            ),
            style: style,
          ),
        ),
      );
    }

    void flush() {
      if (paragraph.isEmpty) return;
      addText(paragraph.join(' '));
      paragraph.clear();
    }

    for (final line in text.replaceAll('\r\n', '\n').split('\n')) {
      final value = line.trim();
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(value);
      final bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(value);
      if (value.isEmpty) {
        flush();
      } else if (heading != null) {
        flush();
        addText(heading.group(2)!, heading: heading.group(1)!.length);
      } else if (bullet != null) {
        flush();
        addText(bullet.group(1)!, bullet: true);
      } else {
        paragraph.add(value);
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
