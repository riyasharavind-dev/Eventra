import 'package:flutter/material.dart';

import '../../models/service_model.dart';

import '../../widgets/service_details/service_action_bar.dart';
import '../../widgets/service_details/service_description_section.dart';
import '../../widgets/service_details/service_details_section.dart';
import '../../widgets/service_details/service_gallery.dart';
import '../../widgets/service_details/service_info_section.dart';

import 'booking_screen.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final ServiceModel service;

  const ServiceDetailsScreen({
    super.key,
    required this.service,
  });

  @override
  State<ServiceDetailsScreen> createState() =>
      _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState
    extends State<ServiceDetailsScreen> {
  bool _isFavorite = false;

  // ============================================================
  // ADD TO PLAN
  // ============================================================

  void _addToPlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add to Plan will be available soon.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BOOK SERVICE
  // ============================================================

  Future<void> _bookService() async {
    final bool? bookingCreated =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          service: widget.service,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (bookingCreated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Booking request created successfully.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ServiceModel service =
        widget.service;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F5F5),

      // ========================================================
      // FIXED BOTTOM ACTION BAR
      // ========================================================

      bottomNavigationBar:
          ServiceActionBar(
        onAddToPlan:
            _addToPlan,
        onBookService:
            _bookService,
      ),

      // ========================================================
      // SCREEN CONTENT
      // ========================================================

      body: CustomScrollView(
        slivers: [

          // ======================================================
          // APP BAR
          // ======================================================

          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor:
                Colors.white,
            foregroundColor:
                Colors.black,

            title: const Text(
              'Service Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            actions: [

              IconButton(
                tooltip:
                    'Favorite',

                onPressed: () {
                  setState(() {
                    _isFavorite =
                        !_isFavorite;
                  });
                },

                icon: Icon(
                  _isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,

                  color: _isFavorite
                      ? Colors.red
                      : Colors.black,
                ),
              ),

              const SizedBox(
                width: 4,
              ),
            ],
          ),

          // ======================================================
          // GALLERY
          // ======================================================

          SliverToBoxAdapter(
            child:
                ServiceGallery(
              gallery:
                  service.gallery,
            ),
          ),

          // ======================================================
          // SERVICE INFO
          // ======================================================

          SliverToBoxAdapter(
            child:
                ServiceInfoSection(
              service:
                  service,
            ),
          ),

          // ======================================================
          // DESCRIPTION
          // ======================================================

          SliverToBoxAdapter(
            child:
                ServiceDescriptionSection(
              service:
                  service,
            ),
          ),

          // ======================================================
          // SERVICE DETAILS
          // ======================================================

          SliverToBoxAdapter(
            child:
                ServiceDetailsSection(
              service:
                  service,
            ),
          ),

          // ======================================================
          // BOTTOM SPACE
          // ======================================================

          const SliverToBoxAdapter(
            child: SizedBox(
              height: 30,
            ),
          ),
        ],
      ),
    );
  }
}