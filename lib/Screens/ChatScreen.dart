import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:wingbase/components/ui/user_avatar.dart';
import 'package:wingbase/providers/message_provider.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/presence_service.dart';
import 'package:wingbase/utils/colors.dart';
import 'package:wingbase/components/ui/MessageBubble.dart';

class ChatScreen extends StatelessWidget {
  final String chatId;
  final String chatName;
  final String avatarUrl;
  final bool isGroup;
  final RecordModel? otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.avatarUrl,
    this.isGroup = false,
    this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MessageProvider(chatId)..init(),
      child: _ChatScreenBody(
        chatId: chatId,
        chatName: chatName,
        avatarUrl: avatarUrl,
        isGroup: isGroup,
        otherUser: otherUser,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChatScreenBody extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String avatarUrl;
  final bool isGroup;
  final RecordModel? otherUser;

  const _ChatScreenBody({
    required this.chatId,
    required this.chatName,
    required this.avatarUrl,
    required this.isGroup,
    this.otherUser,
  });

  @override
  State<_ChatScreenBody> createState() => _ChatScreenBodyState();
}

class _ChatScreenBodyState extends State<_ChatScreenBody> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showSend = false;

  // Voice recording
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;

  // Presence
  String _presenceText = '';
  UnsubscribeFunc? _presenceUnsub;

  @override
  void initState() {
    super.initState();

    _textCtrl.addListener(() {
      final hasText = _textCtrl.text.trim().isNotEmpty;
      if (hasText != _showSend) setState(() => _showSend = hasText);
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <= 100) {
        context.read<MessageProvider>().loadMoreMessages();
      }
    });

