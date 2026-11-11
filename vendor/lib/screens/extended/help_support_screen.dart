import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/support_model.dart';
import '../../repositories/support_repository.dart';

const _supportRed = Color(0xFF80152C);
const _supportBackground = Color(0xFFF8F8FA);

String _supportDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day}/${date.month}/${date.year}';
}

void _supportError(BuildContext context, Object error) {
  debugPrint('Support error: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppSettingsScope.translate(
          context,
          "vendor.something_went_wrong_check_your_connection_an.067b61d2",
        ),
      ),
    ),
  );
}

Widget _supportPanel(Widget child) => Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFF0EDF0)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF80152C).withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  clipBehavior: Clip.antiAlias,
  child: child,
);

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
            queryParameters: {'subject': 'Eventor Vendor Support'},
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
                "vendor.unable_to_open_value0_please_submit_a_support.03be8957",
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
      child: _supportPanel(
        InkWell(
          onTap: enabled ? () => _contact(email) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  email ? Icons.mail_outline : Icons.chat_bubble_outline,
                  color: AppIconColors.standard,
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
    return VendorPageScaffold(
      backgroundColor: _supportBackground,
      appBar: AppBar(
        title: Text(
          AppSettingsScope.translate(context, "vendor.help_support.1f8ecc24"),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: AppSettingsScope.translate(
              context,
              "vendor.refresh_support.74fe6d06",
            ),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: AppContentSkeleton(layout: SkeletonLayout.listings),
            )
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
                        "vendor.unable_to_load_support_check_your_connection_.15ccd2b3",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.retry.942087cc",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : AppShimmerRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.eventor_vendor_support.cb8de67d",
                    ),
                    style: TextStyle(
                      color: _supportRed,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.how_can_we_help.7b56e0d0",
                    ),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.find_an_answer_or_reach_out_to_our_team.8d7018c7",
                    ),
                    style: TextStyle(color: Color(0xFF6F6F7A)),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: AppSettingsScope.translate(
                        context,
                        "vendor.search_questions_or_topics.80db7c0a",
                      ),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  _section(
                    AppSettingsScope.translate(
                      context,
                      "vendor.frequently_asked_questions.e956a940",
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
                            showCheckmark: false,
                            selectedColor: _supportRed,
                            labelStyle: TextStyle(
                              color: _category == category
                                  ? Colors.white
                                  : const Color(0xFF615962),
                              fontWeight: _category == category
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: _category == category
                                  ? _supportRed
                                  : const Color(0xFFE8E5E8),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.white,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _supportPanel(
                    filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.no_matching_questions_try_another_search_or_r.0c5c7f29",
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
                      "vendor.need_a_little_more_help.12e7b448",
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
                  Material(
                    color: const Color(0xFFF5E8EC),
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      leading: const Icon(
                        Icons.help_outline,
                        color: AppIconColors.standard,
                      ),
                      title: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.report_an_issue.635ae219",
                        ),
                        style: TextStyle(
                          color: _supportRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.tell_us_what_went_wrong.fb62f1c4",
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        ReportSupportIssueScreen(repository: _repository),
                      ),
                    ),
                  ),
                  _section(
                    AppSettingsScope.translate(
                      context,
                      "vendor.my_support_requests.9cce51cb",
                    ),
                    action: TextButton(
                      onPressed: () =>
                          _open(SupportRequestsScreen(repository: _repository)),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.view_all.30a64216",
                        ),
                      ),
                    ),
                  ),
                  _supportPanel(
                    _tickets.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.no_support_requests_yet_your_requests_will_ap.ed360d34",
                              ),
                            ),
                          )
                        : Column(
                            children: _tickets
                                .take(2)
                                .map(
                                  (ticket) => _SupportTicketTile(
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

class _SupportTicketTile extends StatelessWidget {
  const _SupportTicketTile({required this.ticket, required this.onTap});
  final SupportTicket ticket;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final done = ticket.status == 'resolved' || ticket.status == 'closed';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(16),
      title: Text(
        ticket.subject,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '${ticket.reference} · ${_supportDate(ticket.createdAt)}\n${ticket.category}',
          style: const TextStyle(fontSize: 12, height: 1.6),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 100),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFEAF5EE) : const Color(0xFFFFF4DF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          ticket.statusLabel,
          style: TextStyle(
            fontSize: 11,
            color: done ? const Color(0xFF267349) : const Color(0xFF945C00),
          ),
        ),
      ),
    );
  }
}

