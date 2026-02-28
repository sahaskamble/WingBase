import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/pb_client.dart';

class PresenceService {
  static Timer? _heartbeatTimer;
  static UnsubscribeFunc? _presenceUnsub;

  // Cache: userId -> presence record
  static final Map<String, RecordModel> _cache = {};

  // Own presence -----------------------------------

  // Call once after login. Sets online = true and starts heartbeat.
  static Future<void> goOnline() async {
    final myId = AuthService.currentUserId;
    if (myId.isEmpty) return;

    await _upsertPresence(isOnline: true);

    // Heartbeat every 30s to keep lastseen fresh
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _upsertPresence(isOnline: true);
    });
  }

  /// Call on logout or app background. Sets online = false.
  static Future<void> goOffline() async {
    _heartbeatTimer?.cancel();
    await _upsertPresence(isOnline: false);
  }

  static Future<void> _upsertPresence({required bool isOnline}) async {
    final myId = AuthService.currentUserId;
    if (myId.isEmpty) return;
    try {
      // Try to find existing record
      final existing = await pb
          .collection('presence')
          .getFirstListItem('userId = "$myId"');
      await pb
          .collection('presence')
          .update(
            existing.id,
            body: {
              'isOnline': isOnline,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
          );
    } catch (_) {
      // No record yet — create one
      try {
        await pb
            .collection('presence')
            .create(
              body: {
                'userId': myId,
                'isOnline': isOnline,
                'lastSeen': DateTime.now().toUtc().toIso8601String(),
              },
            );
      } catch (_) {}
    }
  }

  // ─── Fetch another user's presence ───────────────────────────────

  static Future<RecordModel?> fetchPresence(String userId) async {
    try {
      final record = await pb
          .collection('presence')
          .getFirstListItem('userId = "$userId"');
      _cache[userId] = record;
      return record;
    } catch (_) {
      return null;
    }
  }

  static RecordModel? getCached(String userId) => _cache[userId];

  /// Returns human-readable last seen string.
  /// e.g. "Online", "Last seen today at 3:42 PM", "Last seen yesterday"
  static String formatPresence(RecordModel? presence) {
    if (presence == null) return '';

    final isOnline = presence.getBoolValue('isOnline');
    if (isOnline) return 'Online';

    final lastSeenStr = presence.getStringValue('lastSeen');
    if (lastSeenStr.isEmpty) return 'Last seen recently';

    try {
      final lastSeen = DateTime.parse(lastSeenStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 1) return 'Last seen just now';
      if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';

      final timeStr = _formatTime(lastSeen);

      if (diff.inDays == 0) return 'Last seen today at $timeStr';
      if (diff.inDays == 1) return 'Last seen yesterday at $timeStr';
      if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return 'Last seen ${days[lastSeen.weekday - 1]} at $timeStr';
      }
      return 'Last seen ${lastSeen.day}/${lastSeen.month}/${lastSeen.year % 100}';
    } catch (_) {
      return 'Last seen recently';
    }
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  // ─── Subscribe to a user's presence changes ──────────────────────

  /// Subscribe to presence changes for a specific user.
  /// Returns an unsubscribe function — call it when leaving ChatScreen.
  static Future<UnsubscribeFunc?> subscribeToPresence(
    String userId,
    void Function(RecordModel presence) onUpdate,
  ) async {
    try {
      final record = await pb
          .collection('presence')
          .getFirstListItem('userId = "$userId"');
      _cache[userId] = record;
      onUpdate(record); // emit initial state immediately

      return await pb.collection('presence').subscribe(record.id, (event) {
        if (event.record != null) {
          _cache[userId] = event.record!;
          onUpdate(event.record!);
        }
      });
    } catch (_) {
      return null;
    }
  }

  // ─── Cleanup ──────────────────────────────────────────────────────

  static void dispose() {
    _heartbeatTimer?.cancel();
    _presenceUnsub?.call();
    _cache.clear();
  }
}
