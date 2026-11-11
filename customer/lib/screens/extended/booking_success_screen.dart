import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.bookingIds});
  final List<String> bookingIds;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      centerTitle: true,
      title: Text(
        AppSettingsScope.translate(
          context,
          "customer.booking_requested.1a20dcf2",
        ),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF17171B),
        ),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      elevation: 0,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppSettingsScope.translate(
            context,
            "customer.your_requests_have_been_sent.1940874e",
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Text(
            AppSettingsScope.translate(
              context,
              "customer.each_vendor_will_review_their_booking_track_a.fd37c7c2",
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF73737D),
            ),
          ),
        ),
        if (bookingIds.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0EDF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF80152C).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < bookingIds.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFF0EDF0),
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E8EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.tag_rounded,
                        color: Color(0xFF80152C),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      '#${bookingIds[i]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: AppSettingsScope.translate(
                        context,
                        "customer.copy_booking_id.fcfec0c8",
                      ),
                      icon: const Icon(
                        Icons.copy_outlined,
                        color: AppIconColors.standard,
                        size: 20,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: bookingIds[i]));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Booking ID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 28),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF80152C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppSettingsScope.translate(context, "customer.done.11a6767d"),
            ),
          ),
        ),
      ],
    ),
  );
}
