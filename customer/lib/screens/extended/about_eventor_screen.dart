import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/about_eventor_model.dart';
import '../../repositories/about_eventor_repository.dart';
import 'privacy_policy_screen.dart';
import 'terms_and_conditions_screen.dart';

class AboutEventorScreen extends StatefulWidget {
  const AboutEventorScreen({
    super.key,
    this.languageCode = 'en',
    this.repository,
  });

  final String languageCode;
  final AboutEventorRepository? repository;

  @override
  State<AboutEventorScreen> createState() => _AboutEventorScreenState();
}

class _AboutEventorScreenState extends State<AboutEventorScreen>
    with LiveDataState<AboutEventorScreen> {
  @override
  Set<String> get liveDatasets => {'public:about_eventra_content'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

  static const _red = Color(0xFF80152C);
  // Match the installed app's pubspec.yaml, not editable marketing content.
  static const _version = '1.0.0';
  static const _build = '1';
  late final AboutEventorRepository _repository;
  AboutEventorModel? _about;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AboutEventorRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (!liveRefreshing) _loading = true;
      _failed = false;
    });
    try {
      final about = await _repository.getCustomerAbout(
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _about = about;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Unable to load About Eventor: $error');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Widget _feature(AboutEventorFeature feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: _red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  feature.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF6F6F7A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: _red, size: 44),
            const SizedBox(height: 16),
            Text(
              _failed
                  ? 'Unable to load About Eventor'
                  : 'About information is not available yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              _failed
                  ? 'Check your connection and try again.'
                  : 'Please check back once the content is published.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _load,
              child: Text(_failed ? 'Retry' : 'Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final about = _about;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text('About Eventor'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh About Eventor',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _red))
            : _failed || about == null
            ? _message()
            : RefreshIndicator(
                onRefresh: _load,
                color: _red,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: Icon(
                              Icons.celebration_outlined,
                              color: _red,
                              size: 72,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            about.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (about.tagline.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              about.tagline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF6F6F7A),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            'Version $_version · Build $_build',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF777777),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFECECEC),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  about.introduction,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.65,
                                    color: Color(0xFF6F6F7A),
                                  ),
                                ),
                                if (about.features.isNotEmpty)
                                  const SizedBox(height: 12),
                                ...about.features.map(_feature),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Policies',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.description_outlined,
                                    color: _red,
                                  ),
                                  title: const Text('Terms & Conditions'),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () =>
                                      _open(const TermsAndConditionsScreen()),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.privacy_tip_outlined,
                                    color: _red,
                                  ),
                                  title: const Text('Privacy Policy'),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () =>
                                      _open(const PrivacyPolicyScreen()),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