class ReportSupportIssueScreen extends StatefulWidget {
  const ReportSupportIssueScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<ReportSupportIssueScreen> createState() =>
      _ReportSupportIssueScreenState();
}

class _ReportSupportIssueScreenState extends State<ReportSupportIssueScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  late final String _requestId;
  String _category = SupportRepository.categories.first;
  XFile? _screenshot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _requestId = widget.repository.newRequestId();
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
                  "vendor.choose_a_jpg_png_or_webp_image_smaller_than_5.d78916c2",
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
      final ticket = await widget.repository.createTicket(
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
              "vendor.request_value0_submitted.6dbad8ac",
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
    child: VendorPageScaffold(
      backgroundColor: _supportBackground,
      appBar: AppBar(
        title: Text(
          AppSettingsScope.translate(
            context,
            "vendor.report_an_issue.635ae219",
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
                "vendor.tell_us_what_happened.70ca7e3a",
              ),
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.a_few_details_will_help_our_team_understand_t.357d1cf1",
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "vendor.category.292c06f0",
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
                  "vendor.subject.68971283",
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? AppSettingsScope.translate(
                      context,
                      "vendor.enter_a_subject_with_at_least_3_characters.da3cf6a9",
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
                  "vendor.description.526e0087",
                ),
                alignLabelWithHint: true,
                hintText: AppSettingsScope.translate(
                  context,
                  "vendor.what_happened_what_did_you_expect_include_the.adac6381",
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? AppSettingsScope.translate(
                      context,
                      "vendor.describe_the_issue_in_at_least_10_characters.2a2368f5",
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pick,
              icon: const Icon(Icons.attach_file),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.attach_screenshot_optional.c47333b2",
                ),
              ),
            ),
            if (_screenshot != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_screenshot!.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.private_attachment_max_5_mb.56cb78cc",
                  ),
                ),
                trailing: IconButton(
                  tooltip: AppSettingsScope.translate(
                    context,
                    "vendor.remove_screenshot.ed14fa72",
                  ),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _screenshot = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.never_share_passwords_pins_full_card_numbers_.48ea9cf9",
              ),
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
                      child: AppShimmerIndicator(strokeWidth: 2),
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

class SupportRequestsScreen extends StatefulWidget {
  const SupportRequestsScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen>
    with LiveDataState<SupportRequestsScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:support_tickets',
    'own:support_messages',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _reload();
  }

  late Future<List<SupportTicket>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.getTickets();
  }

  Future<void> _reload() async {
    final future = widget.repository.getTickets();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder displays the retry state. */
    }
  }

  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    backgroundColor: _supportBackground,
    appBar: AppBar(
      title: Text(
        AppSettingsScope.translate(
          context,
          "vendor.my_support_requests.9cce51cb",
        ),
      ),
      actions: [
        IconButton(
          tooltip: AppSettingsScope.translate(
            context,
            "vendor.refresh_requests.2ce6d3e7",
          ),
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<SupportTicket>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: AppContentSkeleton(layout: SkeletonLayout.listings),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: _reload,
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.unable_to_load_retry.007ee6bc",
                ),
              ),
            ),
          );
        }
        final tickets = snapshot.data ?? [];
        return AppShimmerRefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: tickets.isEmpty
                ? [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.no_support_requests_yet.7121a59c",
                        ),
                      ),
                    ),
                  ]
                : tickets
                      .map(
                        (ticket) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _supportPanel(
                            _SupportTicketTile(
                              ticket: ticket,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SupportRequestDetailScreen(
                                      ticket: ticket,
                                      repository: widget.repository,
                                    ),
                                  ),
                                );
                                if (mounted) await _reload();
                              },
                            ),
                          ),
                        ),
                      )
                      .toList(),
          ),
        );
      },
    ),
  );
}

