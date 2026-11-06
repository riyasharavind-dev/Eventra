import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';

class AdminCustomerAppScreen extends StatefulWidget {
  const AdminCustomerAppScreen({
    super.key,
    required this.repo,
    required this.modules,
    required this.onOpen,
  });
  final AdminRepository repo;
  final List<AdminModule> modules;
  final void Function(String, Map<String, dynamic>) onOpen;
  @override
  State<AdminCustomerAppScreen> createState() => _AdminCustomerAppScreenState();
}

class _AdminCustomerAppScreenState extends State<AdminCustomerAppScreen> {
  late Future<AdminPage> _contacts;
  @override
  void initState() {
    super.initState();
    _contacts = widget.repo.records(
      'support_settings',
      filters: const {'audience': 'customer'},
    );
  }

  Future<void> _refresh() async {
    final future = widget.repo.records(
      'support_settings',
      filters: const {'audience': 'customer'},
    );
    setState(() => _contacts = future);
    try {
      await future;
    } catch (_) {
      /* Render retry. */
    }
  }

  Widget _entry(
    String title,
    String detail,
    String module,
    IconData icon, [
    Map<String, dynamic> filters = const {},
  ]) {
    final available = widget.modules.any((m) => m.name == module);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          available ? detail : 'Module unavailable. Recheck admin permissions.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: available
            ? () => widget.onOpen(module, Map<String, dynamic>.from(filters))
            : null,
      ),
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Customer App',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage the content and support shown in the customer Me screen. Saved and published content is loaded from the same database by the app.',
        ),
        _heading('Home Feed'),
        _entry(
          'Home sections & rules',
          'Create vendor/service sections, curate pins, preview and publish.',
          'home_feed_sections',
          Icons.view_carousel_outlined,
        ),
        _heading('Support'),
        FutureBuilder<AdminPage>(
          future: _contacts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: _refresh,
                child: const Text('Unable to check support contacts. Retry'),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final row = snapshot.data!.rows.firstOrNull;
            final missing = <String>[
              if ((row?.values['email']?.toString().trim() ?? '').isEmpty)
                'email',
              if ((row?.values['whatsapp_number']?.toString().trim() ?? '')
                  .isEmpty)
                'WhatsApp number',
            ];
            if (missing.isEmpty) {
              return const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Customer support contacts are configured'),
              );
            }
            return Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Complete customer support contacts'),
                subtitle: Text(
                  'Add ${missing.join(' and ')} to enable these contact options in the app.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    widget.onOpen('support_settings', {'audience': 'customer'}),
              ),
            );
          },
        ),
        _entry(
          'Help & Support FAQs',
          'Add answers, choose their order, and publish or hide customer questions.',
          'support_faqs',
          Icons.help_outline,
          {'audience': 'customer'},
        ),
        _entry(
          'Contact Support settings',
          'Set customer email, WhatsApp number, business hours and response time.',
          'support_settings',
          Icons.contact_support_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Support inbox',
          'Read customer and vendor requests, view private screenshots, reply and update ticket status.',
          'support_tickets',
          Icons.support_agent,
        ),
        _entry(
          'Support conversations',
          'Review customer, vendor and support replies. Open the linked ticket to respond.',
          'support_messages',
          Icons.forum_outlined,
        ),
        _heading('About & Legal'),
        _entry(
          'About Eventra',
          'Edit the customer introduction, tagline and feature list. Enable publication to show it in the app.',
          'about_eventra_content',
          Icons.info_outline,
          {'audience': 'customer'},
        ),
        _entry(
          'Privacy Policy',
          'Create a new draft version, edit, then publish the customer privacy policy.',
          'legal_documents',
          Icons.privacy_tip_outlined,
          {'audience': 'customer', 'document_type': 'privacy_policy'},
        ),
        _entry(
          'Terms & Conditions',
          'Manage customer terms using the draft, publish and archive workflow.',
          'legal_documents',
          Icons.description_outlined,
          {'audience': 'customer', 'document_type': 'terms_and_conditions'},
        ),
        _heading('Follow Us'),
        _entry(
          'Customer social links',
          'Upload icons, set destinations and choose their display order.',
          'social_links',
          Icons.share_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Shared social links',
          'Links with Both apps audience appear in customer and vendor apps.',
          'social_links',
          Icons.public,
          {'audience': 'all'},
        ),
        _heading('Published app content'),
        _entry(
          'Live customer FAQs',
          'Check the published questions currently available to customers.',
          'published_support_faqs',
          Icons.fact_check_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Live About Eventra',
          'Check the published customer About page.',
          'published_about_eventra_content',
          Icons.article_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Live legal documents',
          'Check the currently effective customer Privacy Policy and Terms.',
          'current_legal_documents',
          Icons.policy_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Live social links',
          'Inspect active links; App audience can be Customer or Both apps.',
          'active_social_links',
          Icons.link,
        ),
      ],
    ),
  );
}
