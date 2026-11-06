import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_model.dart';
import '../models/vendor_model.dart';
import '../models/booking_model.dart';
import '../models/dashboard_data.dart';
import 'booking_repository.dart';
import 'vendor_repository.dart';

class DashboardRepository {
  final SupabaseClient db;
  DashboardRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  String get uid =>
      db.auth.currentUser?.id ?? (throw StateError('Please sign in again.'));
  Future<List<BusinessModel>> businesses() async =>
      (await db.from('businesses').select().eq('vendor_id', uid).order('name'))
          .map(BusinessModel.fromMap)
          .toList();
  Future<CalendarData> calendar() async {
    final rows = await Future.wait<Object>([
      BookingRepository(client: db).getVendorBookings(uid),
      businesses(),
    ]);
    return CalendarData(
      bookings: rows[0] as List<BookingModel>,
      businesses: rows[1] as List<BusinessModel>,
    );
  }

  Future<DashboardOverview> overview({String business = 'all'}) async =>
      DashboardOverview.fromMap(
        Map<String, dynamic>.from(
          await db.rpc(
            'get_vendor_dashboard_overview',
            params: {
              'p_business_id': business == 'all' || business == 'unassigned'
                  ? null
                  : business,
              'p_unassigned': business == 'unassigned',
            },
          ) as Map,
        ),
      );
  Future<DashboardData> load({String business = 'all'}) async {
    final rows = await Future.wait<Object?>([
      calendar(),
      VendorRepository().getMyVendor(),
      overview(business: business),
    ]);
    final data = rows[0] as CalendarData;
    return DashboardData(
      bookings: data.bookings,
      businesses: data.businesses,
      vendor: rows[1] as VendorModel?,
      overview: rows[2] as DashboardOverview,
    );
  }
}
