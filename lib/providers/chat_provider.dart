import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/chat_service.dart';
import 'package:wingbase/services/pb_client.dart';

class ChatProvider extends ChangeNotifier {
  List<RecordModel> _chats = [];
  bool _loading = false;
  String? _error;

  // chatId → unread count
  final Map<String, int> _unreadCounts = {};

  List<RecordModel> get chats => _chats;
  bool get loading => _loading;
  String? get error => _error;

  int unreadCount(String chatId) => _unreadCounts[chatId] ?? 0;
  int get totalUnread => _unreadCounts.values.fold(0, (sum, c) => sum + c);

  // ─── Init ─────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadChats();
    await _loadUnreadCounts();
    await _subscribeToChats();
    await _subscribeToMessagesForBadge();
  }

  // ─── Load Chats ───────────────────────────────────────────────────

  Future<void> loadChats() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _chats = await ChatService.fetchChats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Unread Counts ────────────────────────────────────────────────

  Future<void> _loadUnreadCounts() async {
    final myId = AuthService.currentUserId;
    for (final chat in _chats) {
      try {
        final result = await pb
            .collection('messages')
            .getList(
              perPage: 1,
              filter:
                  'chatId = "${chat.id}" && senderId != "$myId" && status != "read"',
            );
        _unreadCounts[chat.id] = result.totalItems;
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Call when user opens a chat to clear its badge.
  void markChatRead(String chatId) {
    if ((_unreadCounts[chatId] ?? 0) != 0) {
      _unreadCounts[chatId] = 0;
      notifyListeners();
    }
  }

  // ─── Realtime: chat list ──────────────────────────────────────────

  Future<void> _subscribeToChats() async {
    await ChatService.subscribeToChatList((record, action) {
      if (record == null) return;

      if (action == 'create') {
        final participants = record.getListValue<String>('participants');
        if (participants.contains(AuthService.currentUserId)) {
          _chats.insert(0, record);
          notifyListeners();
        }
      } else if (action == 'update') {
        final idx = _chats.indexWhere((c) => c.id == record.id);
        if (idx != -1) {
          _chats[idx] = record;
          _chats.sort((a, b) {
            final aTime = a.getStringValue('lastMessageTime');
            final bTime = b.getStringValue('lastMessageTime');
            return bTime.compareTo(aTime);
          });
          notifyListeners();
        }
      } else if (action == 'delete') {
        _chats.removeWhere((c) => c.id == record.id);
        notifyListeners();
      }
    });
  }

  // ─── Realtime: new messages → increment badge ────────────────────

  Future<void> _subscribeToMessagesForBadge() async {
    final myId = AuthService.currentUserId;
    await pb.collection('messages').subscribe('*', (event) {
      final record = event.record;
      if (record == null || event.action != 'create') return;

      final senderId = record.getStringValue('senderId');
      final chatId = record.getStringValue('chatId');

      if (senderId != myId) {
        _unreadCounts[chatId] = (_unreadCounts[chatId] ?? 0) + 1;
        notifyListeners();
      }
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String getChatName(RecordModel chat) {
    if (chat.getBoolValue('isGroup')) {
      return chat.getStringValue('groupName');
    }
    final participantsExpand = chat.expand['participants'];
    if (participantsExpand == null) return 'Unknown';

    final dyn = participantsExpand as dynamic;
    if (dyn is List && dyn.isNotEmpty) {
      for (final p in dyn) {
        if (p is RecordModel && p.id != AuthService.currentUserId) {
          return p.getStringValue('name');
        }
      }
    }
    return 'Unknown';
  }

  String getChatAvatar(RecordModel chat) {
    if (chat.getBoolValue('isGroup')) {
      final filename = chat.getStringValue('groupIcon');
      return filename.isEmpty ? '' : ChatService.fileUrl(chat, filename);
    }
    final participantsExpand = chat.expand['participants'];
    if (participantsExpand == null) return '';

    final dyn = participantsExpand as dynamic;
    if (dyn is List && dyn.isNotEmpty) {
      for (final p in dyn) {
        if (p is RecordModel && p.id != AuthService.currentUserId) {
          return ChatService.avatarUrl(p);
        }
      }
    }
    return '';
  }

  RecordModel? getOtherUser(RecordModel chat) {
    final participantsExpand = chat.expand['participants'];
    if (participantsExpand == null) return null;

    final dyn = participantsExpand as dynamic;
    if (dyn is List && dyn.isNotEmpty) {
      for (final p in dyn) {
        if (p is RecordModel && p.id != AuthService.currentUserId) {
          return p;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    ChatService.unsubscribeAll();
    pb.collection('messages').unsubscribe('*');
    super.dispose();
  }
}