    // Subscribe to other user's presence for 1-on-1 chats
    if (!widget.isGroup && widget.otherUser != null) {
      _subscribeToPresence();
    }
  }

  Future<void> _subscribeToPresence() async {
    _presenceUnsub = await PresenceService.subscribeToPresence(
      widget.otherUser!.id,
      (presence) {
        if (mounted) {
          setState(
            () => _presenceText = PresenceService.formatPresence(presence),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _presenceUnsub?.call();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    try {
      final tempDir = Directory.systemTemp;
      final path =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordingStartTime = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();

      if (send && path != null && mounted) {
        final duration = _recordingStartTime != null
            ? DateTime.now().difference(_recordingStartTime!).inSeconds
            : 0;

        if (duration >= 1) {
          await context.read<MessageProvider>().sendAudio(path);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Recording too short')));
        }
      }
    } catch (e) {
      // Ignore errors
    } finally {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingStartTime = null;
      });
    }
  }

  void _cancelRecording() {
    _stopRecording(send: false);
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (animated) {
      _scrollCtrl.animateTo(
        max,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(max);
    }
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text;
    _textCtrl.clear();
    await context.read<MessageProvider>().sendText(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _showMediaPicker() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndSend(isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndSend(isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSend({required bool isVideo}) async {
    final picker = ImagePicker();
    if (isVideo) {
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null || !mounted) return;
      await context.read<MessageProvider>().sendVideo(picked.path);
    } else {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      await context.read<MessageProvider>().sendImage(picked.path);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<MessageProvider>();

    // Auto-scroll on new message if near bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 120) {
        _scrollToBottom(animated: false);
      }
    });

    return Scaffold(
      backgroundColor: isDark
          ? WingBaseColors.darkScaffoldBg
          : WingBaseColors.lightScaffoldBg,

      // ─── AppBar ──────────────────────────────────────────────────
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Avatar
            UserAvatar(
              imageUrl: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
              name: widget.chatName,
              radius: 18,
              showOnlineIndicator: !widget.isGroup,
              isOnline: _presenceText == 'Online',
            ),
            const SizedBox(width: 10),

            // Name + presence / typing
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (provider.typingUserIds.isNotEmpty)
                    Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: WingBaseColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (_presenceText.isNotEmpty)
                    Text(
                      _presenceText,
                      style: TextStyle(
                        fontSize: 12,
                        color: _presenceText == 'Online'
                            ? const Color(0xFF4CAF50)
                            : (isDark
                                  ? WingBaseColors.darkTextSecondary
                                  : WingBaseColors.lightTextSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {},
          ),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),

      // ─── Body ────────────────────────────────────────────────────
      body: Column(
        children: [
          if (provider.loadingMore)
            LinearProgressIndicator(
              color: WingBaseColors.primary,
              backgroundColor: Colors.transparent,
            ),

          // Recording indicator
          if (_isRecording) _buildRecordingIndicator(isDark),

          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = provider.messages[index];
                      final prev = index > 0
                          ? provider.messages[index - 1]
                          : null;
                      final showDate =
                          prev == null ||
                          !_isSameDay(
                            prev.created.toString(),
                            msg.created.toString(),
                          );

                      return Column(
                        children: [
                          if (showDate)
                            _DateSeparator(dateStr: msg.created.toString()),
                          GestureDetector(
                            onHorizontalDragEnd: (d) {
                              if ((d.primaryVelocity ?? 0) > 200) {
                                provider.setReply(msg);
                              }
                            },
                            child: MessageBubble(
                              message: msg,
                              showAvatar: widget.isGroup,
                              onLongPress: () =>
                                  _showMessageOptions(context, msg),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          if (provider.replyTo != null)
            _ReplyBar(
              message: provider.replyTo!,
              onDismiss: provider.clearReply,
            ),

          _buildInputBar(context, isDark, provider),
        ],
      ),
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    bool isDark,
    MessageProvider provider,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        6,
        8,
        MediaQuery.of(context).padding.bottom + 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? WingBaseColors.darkAppBar : WingBaseColors.lightAppBar,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment (image + video picker)
          IconButton(
            onPressed: _showMediaPicker,
            icon: Icon(
              Icons.attach_file,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark
                    ? WingBaseColors.darkCardBg
                    : WingBaseColors.lightCardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(
                    color: isDark
                        ? WingBaseColors.darkTextHint
                        : WingBaseColors.lightTextHint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onChanged: provider.onTextChanged,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send / Mic button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _showSend
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: _sendText,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: WingBaseColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: _startRecording,
                    onLongPress: _startRecording,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: WingBaseColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, RecordModel message) {
    final isMe =
        message.getStringValue('senderId') == AuthService.currentUserId;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                context.read<MessageProvider>().setReply(message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await context.read<MessageProvider>().deleteMessage(
                    message.id,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade100,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Recording...',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(onPressed: _cancelRecording, child: const Text('Cancel')),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _stopRecording(send: true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Text(
        'No messages yet.\nSay hello! 👋',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark
              ? WingBaseColors.darkTextSecondary
              : WingBaseColors.lightTextSecondary,
          fontSize: 15,
        ),
      ),
    );
  }

  bool _isSameDay(String aStr, String bStr) {
    try {
      final a = DateTime.parse(aStr).toLocal();
      final b = DateTime.parse(bStr).toLocal();
      return a.year == b.year && a.month == b.month && a.day == b.day;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reply bar
// ─────────────────────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  final RecordModel message;
  final VoidCallback onDismiss;
  const _ReplyBar({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final senderExpand = message.expand['senderId'];
    String senderName = 'Unknown';

    final senderRecord = senderExpand as dynamic;
    if (senderRecord is RecordModel) {
      senderName = senderRecord.getStringValue('name');
    } else if (senderRecord is List && senderRecord.length > 0) {
      final first = senderRecord[0];
      if (first is RecordModel) {
        senderName = (first as RecordModel).getStringValue('name');
      }
    }

    final content = switch (message.getStringValue('type')) {
      'image' => '📷 Photo',
      'video' => '🎥 Video',
      _ => message.getStringValue('content'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? WingBaseColors.darkCardBg : WingBaseColors.lightCardBg,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: WingBaseColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: WingBaseColors.primary,
                  ),
                ),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? WingBaseColors.darkTextSecondary
                        : WingBaseColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date separator
// ─────────────────────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String dateStr;
  const _DateSeparator({required this.dateStr});

  DateTime get date => DateTime.tryParse(dateStr) ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final local = date.toLocal();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final label = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Yesterday'
        : '${local.day} ${months[local.month - 1]} ${local.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? WingBaseColors.darkCardBg
                : WingBaseColors.lightCardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
