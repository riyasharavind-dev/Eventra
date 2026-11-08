import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/support_model.dart';
import '../../repositories/support_repository.dart';
import '../../widgets/support/support_ui.dart';
import '../../widgets/support/support_ticket_tile.dart';
import 'support_request_detail_screen.dart';

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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: supportBackground,
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
          return const Center(child: CircularProgressIndicator());
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
        return RefreshIndicator(
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
                          child: supportPanel(
                            SupportTicketTile(
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
