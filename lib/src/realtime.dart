import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaploeRealtimeSubscription {
  final RealtimeChannel _channel;

  TaploeRealtimeSubscription._(this._channel);

  static TaploeRealtimeSubscription forProfile({
    required String profileId,
    required VoidCallback onRefresh,
  }) {
    final channel =
        Supabase.instance.client.channel('taploe-profile-$profileId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'analytics_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: profileId,
            ),
            callback: (_) => onRefresh(),
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'leads',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: profileId,
            ),
            callback: (_) => onRefresh(),
          )
          ..subscribe();

    return TaploeRealtimeSubscription._(channel);
  }

  static TaploeRealtimeSubscription forNotifications({
    required String userId,
    required VoidCallback onRefresh,
  }) {
    final channel =
        Supabase.instance.client.channel('taploe-notifications-$userId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => onRefresh(),
          )
          ..subscribe();

    return TaploeRealtimeSubscription._(channel);
  }

  Future<void> close() async {
    await Supabase.instance.client.removeChannel(_channel);
  }
}
