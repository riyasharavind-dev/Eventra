import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/support_model.dart';
import '../../repositories/support_repository.dart';
import '../../widgets/support/support_ui.dart';

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
      if (mounted) showSupportError(context, error);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppSettingsScope.translate(context, "customer.screenshot.029320ad"),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.maxFinite,
              child: Image.network(
                url,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(color: supportWine),
                        ),
                      ),
                errorBuilder: (_, error, stack) => Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.unable_to_load_screenshot_please_try_again.f0cfeea5",
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                AppSettingsScope.translate(context, "customer.close.7d9eb7ac"),
                style: const TextStyle(fontWeight: FontWeight.w700, color: supportWine),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showSupportError(context, error);
    }
  }

  Widget _message(String author, String body, DateTime date, bool support) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: supportPanel(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$author · ${supportDate(date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: support ? supportWine : const Color(0xFF6F6F7A),
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
    backgroundColor: supportBackground,
    appBar: AppBar(
      title: Text(_ticket.reference),
      actions: [
        IconButton(
          tooltip: AppSettingsScope.translate(
            context,
            "customer.refresh_request.f3ab0db6",
          ),
          onPressed: _loading || _sending ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? Center(
            child: FilledButton(
              onPressed: _load,
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.unable_to_load_retry.007ee6bc",
                ),
              ),
            ),
          )
        : RefreshIndicator(
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
                  AppSettingsScope.translate(context, "customer.you.08b04193"),
                  _ticket.description,
                  _ticket.createdAt,
                  false,
                ),
                if (_ticket.screenshotPath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: supportWine,
                        side: const BorderSide(color: Color(0xFFF0EDF0)),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: _attachment,
                      icon: const Icon(Icons.image_outlined, color: Color(0xFF73737D)),
                      label: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.view_screenshot.acf862e2",
                        ),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.your_request_has_been_submitted_replies_from_.4c85c2fc",
                      ),
                      style: const TextStyle(color: Color(0xFF73737D)),
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
                        "customer.your_reply.74a41190",
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: supportWine,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(_sending ? 'Sending…' : 'Send reply'),
                  ),
                  if (_ticket.status == 'resolved')
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.sending_a_reply_will_reopen_this_request.e84a424d",
                        ),
                      ),
                    ),
                ] else
                  Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.this_request_is_closed_create_a_new_request_i.1038f2d1",
                    ),
                  ),
              ],
            ),
          ),
  );
}
