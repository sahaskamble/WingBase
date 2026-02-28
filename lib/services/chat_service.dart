import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/pb_client.dart';

class ChatService {
  // ─── Subscriptions (kept so we can cancel them) ──────────────────
  static UnsubscribeFunc? _chatsUnsub;
  static final Map<String, UnsubscribeFunc> _messageUnsubs = {};

  // ─── Avatar URL helper ───────────────────────────────────────────
  static String avatarUrl(RecordModel user) {
    final filename = user.getStringValue('avatar');
    if (filename.isEmpty) return '';
    return '${pbUrl}/api/files/users/${user.id}/$filename';
  }

  static String fileUrl(RecordModel record, String filename, {String? thumb}) {
    if (filename.isEmpty) return '';

    // Determine collection name based on record type
    // For messages, the collection is 'messages' (pbc_2605467279)
    String collection = 'messages';

    // Check if this is a user record
    if (record.collectionId == '_pb_users_auth_' ||
        record.collectionId.contains('users')) {
      collection = 'users';
    }

    String url = '${pbUrl}/api/files/$collection/${record.id}/$filename';
    if (thumb != null) {
      url += '?thumb=$thumb';
    }
    return url;
  }

  // ─── CHATS ───────────────────────────────────────────────────────

  /// Fetch all chats the current user is part of, sorted by lastMessageTime.
  static Future<List<RecordModel>> fetchChats() async {
    return await pb
        .collection('chats')
        .getFullList(
          sort: '-lastMessageTime',
          expand: 'participants,lastMessageBy',
          filter: 'participants.id ?= "${AuthService.currentUserId}"',
        );
  }

  /// Create a new 1-on-1 chat or return existing one.
  static Future<RecordModel> getOrCreateDirectChat(String otherUserId) async {
    final myId = AuthService.currentUserId;

    // Check if chat already exists
    try {
      final existing = await pb
          .collection('chats')
          .getFirstListItem(
            'participants.id ?= "$myId" && participants.id ?= "$otherUserId" && isGroup = false',
            expand: 'participants',
          );
      return existing;
    } catch (_) {
      // Doesn't exist, create it
    }

    return await pb
        .collection('chats')
        .create(
          body: {
            'participants': [myId, otherUserId],
            'isGroup': false,
          },
          expand: 'participants',
        );
  }

  /// Create a group chat.
  static Future<RecordModel> createGroupChat({
    required String name,
    required List<String> participantIds,
    File? icon,
  }) async {
    final myId = AuthService.currentUserId;
    final allParticipants = [myId, ...participantIds];

    final body = {
      'participants': allParticipants,
      'isGroup': true,
      'groupName': name,
      'groupAdmin': myId,
    };

    if (icon != null) {
      final ext = icon.path.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final files = [
        await http.MultipartFile.fromPath(
          'groupIcon',
          icon.path,
          contentType: MediaType.parse(mimeType),
        ),
      ];
      return await pb
          .collection('chats')
          .create(body: body, files: files, expand: 'participants');
    }

    return await pb
        .collection('chats')
        .create(body: body, expand: 'participants');
  }

  // ─── MESSAGES ────────────────────────────────────────────────────

  /// Fetch messages for a chat (paginated, newest last).
  static Future<List<RecordModel>> fetchMessages(
    String chatId, {
    int page = 1,
    int perPage = 50,
  }) async {
    final result = await pb
        .collection('messages')
        .getList(
          page: page,
          perPage: perPage,
          sort: 'created',
          filter: 'chatId = "$chatId" && isDeleted = false',
          expand: 'senderId,replyTo,replyTo.senderId',
        );
    return result.items;
  }

  /// Send a text message.
  static Future<RecordModel> sendTextMessage({
    required String chatId,
    required String content,
    String? replyToId,
  }) async {
    final myId = AuthService.currentUserId;

    final record = await pb
        .collection('messages')
        .create(
          body: {
            'chatId': chatId,
            'senderId': myId,
            'content': content,
            'type': 'text',
            'status': 'sent',
            'replyTo': ?replyToId,
          },
        );

    // Update chat's last message metadata
    await _updateChatLastMessage(
      chatId: chatId,
      content: content,
      senderId: myId,
    );

    return record;
  }

  /// Send an image message.
  static Future<RecordModel> sendImageMessage({
    required String chatId,
    required File imageFile,
    String? replyToId,
  }) async {
    final myId = AuthService.currentUserId;
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final files = [
      await http.MultipartFile.fromPath(
        'mediaFile',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ),
    ];

    final record = await pb
        .collection('messages')
        .create(
          body: {
            'chatId': chatId,
            'senderId': myId,
            'content': '',
            'type': 'image',
            'status': 'sent',
            'replyTo': ?replyToId,
          },
          files: files,
        );

    await _updateChatLastMessage(
      chatId: chatId,
      content: '📷 Photo',
      senderId: myId,
    );

    return record;
  }

  /// Send a video message.
  static Future<RecordModel> sendVideoMessage({
    required String chatId,
    required File videoFile,
    String? replyToId,
  }) async {
    final myId = AuthService.currentUserId;
    final ext = videoFile.path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      '3gp' => 'video/3gpp',
      _ => 'video/mp4',
    };

