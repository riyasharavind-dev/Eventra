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
          title: const Text('Screenshot'),
          content: SizedBox(
            width: double.maxFinite,
            child: Image.network(
              url,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
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
          tooltip: 'Refresh request',
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
              child: const Text('Unable to load. Retry'),
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
                _message('You', _ticket.description, _ticket.createdAt, false),
                if (_ticket.screenshotPath != null)
                  OutlinedButton.icon(
                    onPressed: _attachment,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('View screenshot'),
                  ),
                ..._messages.map(
                  (message) => _message(
                    message.fromSupport ? 'Eventra Support' : 'You',
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
                    style: FilledButton.styleFrom(backgroundColor: supportWine),
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
