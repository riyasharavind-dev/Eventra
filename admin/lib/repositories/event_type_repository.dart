import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_type_model.dart';

class EventTypeRepository {
  final SupabaseClient supabase;

  EventTypeRepository({
    SupabaseClient? supabase,
  }) : supabase =
            supabase ?? Supabase.instance.client;

  // ============================================================
  // GET ALL
  // ============================================================

  Future<List<EventTypeModel>> getEventTypes() async {
    final response = await supabase
        .from('event_types')
        .select()
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map(
          (item) => EventTypeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<EventTypeModel> createEventType(
    EventTypeModel eventType,
  ) async {
    final response = await supabase
        .from('event_types')
        .insert(
          eventType.toInsertMap(),
        )
        .select()
        .single();

    return EventTypeModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<EventTypeModel> updateEventType(
    EventTypeModel eventType,
  ) async {
    final response = await supabase
        .from('event_types')
        .update(
          eventType.toUpdateMap(),
        )
        .eq('id', eventType.id)
        .select()
        .single();

    return EventTypeModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // TOGGLE ACTIVE
  // ============================================================

  Future<void> toggleEventType(
    EventTypeModel eventType,
  ) async {
    await supabase
        .from('event_types')
        .update({
          'is_active': !eventType.isActive,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', eventType.id);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deleteEventType(
    String id,
  ) async {
    await supabase
        .from('event_types')
        .delete()
        .eq('id', id);
  }
}