class SupportRequestDetailScreen extends StatefulWidget {
  const SupportRequestDetailScreen({
    super.key,
    required this.ticket,
    required this.repository,
  });
  final SupportTicket ticket;
  final SupportRepository repository;
  @override
  State<SupportRequestDetailScreen> createState() =>
      _SupportRequestDetailScreenState();
}

class _SupportRequestDetailScreenState extends State<SupportRequestDetailScreen>
    with LiveDataState<SupportRequestDetailScreen> {
  @override
  bool get liveCanRefresh => !_sending && !_loading;
  @override
  Set<String> get liveDatasets => {
    'own:support_tickets',
    'own:support_messages',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

  final _reply = TextEditingController();
  late SupportTicket _ticket;
  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      if (!liveRefreshing) _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait<Object>([
        widget.repository.getTickets(ticketId: _ticket.id),
        widget.repository.getMessages(_ticket.id),
      ]);
      final tickets = results[0] as List<SupportTicket>;
      if (tickets.isEmpty) throw Exception('Request unavailable');
      if (!mounted) return;
      setState(() {
        _ticket = tickets.first;
        _messages = results[1] as List<SupportMessage>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.repository.reply(_ticket.id, _reply.text);
      _reply.clear();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) _supportError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachment() async {
    try {
      final url = await widget.repository.attachmentUrl(
        _ticket.screenshotPath!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            AppSettingsScope.translate(context, "vendor.screenshot.029320ad"),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Image.network(
              url,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 180,
                      child: Center(child: AppShimmerIndicator()),
                    ),
              errorBuilder: (_, error, stack) => Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.unable_to_load_screenshot_please_try_again.f0cfeea5",
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                AppSettingsScope.translate(context, "vendor.close.7d9eb7ac"),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _supportError(context, error);
    }
  }

  Widget _message(String author, String body, DateTime date, bool support) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _supportPanel(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$author · ${_supportDate(date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: support ? _supportRed : const Color(0xFF6F6F7A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(body, style: const TextStyle(height: 1.6)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    backgroundColor: _supportBackground,
    appBar: AppBar(
      title: Text(_ticket.reference),
      actions: [
        IconButton(
          tooltip: AppSettingsScope.translate(
            context,
            "vendor.refresh_request.f3ab0db6",
          ),
          onPressed: _loading || _sending ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(
            child: AppContentSkeleton(layout: SkeletonLayout.document),
          )
        : _failed
        ? Center(
            child: FilledButton(
              onPressed: _load,
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.unable_to_load_retry.007ee6bc",
                ),
              ),
            ),
          )
        : AppShimmerRefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  _ticket.subject,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text('${_ticket.category} · ${_ticket.statusLabel}'),
                const SizedBox(height: 22),
                _message(
                  AppSettingsScope.translate(context, "vendor.you.08b04193"),
                  _ticket.description,
                  _ticket.createdAt,
                  false,
                ),
                if (_ticket.screenshotPath != null)
                  OutlinedButton.icon(
                    onPressed: _attachment,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.view_screenshot.acf862e2",
                      ),
                    ),
                  ),
                ..._messages.map(
                  (message) => _message(
                    message.fromSupport ? 'Eventor Support' : 'You',
                    message.body,
                    message.createdAt,
                    message.fromSupport,
                  ),
                ),
                if (_messages.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.your_request_has_been_submitted_replies_from_.4c85c2fc",
                      ),
                    ),
                  ),
                if (_ticket.status != 'closed') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reply,
                    enabled: !_sending,
                    maxLength: 4000,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: AppSettingsScope.translate(
                        context,
                        "vendor.your_reply.74a41190",
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(backgroundColor: _supportRed),
                    child: Text(_sending ? 'Sending…' : 'Send reply'),
                  ),
                  if (_ticket.status == 'resolved')
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.sending_a_reply_will_reopen_this_request.e84a424d",
                        ),
                      ),
                    ),
                ] else
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.this_request_is_closed_create_a_new_request_i.1038f2d1",
                    ),
                  ),
              ],
            ),
          ),
  );
}
