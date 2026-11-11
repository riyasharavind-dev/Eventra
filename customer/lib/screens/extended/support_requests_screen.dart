import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/support_model.dart';
import '../../repositories/support_repository.dart';
import '../../widgets/common/app_empty_state.dart';
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
      title: Text(
        AppSettingsScope.translate(
          context,
          "customer.my_support_requests.9cce51cb",
        ),
      ),
      actions: [
        IconButton(
          tooltip: AppSettingsScope.translate(
            context,
            "customer.refresh_requests.2ce6d3e7",
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
          return const Center(child: CircularProgressIndicator(color: supportWine));
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: supportWine,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: _reload,
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.unable_to_load_retry.007ee6bc",
                ),
              ),
            ),
          );
        }
        final tickets = snapshot.data ?? [];
        return RefreshIndicator(
          color: supportWine,
          onRefresh: _reload,
          child: tickets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                    AppEmptyState(
                      icon: Icons.support_agent_outlined,
                      title: AppSettingsScope.translate(
                        context,
                        "customer.no_support_requests_yet.7121a59c",
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: tickets
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
