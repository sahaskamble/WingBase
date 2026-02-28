import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/components/ui/user_avatar.dart';
import 'package:wingbase/providers/chat_provider.dart';
import 'package:wingbase/Screens/ChatScreen.dart';
import 'package:wingbase/Pages/NewChatPage.dart';
import 'package:wingbase/Screens/SettingsPage.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/presence_service.dart';
import 'package:wingbase/utils/colors.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with WidgetsBindingObserver {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().init();
      PresenceService.goOnline();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      PresenceService.goOffline();
    } else if (state == AppLifecycleState.resumed) {
      PresenceService.goOnline();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.goOffline();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? WingBaseColors.darkScaffoldBg
          : WingBaseColors.lightScaffoldBg,
      body: chatProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : chatProvider.chats.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: chatProvider.loadChats,
              child: ListView.builder(
                itemCount: chatProvider.chats.length,
                itemBuilder: (context, index) =>
                    _ChatTile(chat: chatProvider.chats[index]),
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 72,
            color: isDark
                ? WingBaseColors.darkTextSecondary
                : WingBaseColors.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? WingBaseColors.darkTextPrimary
                  : WingBaseColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to start a conversation',
            style: TextStyle(
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ChatSearchDelegate(
        chatProvider: context.read<ChatProvider>(),
        onChatSelected: (chat) {
          final chatProvider = context.read<ChatProvider>();
          final isGroup = chat.getBoolValue('isGroup');
          final name = chatProvider.getChatName(chat);
          final avatarUrl = chatProvider.getChatAvatar(chat);
          final otherUser = isGroup ? null : chatProvider.getOtherUser(chat);

          chatProvider.markChatRead(chat.id);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chat.id,
                chatName: name,
                avatarUrl: avatarUrl,
                isGroup: isGroup,
                otherUser: otherUser,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search delegate
// ─────────────────────────────────────────────────────────────────────────────

class _ChatSearchDelegate extends SearchDelegate<RecordModel?> {
  final ChatProvider chatProvider;
  final void Function(RecordModel) onChatSelected;

  _ChatSearchDelegate({
    required this.chatProvider,
    required this.onChatSelected,
  });

  @override
  String get searchFieldLabel => 'Search chats';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.brightness == Brightness.dark
            ? WingBaseColors.darkAppBar
            : WingBaseColors.lightAppBar,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = query.toLowerCase();

    final results = chatProvider.chats.where((chat) {
      final name = chatProvider.getChatName(chat).toLowerCase();
      final lastMsg = chat.getStringValue('lastMessage').toLowerCase();
      return name.contains(q) || lastMsg.contains(q);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No chats found',
          style: TextStyle(
            color: isDark
                ? WingBaseColors.darkTextSecondary
                : WingBaseColors.lightTextSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final chat = results[index];
        final name = chatProvider.getChatName(chat);
        final avatarUrl = chatProvider.getChatAvatar(chat);
        final lastMessage = chat.getStringValue('lastMessage');

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: WingBaseColors.primary.withOpacity(0.15),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: WingBaseColors.primary,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? WingBaseColors.darkTextPrimary
                  : WingBaseColors.lightTextPrimary,
            ),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
          onTap: () {
            onChatSelected(chat);
            close(context, null);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTile extends StatefulWidget {
  final RecordModel chat;
  const _ChatTile({required this.chat});

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    final isGroup = widget.chat.getBoolValue('isGroup');
    if (isGroup) return;

    final chatProvider = context.read<ChatProvider>();
    final otherUser = chatProvider.getOtherUser(widget.chat);
    if (otherUser == null) return;

    final presence = await PresenceService.fetchPresence(otherUser.id);
    if (mounted && presence != null) {
      setState(() => _isOnline = presence.getBoolValue('isOnline'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.read<ChatProvider>();

    final name = chatProvider.getChatName(widget.chat);
    final avatarUrl = chatProvider.getChatAvatar(widget.chat);
    final lastMessage = widget.chat.getStringValue('lastMessage');
    final lastTime = widget.chat.getStringValue('lastMessageTime');
    final isGroup = widget.chat.getBoolValue('isGroup');
    final unread = chatProvider.unreadCount(widget.chat.id);

    // Typing indicator
    final typingUsers = widget.chat.getListValue<String>('typingUsers');
    final myId = AuthService.currentUserId;
    final isTyping = typingUsers.any((id) => id != myId);

    // Last message sender prefix for groups
    String lastMessageDisplay = lastMessage;
    if (isGroup && lastMessage.isNotEmpty) {
      final lastByExpand = widget.chat.expand['lastMessageBy'];
      String senderName = '';
      if (lastByExpand != null) {
        RecordModel? lastBy;
        final dyn = lastByExpand as dynamic;
        if (dyn is List && dyn.length > 0) {
          lastBy = dyn[0] as RecordModel?;
        } else if (dyn is RecordModel) {
          lastBy = dyn;
        }
        if (lastBy != null) {
          senderName = lastBy.getStringValue('name').split(' ').first;
        }
      }
      if (senderName.isNotEmpty) {
        lastMessageDisplay = '$senderName: $lastMessage';
      }
    }

    return InkWell(
      onTap: () {
        // Clear badge before navigating
        chatProvider.markChatRead(widget.chat.id);

        final otherUser = isGroup
            ? null
            : chatProvider.getOtherUser(widget.chat);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: widget.chat.id,
              chatName: name,
              avatarUrl: avatarUrl,
              isGroup: isGroup,
              otherUser: otherUser,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? WingBaseColors.darkDivider
                  : WingBaseColors.lightDivider,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar with online dot
            _AvatarWithOnline(
              name: name,
              avatarUrl: avatarUrl,
              isOnline: !isGroup && _isOnline,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 16,
                            color: isDark
                                ? WingBaseColors.darkTextPrimary
                                : WingBaseColors.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTime.isNotEmpty)
                        Text(
                          _formatTileTime(lastTime),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: unread > 0
                                ? WingBaseColors.primary
                                : (isDark
                                      ? WingBaseColors.darkTextSecondary
                                      : WingBaseColors.lightTextSecondary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: isTyping
                            ? _TypingIndicator()
                            : Text(
                                lastMessageDisplay.isEmpty
                                    ? 'No messages yet'
                                    : lastMessageDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: unread > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  color: unread > 0
                                      ? (isDark
                                            ? WingBaseColors.darkTextPrimary
                                            : WingBaseColors.lightTextPrimary)
                                      : (isDark
                                            ? WingBaseColors.darkTextSecondary
                                            : WingBaseColors
                                                  .lightTextSecondary),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                      ),

                      // ─── Unread badge ───────────────────────────
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: WingBaseColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTileTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) {
        final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}/${dt.year % 100}';
      }
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar with online green dot
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarWithOnline extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final bool isOnline;

  const _AvatarWithOnline({
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
      name: name,
      radius: 26,
      showOnlineIndicator: true,
      isOnline: isOnline,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated typing indicator
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Text(
        'typing...',
        style: TextStyle(
          fontSize: 13,
          color: WingBaseColors.primary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
