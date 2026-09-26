import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_model.dart';

class CustomerRepository {
  CustomerRepository();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // GET ALL CUSTOMERS
  // ============================================================

  Future<List<CustomerModel>> getCustomers() async {
    final response = await _supabase
        .from('customers')
        .select(
          'id, name, email, created_at',
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => CustomerModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SINGLE CUSTOMER
  // ============================================================

  Future<CustomerModel> getCustomer(
    String customerId,
  ) async {
    final response = await _supabase
        .from('customers')
        .select(
          'id, name, email, created_at',
        )
        .eq('id', customerId)
        .single();

    return CustomerModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // DELETE CUSTOMER
  // ============================================================

  Future<void> deleteCustomer(
    String customerId,
  ) async {
    await _supabase
        .from('customers')
        .delete()
        .eq('id', customerId);
  }
}