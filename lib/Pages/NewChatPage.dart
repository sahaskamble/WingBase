import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/components/ui/user_avatar.dart';
import 'package:wingbase/Screens/ChatScreen.dart';
import 'package:wingbase/Screens/SelectContact.dart';
import 'package:wingbase/providers/chat_provider.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/chat_service.dart';
import 'package:wingbase/utils/colors.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _searchCtrl = TextEditingController();
  List<RecordModel> _searchResults = [];
  bool _isSearching = false;
  bool _showRecent = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showRecent = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showRecent = false;
    });

    try {
      final results = await ChatService.searchUsers(query);
      final myId = AuthService.currentUserId;
      final filtered = results.where((u) => u.id != myId).toList();
      setState(() {
        _searchResults = filtered;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _startChat(RecordModel user) async {
    try {
      final chat = await ChatService.getOrCreateDirectChat(user.id);

      // Refresh chat list
      if (mounted) {
        context.read<ChatProvider>().loadChats();
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            chatName: user.getStringValue('name'),
            avatarUrl: ChatService.avatarUrl(user),
            isGroup: false,
            otherUser: user,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    }
  }

  void _createGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectContact()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? WingBaseColors.darkScaffoldBg
          : WingBaseColors.lightScaffoldBg,
      appBar: AppBar(
        title: const Text(
          'New Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _createGroup,
            tooltip: 'Create Group',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark
                ? WingBaseColors.darkAppBar
                : WingBaseColors.lightAppBar,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search name or number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? WingBaseColors.darkCardBg
                    : WingBaseColors.lightCardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _showRecent
                ? _buildRecentChats(isDark)
                : _searchResults.isEmpty
                ? _buildNoResults(isDark)
                : _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChats(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark
                ? WingBaseColors.darkTextSecondary
                : WingBaseColors.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for contacts',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a name or phone number',
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

  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDark
                ? WingBaseColors.darkTextSecondary
                : WingBaseColors.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final name = user.getStringValue('name');
        final phone = user.getStringValue('phone');
        final email = user.getStringValue('email');
        final avatarUrl = ChatService.avatarUrl(user);

        return ListTile(
          leading: UserAvatar(
            imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
            name: name,
            radius: 24,
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
            phone.isNotEmpty ? phone : email,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? WingBaseColors.darkTextSecondary
                  : WingBaseColors.lightTextSecondary,
            ),
          ),
          onTap: () => _startChat(user),
        );
      },
    );
  }
}
