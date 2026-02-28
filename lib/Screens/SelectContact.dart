import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/components/ui/user_avatar.dart';
import 'package:wingbase/Screens/ChatScreen.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/chat_service.dart';
import 'package:wingbase/services/pb_client.dart';
import 'package:wingbase/utils/colors.dart';

class SelectContact extends StatefulWidget {
  const SelectContact({super.key});

  @override
  State<SelectContact> createState() => _SelectContactState();
}

class _SelectContactState extends State<SelectContact> {
  final _searchCtrl = TextEditingController();
  List<RecordModel> _allUsers = [];
  List<RecordModel> _filteredUsers = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _isCreating = false;
  File? _groupIcon;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await pb.collection('users').getFullList();
      final myId = AuthService.currentUserId;
      final filtered = users.where((u) => u.id != myId).toList();
      setState(() {
        _allUsers = filtered;
        _filteredUsers = filtered;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredUsers = _allUsers.where((u) {
          final name = u.getStringValue('name').toLowerCase();
          final phone = u.getStringValue('phone').toLowerCase();
          final email = u.getStringValue('email').toLowerCase();
          return name.contains(q) || phone.contains(q) || email.contains(q);
        }).toList();
      });
    }
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  Future<void> _pickGroupIcon() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _groupIcon = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one contact')),
      );
      return;
    }

    final name = await _showGroupNameDialog();
    if (name == null || name.trim().isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final chat = await ChatService.createGroupChat(
        name: name.trim(),
        participantIds: _selectedIds.toList(),
        icon: _groupIcon,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            chatName: name.trim(),
            avatarUrl: _groupIcon != null ? '' : '',
            isGroup: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
      }
    }
  }

  Future<String?> _showGroupNameDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Group Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter group name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _selectedIds.isEmpty
                  ? 'Select participants'
                  : '${_selectedIds.length} selected',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _isCreating ? null : _createGroup,
            ),
        ],
      ),
      body: Column(
        children: [
          // Group icon + search
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark
                ? WingBaseColors.darkAppBar
                : WingBaseColors.lightAppBar,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickGroupIcon,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: WingBaseColors.primary.withOpacity(
                          0.15,
                        ),
                        backgroundImage: _groupIcon != null
                            ? FileImage(_groupIcon!)
                            : null,
                        child: _groupIcon == null
                            ? Icon(Icons.group, color: WingBaseColors.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: WingBaseColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterUsers,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
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
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(
                        color: isDark
                            ? WingBaseColors.darkTextSecondary
                            : WingBaseColors.lightTextSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedIds.contains(user.id);
                      final name = user.getStringValue('name');
                      final phone = user.getStringValue('phone');
                      final avatarUrl = ChatService.avatarUrl(user);

                      return ListTile(
                        leading: Stack(
                          children: [
                            UserAvatar(
                              imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                              name: name,
                              radius: 24,
                            ),
                            if (isSelected)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: WingBaseColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? WingBaseColors.darkScaffoldBg
                                          : WingBaseColors.lightScaffoldBg,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
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
                          phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? WingBaseColors.darkTextSecondary
                                : WingBaseColors.lightTextSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: WingBaseColors.primary,
                              )
                            : null,
                        onTap: () => _toggleSelection(user.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
