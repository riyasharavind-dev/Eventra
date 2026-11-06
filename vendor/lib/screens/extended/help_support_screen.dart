import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/support_model.dart';
import '../../repositories/support_repository.dart';

const _supportRed = Color(0xFF9F0101);
const _supportBackground = Color(0xFFF8F8FA);

String _supportDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day}/${date.month}/${date.year}';
}

void _supportError(BuildContext context, Object error) {
  debugPrint('Support error: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Something went wrong. Check your connection and try again.',
      ),
    ),
  );
}

Widget _supportPanel(Widget child) => Material(
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xFFECECEF)),
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
                  color: _supportRed,
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
      backgroundColor: _supportBackground,
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
          : AppShimmerRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'EVENTOR VENDOR SUPPORT',
                    style: TextStyle(
                      color: _supportRed,
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
                  _supportPanel(
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
                        color: _supportRed,
                      ),
                      title: const Text(
                        'Report an issue',
                        style: TextStyle(
                          color: _supportRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Tell us what went wrong'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        ReportSupportIssueScreen(repository: _repository),
                      ),
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
                  _supportPanel(
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
      final ticket = await widget.repository.createTicket(
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
      appBar: AppBar(title: const Text('Report an issue')),
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

class _SupportRequestsScreenState extends State<SupportRequestsScreen> {
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _supportBackground,
    appBar: AppBar(
      title: const Text('My support requests'),
      actions: [
        IconButton(
          tooltip: 'Refresh requests',
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
              child: const Text('Unable to load. Retry'),
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
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No support requests yet.'),
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

class _SupportRequestDetailScreenState
    extends State<SupportRequestDetailScreen> {
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
      _loading = true;
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
          title: const Text('Screenshot'),
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
              errorBuilder: (_, error, stack) =>
                  const Text('Unable to load screenshot. Please try again.'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _supportBackground,
    appBar: AppBar(
      title: Text(_ticket.reference),
      actions: [
        IconButton(
          tooltip: 'Refresh request',
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
              child: const Text('Unable to load. Retry'),
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
                _message('You', _ticket.description, _ticket.createdAt, false),
                if (_ticket.screenshotPath != null)
                  OutlinedButton.icon(
                    onPressed: _attachment,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('View screenshot'),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Your request has been submitted. Replies from support will appear here.',
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
                    decoration: const InputDecoration(
                      labelText: 'Your reply',
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
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('Sending a reply will reopen this request.'),
                    ),
                ] else
                  const Text(
                    'This request is closed. Create a new request if you need more help.',
                  ),
              ],
            ),
          ),
  );
}
