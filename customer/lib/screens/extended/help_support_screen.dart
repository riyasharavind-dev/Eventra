import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';

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

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with LiveDataState<HelpSupportScreen> {
  @override
  Set<String> get liveDatasets => {
    'public:support_faqs',
    'public:support_settings',
    'own:support_tickets',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

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
      if (!liveRefreshing) _loading = true;
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
              AppSettingsScope.translate(
                context,
                "customer.unable_to_open_value0_please_submit_a_support.03be8957",
                args: {"value0": email ? 'email' : 'WhatsApp'},
              ),
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8EC),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    email ? Icons.mail_outline : Icons.chat_bubble_outline,
                    color: supportWine,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  email ? 'Email support' : 'WhatsApp support',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17171B),
                  ),
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
                    color: Color(0xFF73737D),
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
        title: Text(
          AppSettingsScope.translate(context, "customer.help_support.1f8ecc24"),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: AppSettingsScope.translate(
              context,
              "customer.refresh_support.74fe6d06",
            ),
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
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.unable_to_load_support_check_your_connection_.15ccd2b3",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.retry.942087cc",
                        ),
                      ),
                    ),
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
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.eventor_customer_support.f34f7c16",
                    ),
                    style: TextStyle(
                      color: supportWine,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.how_can_we_help.7b56e0d0",
                    ),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.find_an_answer_or_reach_out_to_our_team.8d7018c7",
                    ),
                    style: TextStyle(color: Color(0xFF6F6F7A)),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: AppSettingsScope.translate(
                        context,
                        "customer.search_questions_or_topics.80db7c0a",
                      ),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF73737D)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                      ),
                    ),
                  ),
                  _section(
                    AppSettingsScope.translate(
                      context,
                      "customer.frequently_asked_questions.e956a940",
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: categories
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: _category == category,
                            selectedColor: const Color(0xFFF5E8EC),
                            side: BorderSide(
                              color: _category == category
                                  ? supportWine
                                  : const Color(0xFFF0EDF0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelStyle: TextStyle(
                              color: _category == category
                                  ? supportWine
                                  : const Color(0xFF17171B),
                              fontWeight: _category == category
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  supportPanel(
                    filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.no_matching_questions_try_another_search_or_r.0c5c7f29",
                              ),
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
                  _section(
                    AppSettingsScope.translate(
                      context,
                      "customer.need_a_little_more_help.12e7b448",
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _contactCard(true),
                      const SizedBox(width: 10),
                      _contactCard(false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E8EC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF2D1DC)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: supportWine,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.report_an_issue.635ae219",
                          ),
                          style: const TextStyle(
                            color: supportWine,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.tell_us_what_went_wrong.fb62f1c4",
                          ),
                          style: const TextStyle(
                            color: Color(0xFF73737D),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF73737D)),
                        onTap: () =>
                            _open(ContactSupportScreen(repository: _repository)),
                      ),
                    ),
                  ),
                  _section(
                    AppSettingsScope.translate(
                      context,
                      "customer.my_support_requests.9cce51cb",
                    ),
                    action: TextButton(
                      onPressed: () =>
                          _open(SupportRequestsScreen(repository: _repository)),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.view_all.30a64216",
                        ),
                      ),
                    ),
                  ),
                  supportPanel(
                    _tickets.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.no_support_requests_yet_your_requests_will_ap.ed360d34",
                              ),
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
