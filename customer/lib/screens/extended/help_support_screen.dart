import 'package:flutter/material.dart';

import 'contact_support_screen.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../models/support_model.dart';
import '../../repositories/support_repository.dart';

import '../../widgets/support/support_ui.dart';
import '../../widgets/support/support_ticket_tile.dart';
import 'support_requests_screen.dart';
import 'support_request_detail_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, this.repository});
  final SupportRepository? repository;
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  late final SupportRepository _repository;
  List<SupportFaq> _faqs = [];
  List<SupportTicket> _tickets = [];
  SupportSettings _settings = const SupportSettings();
  String _search = '';
  String _category = 'All';
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupportRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait<Object>([
        _repository.getFaqs(),
        _repository.getSettings(),
        _repository.getTickets(),
      ]);
      if (!mounted) return;
      setState(() {
        _faqs = results[0] as List<SupportFaq>;
        if (_category != 'All' &&
            !_faqs.any((faq) => faq.category == _category)) {
          _category = 'All';
        }
        _settings = results[1] as SupportSettings;
        _tickets = results[2] as List<SupportTicket>;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Support load failed: $error');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  Future<void> _contact(bool email) async {
    final value = email ? _settings.email : _settings.whatsappNumber;
    if (value == null || value.trim().isEmpty) return;
    final uri = email
        ? Uri(
            scheme: 'mailto',
            path: value,
            queryParameters: {'subject': 'Eventor Customer Support'},
          )
        : Uri.https('wa.me', '/$value');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No app available');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open ${email ? 'email' : 'WhatsApp'}. Please submit a support request instead.',
            ),
          ),
        );
      }
    }
  }

  Widget _section(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _contactCard(bool email) {
    final value = email ? _settings.email : _settings.whatsappNumber;
    final enabled = value != null && value.trim().isNotEmpty;
    final detail = email ? _settings.responseTime : _settings.businessHours;
    return Expanded(
      child: supportPanel(
        InkWell(
          onTap: enabled ? () => _contact(email) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  email ? Icons.mail_outline : Icons.chat_bubble_outline,
                  color: supportWine,
                ),
                const SizedBox(height: 12),
                Text(
                  email ? 'Email support' : 'WhatsApp support',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  enabled
                      ? (detail?.trim().isNotEmpty == true
                            ? detail!
                            : 'Contact the support team')
                      : 'Not configured yet',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF6F6F7A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ..._faqs.map((f) => f.category).toSet()];
    final filtered = _faqs
        .where(
          (faq) =>
              (_category == 'All' || faq.category == _category) &&
              '${faq.question} ${faq.answer} ${faq.category}'
                  .toLowerCase()
                  .contains(_search.toLowerCase().trim()),
        )
        .toList();
    return Scaffold(
      backgroundColor: supportBackground,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh support',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: supportWine))
          : _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load support. Check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'EVENTOR CUSTOMER SUPPORT',
                    style: TextStyle(
                      color: supportWine,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'How can we help?',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find an answer or reach out to our team.',
                    style: TextStyle(color: Color(0xFF6F6F7A)),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: 'Search questions or topics…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  _section('Frequently asked questions'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: categories
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: _category == category,
                            selectedColor: const Color(0xFFFBEAEA),
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  supportPanel(
                    filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No matching questions. Try another search or report an issue.',
                            ),
                          )
                        : Column(
                            children: filtered
                                .map(
                                  (faq) => ExpansionTile(
                                    key: ValueKey(
                                      '${faq.category}:${faq.question}',
                                    ),
                                    title: Text(
                                      faq.question,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    childrenPadding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      18,
                                    ),
                                    expandedCrossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          faq.answer,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.6,
                                            color: Color(0xFF6F6F7A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  _section('Need a little more help?'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _contactCard(true),
                      const SizedBox(width: 10),
                      _contactCard(false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xFFFBEAEA),
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      leading: const Icon(
                        Icons.help_outline,
                        color: supportWine,
                      ),
                      title: const Text(
                        'Report an issue',
                        style: TextStyle(
                          color: supportWine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Tell us what went wrong'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _open(ContactSupportScreen(repository: _repository)),
                    ),
                  ),
                  _section(
                    'My support requests',
                    action: TextButton(
                      onPressed: () =>
                          _open(SupportRequestsScreen(repository: _repository)),
                      child: const Text('View all'),
                    ),
                  ),
                  supportPanel(
                    _tickets.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No support requests yet. Your requests will appear here.',
                            ),
                          )
                        : Column(
                            children: _tickets
                                .take(2)
                                .map(
                                  (ticket) => SupportTicketTile(
                                    ticket: ticket,
                                    onTap: () => _open(
                                      SupportRequestDetailScreen(
                                        ticket: ticket,
                                        repository: _repository,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
