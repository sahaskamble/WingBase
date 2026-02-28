import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wingbase/Pages/ChatPage.dart';
import 'package:wingbase/Pages/NewChatPage.dart';
import 'package:wingbase/Screens/ChatScreen.dart';
import 'package:wingbase/Screens/SettingsPage.dart';
import 'package:wingbase/providers/chat_provider.dart';
import 'package:wingbase/utils/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _MessagesTab(),
          _CallsTab(isDark: isDark),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: WingBaseColors.primary,
        unselectedItemColor: isDark
            ? WingBaseColors.darkTextSecondary
            : WingBaseColors.lightTextSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            activeIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _MessagesTab extends StatefulWidget {
  const _MessagesTab();

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WingBase',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'new_group') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatPage()),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_group',
                child: Row(
                  children: [
                    Icon(Icons.group, size: 20),
                    SizedBox(width: 12),
                    Text('New Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Status'),
          ],
          indicatorColor: WingBaseColors.primary,
          labelColor: WingBaseColors.primary,
          unselectedLabelColor: isDark
              ? WingBaseColors.darkTextSecondary
              : WingBaseColors.lightTextSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatsPage(),
          _StatusPlaceholder(isDark: isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatPage()),
          );
        },
        child: const Icon(Icons.message),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    showSearch(
      context: context,
      delegate: _ChatSearchDelegate(chatProvider: chatProvider, isDark: dark),
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<String> {
  final ChatProvider chatProvider;
  final bool isDark;

  _ChatSearchDelegate({required this.chatProvider, required this.isDark});

  @override
  String get searchFieldLabel => 'Search chats';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
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
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
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

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: WingBaseColors.primary.withValues(alpha: 0.15),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: WingBaseColors.primary),
                  )
                : null,
          ),
          title: Text(name),
          subtitle: Text(chat.getStringValue('lastMessage')),
          onTap: () {
            final isGroup = chat.getBoolValue('isGroup');
            final otherUser = isGroup ? null : chatProvider.getOtherUser(chat);

            close(context, '');
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
        );
      },
    );
  }
}

class _StatusPlaceholder extends StatelessWidget {
  final bool isDark;
  const _StatusPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: isDark
                ? WingBaseColors.darkTextSecondary
                : WingBaseColors.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No status updates',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add status update',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallsTab extends StatelessWidget {
  final bool isDark;
  const _CallsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calls',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.call_outlined,
              size: 64,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No calls yet',
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? WingBaseColors.darkTextSecondary
                    : WingBaseColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calls you make or receive will appear here',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? WingBaseColors.darkTextSecondary
                    : WingBaseColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add_call),
      ),
    );
  }
}
