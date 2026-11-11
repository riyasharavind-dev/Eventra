import '../services/app_live_data.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/profile_section_title.dart';
import '../models/social_link_model.dart';
import '../repositories/social_links_repository.dart';
import '../services/app_settings_controller.dart';

class FollowUsSection extends StatefulWidget {
  const FollowUsSection({
    super.key,
    this.refreshKey = 0,
    this.loadLinks,
    this.openLink,
  });

  final int refreshKey;
  final Future<List<SocialLinkModel>> Function()? loadLinks;
  final Future<bool> Function(Uri)? openLink;

  @override
  State<FollowUsSection> createState() => _FollowUsSectionState();
}

class _FollowUsSectionState extends State<FollowUsSection>
    with LiveDataState<FollowUsSection> {
  @override
  Set<String> get liveDatasets => {'public:social_links'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _refresh();
  }

  List<SocialLinkModel> _links = SocialLinksRepository.cachedLinks;
  bool _opening = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant FollowUsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey ||
        widget.loadLinks != oldWidget.loadLinks) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    try {
      final repository = widget.loadLinks == null
          ? SocialLinksRepository()
          : null;
      if (repository != null) {
        final cached = await repository.readCache();
        if (!mounted || generation != _generation) return;
        setState(() => _links = cached);
      }
      final links = await (widget.loadLinks?.call() ?? repository!.getLinks());
      if (!mounted || generation != _generation) return;
      setState(() => _links = links);
    } catch (_) {
      // Keep the visible icons and last known links during a connection failure.
    }
  }

  IconData _icon(String key) => switch (key.toLowerCase().trim()) {
    'whatsapp' => Icons.chat_outlined,
    'instagram' => Icons.camera_alt_outlined,
    'facebook' => Icons.facebook,
    'youtube' => Icons.play_circle_outline,
    'telegram' => Icons.send_outlined,
    'website' => Icons.language,
    'email' => Icons.mail_outline,
    _ => Icons.link,
  };

  Future<void> _open(SocialLinkModel item) async {
    final uri = item.destination;

    if (_opening || uri == null) return;

    setState(() => _opening = true);

    try {
      final opened =
          await (widget.openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));

      if (!opened) {
        throw Exception('Link could not be opened');
      }
    } catch (_) {
      if (!mounted) return;

      final settings = AppSettingsScope.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.text(
              'Unable to open this link. Please try again.',
              'இணைப்பைத் திறக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Widget _socialIcon(SocialLinkModel item, ColorScheme colors) {
    const wine = Color(0xFF80152C);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: item.name,
          onPressed: item.destination == null || _opening
              ? null
              : () => _open(item),
          icon: item.imageUri == null
              ? Icon(_icon(item.icon), color: const Color(0xFF73737D), size: 24)
              : Image.network(
                  item.imageUri.toString(),
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  frameBuilder: (_, child, frame, synchronouslyLoaded) =>
                      frame != null || synchronouslyLoaded
                      ? child
                      : Icon(
                          _icon(item.icon),
                          color: const Color(0xFF73737D),
                          size: 24,
                        ),
                  errorBuilder: (_, error, stack) => Icon(
                    _icon(item.icon),
                    color: const Color(0xFF73737D),
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionTitle(
          settings.text('Follow Us', 'எங்களைப் பின்தொடருங்கள்'),
        ),
        const SizedBox(height: 8),
        if (_links.isEmpty)
          Text(
            settings.text(
              'Community links will appear here once added.',
              'சமூக இணைப்புகள் சேர்க்கப்பட்டதும் இங்கே தோன்றும்.',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          )
        else
          Builder(
            builder: (context) {
              final links = _links;
              return LayoutBuilder(
                builder: (context, constraints) {
                  const iconSize = 58.0;
                  const spacing = 12.0;

                  final totalWidth =
                      links.length * iconSize + (links.length - 1) * spacing;

                  // Center the row when it fits.
                  // Allow horizontal scrolling when it overflows.
                  final rowWidth = totalWidth < constraints.maxWidth
                      ? constraints.maxWidth
                      : totalWidth;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: rowWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < links.length; i++) ...[
                            _socialIcon(links[i], colors),
                            if (i < links.length - 1)
                              const SizedBox(width: spacing),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
