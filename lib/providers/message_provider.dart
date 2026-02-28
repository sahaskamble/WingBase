import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/chat_service.dart';

class MessageProvider extends ChangeNotifier {
  final String chatId;
  MessageProvider(this.chatId);

  List<RecordModel> _messages = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _perPage = 50;

  List<String> _typingUserIds = [];
  Timer? _typingTimer;
  bool _isTyping = false;

  RecordModel? _replyTo;

  List<RecordModel> get messages => _messages;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  List<String> get typingUserIds => _typingUserIds;
  RecordModel? get replyTo => _replyTo;

  // ─── Init ─────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadMessages();
    await _subscribeToMessages();
    await ChatService.markChatAsRead(chatId);
  }

  // ─── Load ─────────────────────────────────────────────────────────

  Future<void> loadMessages() async {
    _loading = true;
    notifyListeners();
    try {
      _messages = await ChatService.fetchMessages(
        chatId,
        page: 1,
        perPage: _perPage,
      );
      _page = 1;
      _hasMore = _messages.length == _perPage;
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMoreMessages() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      _page++;
      final older = await ChatService.fetchMessages(
        chatId,
        page: _page,
        perPage: _perPage,
      );
      _messages.insertAll(0, older);
      _hasMore = older.length == _perPage;
    } catch (_) {
      _page--;
    }
    _loadingMore = false;
    notifyListeners();
  }

  // ─── Realtime ─────────────────────────────────────────────────────

  Future<void> _subscribeToMessages() async {
    await ChatService.subscribeToMessages(chatId, (record, action) async {
      if (record == null) return;

      if (action == 'create') {
        if (!_messages.any((m) => m.id == record.id)) {
          _messages.add(record);
        }
        if (record.getStringValue('senderId') != AuthService.currentUserId) {
          await ChatService.updateMessageStatus(record.id, 'read');
        }
        notifyListeners();
      } else if (action == 'update') {
        final idx = _messages.indexWhere((m) => m.id == record.id);
        if (idx != -1) {
          _messages[idx] = record;
          notifyListeners();
        }
      } else if (action == 'delete') {
        _messages.removeWhere((m) => m.id == record.id);
        notifyListeners();
      }
    });
  }

  // ─── Send Text ────────────────────────────────────────────────────

  Future<void> sendText(String content) async {
    if (content.trim().isEmpty) return;
    final replyId = _replyTo?.id;
    clearReply();
    stopTyping();
    try {
      await ChatService.sendTextMessage(
        chatId: chatId,
        content: content.trim(),
        replyToId: replyId,
      );
    } catch (_) {}
  }

  // ─── Send Image ───────────────────────────────────────────────────

  Future<void> sendImage(String filePath) async {
    try {
      await ChatService.sendImageMessage(
        chatId: chatId,
        imageFile: File(filePath),
        replyToId: _replyTo?.id,
      );
      clearReply();
    } catch (_) {}
  }

  // ─── Send Video ───────────────────────────────────────────────────

  Future<void> sendVideo(String filePath) async {
    try {
      await ChatService.sendVideoMessage(
        chatId: chatId,
        videoFile: File(filePath),
        replyToId: _replyTo?.id,
      );
      clearReply();
    } catch (_) {}
  }

  // ─── Send Audio ───────────────────────────────────────────────────

  Future<void> sendAudio(String filePath) async {
    try {
      await ChatService.sendAudioMessage(
        chatId: chatId,
        audioFile: File(filePath),
        replyToId: _replyTo?.id,
      );
      clearReply();
    } catch (_) {}
  }

  // ─── Delete ───────────────────────────────────────────────────────

  Future<void> deleteMessage(String messageId) async {
    await ChatService.deleteMessage(messageId);
  }

  // ─── Typing ──────────────────────────────────────────────────────

  void onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ChatService.setTyping(chatId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), stopTyping);
  }

  void stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      ChatService.setTyping(chatId, false);
    }
    _typingTimer?.cancel();
  }

  void updateTypingUsers(List<String> userIds) {
    _typingUserIds = userIds
        .where((id) => id != AuthService.currentUserId)
        .toList();
    notifyListeners();
  }

  // ─── Reply ────────────────────────────────────────────────────────

  void setReply(RecordModel message) {
    _replyTo = message;
    notifyListeners();
  }

  void clearReply() {
    _replyTo = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTyping();
    ChatService.unsubscribeFromMessages(chatId);
    super.dispose();
  }
}
