import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';
import '../../widgets/trial/sample_booking_card.dart';

/// No repositories, remote images, contacts, notifications or real booking IDs.
class BookingPracticeScreen extends StatefulWidget {
  const BookingPracticeScreen({super.key});
  @override
  State<BookingPracticeScreen> createState() => _BookingPracticeScreenState();
}

class _BookingPracticeScreenState extends State<BookingPracticeScreen> {
  String _status = 'pending';
  bool _opened = false;
  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  Future<void> _details() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Sample booking details', 'மாதிரி முன்பதிவு விவரங்கள்'),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t(
                  'Wedding decoration\nSample customer\n10:00 AM – 2:00 PM\nSample venue, Chennai\n100 guests\n₹25,000\nRequest: simple floral stage setup.',
                  'திருமண அலங்காரம்\nமாதிரி வாடிக்கையாளர்\nகாலை 10 – மதியம் 2\nமாதிரி அரங்கம், சென்னை\n100 விருந்தினர்கள்\n₹25,000\nகோரிக்கை: எளிய மலர் மேடை அலங்காரம்.',
                ),
                style: const TextStyle(height: 1.9),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('Details checked', 'விவரங்களைப் பார்த்தேன்')),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _opened = true);
  }

  Future<void> _decide(String status) async {
    if (!_opened) {
      await _details();
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(
            status == 'accepted'
                ? 'Accept this sample?'
                : 'Reject this sample?',
            status == 'accepted'
                ? 'மாதிரியை ஏற்கவா?'
                : 'மாதிரியை நிராகரிக்கவா?',
          ),
        ),
        content: Text(
          t(
            'Practice only. No customer is notified.',
            'பயிற்சி மட்டும். வாடிக்கையாளருக்கு அறிவிப்பு செல்லாது.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Cancel', 'ரத்து')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Confirm', 'உறுதி')),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Booking practice', 'முன்பதிவு பயிற்சி'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t('PRACTICE MODE • SAMPLE DATA', 'பயிற்சி முறை • மாதிரி தகவல்கள்'),
            style: const TextStyle(
              color: Color(0xFF80152C),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              _opened
                  ? 'Now try Accept or Reject. In the real app, only accept work you can fulfil.'
                  : 'Tap the card arrow and review the details first.',
              _opened
                  ? 'இப்போது ஏற்க அல்லது நிராகரிக்க முயற்சிக்கவும். உண்மையான கோரிக்கையில் உங்களால் செய்யக்கூடிய பணியை மட்டும் ஏற்கவும்.'
                  : 'முதலில் அம்புக்குறியைத் தொட்டு விவரங்களைப் பாருங்கள்.',
            ),
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          SampleBookingCard(
            status: _status,
            onOpen: _details,
            onAccept: () => _decide('accepted'),
            onReject: () => _decide('rejected'),
            onComplete: () => setState(() => _status = 'completed'),
          ),
          if (_status != 'pending') ...[
            const SizedBox(height: 12),
            Text(
              t(
                'Nice — the sample status changed. Real booking actions update the customer too. Mark Completed only after the event is finished.',
                'மாதிரி நிலை மாறிவிட்டது. உண்மையான முன்பதிவில் வாடிக்கையாளருக்கும் தகவல் செல்லும். நிகழ்வு முடிந்த பிறகு மட்டுமே Completed என்பதைத் தேர்வு செய்யுங்கள்.',
              ),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('practice-done'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('Practice complete', 'பயிற்சி முடிந்தது')),
            ),
            TextButton(
              onPressed: () => setState(() {
                _status = 'pending';
                _opened = false;
              }),
              child: Text(t('Try again', 'மீண்டும் முயற்சி')),
            ),
          ],
        ],
      ),
    ),
  );
}
