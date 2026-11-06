import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_statistics.dart';
import '../models/service_review_model.dart';
import 'review_repository.dart';

class ProfileStatisticsRepository {
  final SupabaseClient db;
  ProfileStatisticsRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  Future<ProfileStatistics> load(String vendorId) async {
    if (db.auth.currentUser?.id != vendorId) {
      throw StateError('Vendor account does not match.');
    }
    final result = await Future.wait<Object>([
      db
          .from('bookings')
          .count(CountOption.exact)
          .eq('vendor_id', vendorId)
          .eq('status', 'completed'),
      ReviewRepository(client: db).summary(vendorId: vendorId),
    ]);
    final total = result[1] as ReviewSummary;
    bool verified = false;
    try {
      final rows = await db
          .from('vendor_verifications')
          .select('status')
          .eq('vendor_id', vendorId)
          .order('updated_at', ascending: false)
          .limit(1);
      verified = rows.isNotEmpty && rows.first['status'] == 'verified';
    } catch (e) {
      debugPrint('Vendor verification badge unavailable: $e');
    }
    return ProfileStatistics(
      completedEvents: result[0] as int,
      reviewCount: total.count,
      rating: total.average,
      verified: verified,
    );
  }
}
