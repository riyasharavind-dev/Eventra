import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/service_model.dart';
import '../../repositories/booking_repository.dart';

class BookingScreen extends StatefulWidget {
  final ServiceModel service;

  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ============================================================
  // REPOSITORY
  // ============================================================

  final BookingRepository _repository = BookingRepository();

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _guestController = TextEditingController();

  final TextEditingController _requirementController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  DateTime? _selectedDate;

  bool _isSaving = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _guestController.dispose();

    _requirementController.dispose();

    super.dispose();
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate() async {
    if (_isSaving) {
      return;
    }

    final DateTime now = DateTime.now();

    final DateTime? selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: _selectedDate ?? now,
    );

    if (selected == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDate = selected;
    });
  }

  // ============================================================
  // CREATE BOOKING
  // ============================================================

  Future<void> _createBooking() async {
    // ----------------------------------------------------------
    // VALIDATE FORM
    // ----------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // VALIDATE EVENT DATE
    // ----------------------------------------------------------

    if (_selectedDate == null) {
      _showMessage('Please select your event date.', isError: true);

      return;
    }

    // ----------------------------------------------------------
    // CURRENT USER
    // ----------------------------------------------------------

    final SupabaseClient supabase = Supabase.instance.client;

    final User? user = supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.', isError: true);

      return;
    }

    // ----------------------------------------------------------
    // GUEST COUNT
    // ----------------------------------------------------------

    final int? guestCount = int.tryParse(_guestController.text.trim());

    if (guestCount == null || guestCount <= 0) {
      _showMessage('Please enter a valid guest count.', isError: true);

      return;
    }

    // ----------------------------------------------------------
    // START SAVING
    // ----------------------------------------------------------

    setState(() {
      _isSaving = true;
    });

    try {
      // --------------------------------------------------------
      // CREATE BOOKING
      // --------------------------------------------------------

      await _repository.createBooking(
        customerId: user.id,

        vendorId: widget.service.vendorId,

        serviceId: widget.service.id,

        // ServiceModel currently doesn't expose
        // eventTypeId.
        eventTypeId: null,

        eventDate: _selectedDate!,

        guestCount: guestCount,

        // ------------------------------------------------------
        // REQUIREMENT
        // ------------------------------------------------------
        requirement: _requirementController.text.trim().isEmpty
            ? null
            : _requirementController.text.trim(),

        // ------------------------------------------------------
        // PRICE
        // ------------------------------------------------------
        price: widget.service.price,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Booking request sent successfully.');

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }

    // ----------------------------------------------------------
    // STOP LOADING
    //
    // IMPORTANT:
    // No return inside finally.
    // ----------------------------------------------------------

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ServiceModel service = widget.service;

    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Book Service',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ==================================================
            // SERVICE SUMMARY
            // ==================================================

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '₹${service.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // EVENT DATE
            // ==================================================
            const Text(
              'Event Date',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            InkWell(
              onTap: _isSaving ? null : _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select event date'
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                            '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                            '${_selectedDate!.year}',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // GUEST COUNT
            // ==================================================
            TextFormField(
              controller: _guestController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Guest Count',
                hintText: 'Example: 200',
                prefixIcon: Icon(Icons.groups_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter guest count';
                }

                final int? count = int.tryParse(value.trim());

                if (count == null || count <= 0) {
                  return 'Enter a valid guest count';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            // ==================================================
            // REQUIREMENT
            // ==================================================
            TextFormField(
              controller: _requirementController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Requirement',
                hintText: 'Tell the vendor about your requirement...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 28),

            // ==================================================
            // PRICE
            // ==================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Service Price',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  Text(
                    '₹${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // CONFIRM BOOKING
            // ==================================================
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _createBooking,

                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),

                label: Text(
                  _isSaving ? 'Sending Request...' : 'Confirm Booking',
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
