import 'package:flutter/material.dart';

class ServiceGallery extends StatefulWidget {
  final List<String> gallery;

  const ServiceGallery({
    super.key,
    required this.gallery,
  });

  @override
  State<ServiceGallery> createState() =>
      _ServiceGalleryState();
}

class _ServiceGalleryState
    extends State<ServiceGallery> {
  late final PageController _pageController;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> gallery = widget.gallery;

    // ==========================================================
    // NO IMAGE
    // ==========================================================

    if (gallery.isEmpty) {
      return Container(
        height: 350,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 70,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // ====================================================
          // IMAGE VIEWER
          // ====================================================

          SizedBox(
            height: 350,
            width: double.infinity,
            child: PageView.builder(
              controller: _pageController,
              itemCount: gallery.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 3,
                  child: Image.network(
                    gallery[index],
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // ====================================================
          // INDICATORS
          // ====================================================

          if (gallery.length > 1)
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 10,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: List.generate(
                  gallery.length,
                  (index) {
                    final bool active =
                        index == _currentIndex;

                    return AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      margin:
                          const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      height: 6,
                      width: active ? 20 : 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                            : Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}