    final files = [
      await http.MultipartFile.fromPath(
        'mediaFile',
        videoFile.path,
        contentType: MediaType.parse(mimeType),
      ),
    ];

    final record = await pb
        .collection('messages')
        .create(
          body: {
            'chatId': chatId,
            'senderId': myId,
            'content': '',
            'type': 'video',
            'status': 'sent',
            'replyTo': ?replyToId,
          },
          files: files,
        );

    await _updateChatLastMessage(
      chatId: chatId,
      content: '🎥 Video',
      senderId: myId,
    );

    return record;
  }

  /// Send an audio message.
  static Future<RecordModel> sendAudioMessage({
    required String chatId,
    required File audioFile,
    String? replyToId,
  }) async {
    final myId = AuthService.currentUserId;
    final ext = audioFile.path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };

    final files = [
      await http.MultipartFile.fromPath(
        'mediaFile',
        audioFile.path,
        contentType: MediaType.parse(mimeType),
      ),
    ];

    final record = await pb
        .collection('messages')
        .create(
          body: {
            'chatId': chatId,
            'senderId': myId,
            'content': '',
            'type': 'audio',
            'status': 'sent',
            'replyTo': replyToId,
          },
          files: files,
        );

    await _updateChatLastMessage(
      chatId: chatId,
      content: '🎤 Audio',
      senderId: myId,
    );

    return record;
  }

  /// Update message status (delivered / read).
  static Future<void> updateMessageStatus(
    String messageId,
    String status,
  ) async {
    await pb.collection('messages').update(messageId, body: {'status': status});
  }

  /// Mark all messages in a chat as read.
  static Future<void> markChatAsRead(String chatId) async {
    final myId = AuthService.currentUserId;
    // Fetch unread messages not sent by me
    final unread = await pb
        .collection('messages')
        .getFullList(
          filter:
              'chatId = "$chatId" && senderId != "$myId" && status != "read"',
        );
    for (final msg in unread) {
      await pb.collection('messages').update(msg.id, body: {'status': 'read'});
    }
  }

  /// Soft-delete a message (sets isDeleted = true).
  static Future<void> deleteMessage(String messageId) async {
    await pb
        .collection('messages')
        .update(messageId, body: {'isDeleted': true});
  }

  // ─── TYPING ──────────────────────────────────────────────────────

  static Future<void> setTyping(String chatId, bool isTyping) async {
    final myId = AuthService.currentUserId;
    final chat = await pb.collection('chats').getOne(chatId);
    final List<dynamic> current = List.from(
      chat.getListValue<String>('typingUsers'),
    );

    if (isTyping && !current.contains(myId)) {
      current.add(myId);
    } else if (!isTyping) {
      current.remove(myId);
    }

    await pb.collection('chats').update(chatId, body: {'typingUsers': current});
  }

  // ─── REALTIME ────────────────────────────────────────────────────

  /// Subscribe to chat list changes (new chats, lastMessage updates).
  static Future<void> subscribeToChatList(
    void Function(RecordModel? record, String action) onEvent,
  ) async {
    await _chatsUnsub?.call();
    _chatsUnsub = await pb
        .collection('chats')
        .subscribe(
          '*',
          (event) => onEvent(event.record, event.action),
          filter: 'participants.id ?= "${AuthService.currentUserId}"',
          expand: 'participants,lastMessageBy',
        );
  }

  /// Subscribe to messages in a specific chat.
  static Future<void> subscribeToMessages(
    String chatId,
    void Function(RecordModel? record, String action) onEvent,
  ) async {
    await _messageUnsubs[chatId]?.call();
    _messageUnsubs[chatId] = await pb
        .collection('messages')
        .subscribe(
          '*',
          (event) => onEvent(event.record, event.action),
          filter: 'chatId = "$chatId"',
          expand: 'senderId,replyTo,replyTo.senderId',
        );
  }

  /// Unsubscribe from a chat's messages.
  static Future<void> unsubscribeFromMessages(String chatId) async {
    await _messageUnsubs[chatId]?.call();
    _messageUnsubs.remove(chatId);
  }

  /// Unsubscribe from everything.
  static Future<void> unsubscribeAll() async {
    await _chatsUnsub?.call();
    for (final unsub in _messageUnsubs.values) {
      await unsub();
    }
    _messageUnsubs.clear();
  }

  // ─── PRIVATE HELPERS ─────────────────────────────────────────────

  static Future<void> _updateChatLastMessage({
    required String chatId,
    required String content,
    required String senderId,
  }) async {
    await pb
        .collection('chats')
        .update(
          chatId,
          body: {
            'lastMessage': content,
            'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
            'lastMessageBy': senderId,
          },
        );
  }

  // ─── USER LOOKUP (for starting new chats) ────────────────────────

  static Future<List<RecordModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    return await pb
        .collection('users')
        .getFullList(
          filter: 'name ~ "$query" || phone ~ "$query" || email ~ "$query"',
        );
  }

  static Future<RecordModel> getUserById(String userId) async {
    return await pb.collection('users').getOne(userId);
  }
}
