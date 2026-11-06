import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_model.dart';

class SupportRepository {
  SupportRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  static const categories = [
    'Account & Login',
    'Business & Listings',
    'Bookings',
    'Verification',
    'Promotions & Payments',
    'Technical Issue',
    'Other',
  ];

  String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<List<SupportFaq>> getFaqs() async {
    final rows = await _client
        .from('published_support_faqs')
        .select()
        .eq('audience', 'vendor')
        .order('sort_order');
    return rows.map(SupportFaq.fromMap).toList();
  }

  Future<SupportSettings> getSettings() async {
    final row = await _client
        .from('support_settings')
        .select()
        .eq('audience', 'vendor')
        .maybeSingle();
    return row == null ? const SupportSettings() : SupportSettings.fromMap(row);
  }

  Future<List<SupportTicket>> getTickets({String? ticketId}) async {
    final data = await _client.rpc(
      'get_vendor_support_tickets',
      params: {'p_ticket_id': ticketId},
    );
    return (data as List)
        .map(
          (row) => SupportTicket.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final data = await _client.rpc(
      'get_vendor_support_messages',
      params: {'p_ticket_id': ticketId},
    );
    return (data as List)
        .map(
          (row) =>
              SupportMessage.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<SupportTicket> createTicket({
    required String requestId,
    required String category,
    required String subject,
    required String description,
    XFile? screenshot,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Please log in again.');
    // A retry reuses the same ID; recover a successful earlier submission first.
    final existing = await getTickets(ticketId: requestId);
    if (existing.isNotEmpty) return existing.first;
    String? path;
    if (screenshot != null) {
      final bytes = await screenshot.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Choose a screenshot smaller than 5 MB.');
      }
      final extension = screenshot.name.split('.').last.toLowerCase();
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (mime == null) {
        throw Exception('Choose a JPG, PNG or WebP screenshot.');
      }
      path =
          '${user.id}/$requestId/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage
          .from('support-attachments')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime),
          );
    }
    try {
      final data = await _client.rpc(
        'create_vendor_support_ticket',
        params: {
          'p_request_id': requestId,
          'p_category': category,
          'p_subject': subject.trim(),
          'p_description': description.trim(),
          'p_screenshot_path': path,
        },
      );
      final row = data is List ? data.single : data;
      return SupportTicket.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      // A timeout can happen after commit: recover before removing its attachment.
      try {
        final recovered = await getTickets(ticketId: requestId);
        if (recovered.isNotEmpty) return recovered.first;
        if (path != null) {
          await _client.storage.from('support-attachments').remove([path]);
        }
      } catch (_) {
        /* Keep the attachment if commit status cannot be established. */
      }
      rethrow;
    }
  }

  Future<void> reply(String ticketId, String body) async {
    await _client.rpc(
      'reply_vendor_support_ticket',
      params: {'p_ticket_id': ticketId, 'p_body': body.trim()},
    );
  }

  Future<String> attachmentUrl(String path) =>
      _client.storage.from('support-attachments').createSignedUrl(path, 300);
}
