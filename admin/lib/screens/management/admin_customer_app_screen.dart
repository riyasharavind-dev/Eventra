import '../../services/app_live_data.dart';

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

class _AdminCustomerAppScreenState extends State<AdminCustomerAppScreen>
    with LiveDataState<AdminCustomerAppScreen> {
  @override
  Set<String> get liveDatasets => {'admin:support_settings'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _refresh();
  }

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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: available
              ? () => widget.onOpen(module, Map<String, dynamic>.from(filters))
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8EC),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: const Color(0xFF80152C), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        available
                            ? detail
                            : 'Module unavailable in current permission level.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: available
                              ? const Color(0xFF73737D)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA0A0AC),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF17171B),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: const Color(0xFF80152C),
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF80152C).withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer App Studio',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17171B),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Directly control dynamic customer feed sections, support settings, legal policies, and published content shown on mobile devices.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF73737D)),
              ),
            ],
          ),
        ),

        _heading('Home Feed & Discovery'),
        _entry(
          'Home feed sections & visual rules',
          'Create and order service/vendor rails, curate sticky pins, and publish live.',
          'home_feed_sections',
          Icons.view_carousel_outlined,
        ),

        _heading('Customer Support & Assistance'),
        FutureBuilder<AdminPage>(
          future: _contacts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: _refresh,
                child: const Text('Unable to check support contacts. Retry'),
              );
            }
            if (!snapshot.hasData) {
              return const LinearProgressIndicator(color: Color(0xFF80152C));
            }
            final row = snapshot.data!.rows.firstOrNull;
            final missing = <String>[
              if ((row?.values['email']?.toString().trim() ?? '').isEmpty)
                'email',
              if ((row?.values['whatsapp_number']?.toString().trim() ?? '')
                  .isEmpty)
                'WhatsApp number',
            ];
            if (missing.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Customer support channels are fully configured and active.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF57F17),
                  ),
                  title: const Text(
                    'Complete customer support contacts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Add ${missing.join(' and ')} to enable instant customer outreach options in the app.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onOpen('support_settings', {
                    'audience': 'customer',
                  }),
                ),
              ),
            );
          },
        ),
        _entry(
          'Help & Support FAQs',
          'Add answers, choose their display order, and publish or hide customer questions.',
          'support_faqs',
          Icons.help_outline,
          {'audience': 'customer'},
        ),
        _entry(
          'Contact Support Settings',
          'Set customer email, WhatsApp phone, operational hours and expected response times.',
          'support_settings',
          Icons.contact_support_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Support Inbox & Tickets',
          'Read incoming customer inquiries, inspect uploaded attachments, reply and close tickets.',
          'support_tickets',
          Icons.support_agent_outlined,
        ),
        _entry(
          'Support Conversations History',
          'Review full transcript logs of customer, vendor, and agent replies.',
          'support_messages',
          Icons.forum_outlined,
        ),

        _heading('About Eventor & Compliance'),
        _entry(
          'About Eventor Content',
          'Edit platform introduction, mission statement, features, and brand overview.',
          'about_eventra_content',
          Icons.info_outline,
          {'audience': 'customer'},
        ),
        _entry(
          'Privacy Policy',
          'Draft, review revision history, and publish customer privacy agreements.',
          'legal_documents',
          Icons.privacy_tip_outlined,
          {'audience': 'customer', 'document_type': 'privacy_policy'},
        ),
        _entry(
          'Terms & Conditions Document',
          'Manage legal terms of service for customers with immutable published archives.',
          'legal_documents',
          Icons.description_outlined,
          {'audience': 'customer', 'document_type': 'terms_and_conditions'},
        ),

        _heading('Social & Community Links'),
        _entry(
          'Customer Specific Social Handles',
          'Configure Instagram, YouTube, and website links dedicated to customer audiences.',
          'social_links',
          Icons.share_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Shared Platform Social Links',
          'Manage universal links displayed across both customer and vendor applications.',
          'social_links',
          Icons.public,
          {'audience': 'all'},
        ),

        _heading('Live Published State'),
        _entry(
          'Live Published FAQs',
          'Inspect active answers currently cached and accessible by users.',
          'published_support_faqs',
          Icons.fact_check_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Live Published About Screen',
          'View currently effective public about copy.',
          'published_about_eventra_content',
          Icons.article_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Live Effective Legal Documents',
          'Audit current legal versions actively binding for end customers.',
          'current_legal_documents',
          Icons.policy_outlined,
          {'audience': 'customer'},
        ),
        _entry(
          'Live Active Social Links',
          'Verify currently active social link destinations.',
          'active_social_links',
          Icons.link_rounded,
        ),
      ],
    ),
  );
}
