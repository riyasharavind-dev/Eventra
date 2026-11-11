import 'package:eventor_customer/services/app_settings_controller.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/image_download.dart';

class ServiceGallery extends StatefulWidget {
  const ServiceGallery({
    super.key,
    required this.gallery,
    this.isSaved = false,
    this.saving = false,
    this.onSave,
    this.onShare,
  });
  final List<String> gallery;
  final bool isSaved, saving;
  final VoidCallback? onSave, onShare;
  @override
  State<ServiceGallery> createState() => _ServiceGalleryState();
}

class _ServiceGalleryState extends State<ServiceGallery>
    with WidgetsBindingObserver {
  late final PageController page;
  Timer? timer;
  bool active = true;
  int virtualPage = 0;
  int loopStart(int length) => length <= 1 ? 0 : 100000 - (100000 % length);
  @override
  void initState() {
    super.initState();
    virtualPage = loopStart(widget.gallery.length);
    page = PageController(initialPage: virtualPage);
    WidgetsBinding.instance.addObserver(this);
    restartTimer();
  }

  void restartTimer() {
    timer?.cancel();
    if (widget.gallery.length <= 1 || !active) return;
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !page.hasClients ||
          downloading ||
          page.position.isScrollingNotifier.value ||
          ModalRoute.of(context)?.isCurrent != true ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      page.animateToPage(
        virtualPage + 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      restartTimer();
    } else {
      timer?.cancel();
    }
  }

  int selected = 0;
  bool downloading = false;
  @override
  void didUpdateWidget(covariant ServiceGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.gallery, widget.gallery)) {
      selected = widget.gallery.isEmpty
          ? 0
          : selected.clamp(0, widget.gallery.length - 1);
      virtualPage = loopStart(widget.gallery.length) + selected;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && page.hasClients) page.jumpToPage(virtualPage);
      });
      restartTimer();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    page.dispose();
    super.dispose();
  }

  void select(int index) {
    if (page.hasClients) {
      page.animateToPage(
        virtualPage - virtualPage % widget.gallery.length + index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> download() async {
    if (downloading || widget.gallery.isEmpty) return;
    final url = widget.gallery[selected];
    setState(() => downloading = true);
    try {
      await downloadServiceImage(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.image_saved_download_started.3cfc06bd",
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.could_not_save_image_check_photo_permission_a.2f3c6d2a",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => downloading = false);
      }
    }
  }

  Widget photo(String url) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xFFF5E8EC),
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF73737D)),
      ),
    ),
  );
  Future<void> allPhotos() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: widget.gallery.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => Navigator.pop(context, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo(widget.gallery[i]),
              ),
            ),
          ),
        ),
      ),
    );
    if (index != null && mounted) select(index);
  }

  Widget action(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool selected = false,
  }) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: const EdgeInsets.all(5),
      color: selected ? const Color(0xFFFFCB48) : Colors.white,
      disabledColor: selected ? const Color(0xFFFFCB48) : Colors.white,
      onPressed: onTap,
      icon: Icon(
        icon,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 5)],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final images = widget.gallery;
    return Listener(
      onPointerDown: (_) => timer?.cancel(),
      onPointerUp: (_) => restartTimer(),
      onPointerCancel: (_) => restartTimer(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.isEmpty)
                      const ColoredBox(
                        color: Color(0xFFF5E8EC),
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    else
                      PageView.builder(
                        controller: page,
                        itemCount: images.length == 1 ? 1 : null,
                        onPageChanged: (index) => setState(() {
                          virtualPage = index;
                          selected = index % images.length;
                        }),
                        itemBuilder: (_, i) => photo(images[i % images.length]),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        children: [
                          action(
                            widget.isSaved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            'Save service',
                            widget.saving ? null : widget.onSave,
                            selected: widget.isSaved,
                          ),
                          const SizedBox(height: 5),
                          action(
                            downloading
                                ? Icons.hourglass_top_rounded
                                : Icons.download_rounded,
                            'Download image',
                            images.isEmpty || downloading ? null : download,
                          ),
                          const SizedBox(height: 5),
                          action(
                            Icons.share_outlined,
                            'Share service',
                            widget.onShare,
                          ),
                        ],
                      ),
                    ),
                    if (images.isNotEmpty)
                      Positioned(
                        bottom: 9,
                        right: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${selected + 1} / ${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: (constraints.maxWidth - 32) / 5 * .68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length > 5 ? 5 : images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final more = i == 4 && images.length > 5;
                      return GestureDetector(
                        onTap: () => more ? allPhotos() : select(i),
                        child: Container(
                          width: (constraints.maxWidth - 32) / 5,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: selected == i
                                  ? const Color(0xFF80152C)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                photo(images[i]),
                                if (more)
                                  ColoredBox(
                                    color: Colors.black.withValues(alpha: .6),
                                    child: Center(
                                      child: Text(
                                        '+${images.length - 5}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
