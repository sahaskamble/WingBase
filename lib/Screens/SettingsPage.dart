import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wingbase/components/ui/user_avatar.dart';
import 'package:wingbase/providers/auth_provider.dart';
import 'package:wingbase/services/chat_service.dart';
import 'package:wingbase/utils/colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? WingBaseColors.darkScaffoldBg
          : WingBaseColors.lightScaffoldBg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildHeader(context, isDark),
          const Divider(),
          _buildMenuItem(
            context,
            isDark,
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Update your profile information',
            onTap: () => _showProfileDialog(context, isDark),
          ),
          _buildMenuItem(
            context,
            isDark,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Configure notification settings',
            onTap: () {},
          ),
          _buildMenuItem(
            context,
            isDark,
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Privacy settings',
            onTap: () {},
          ),
          _buildMenuItem(
            context,
            isDark,
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'Get help and support',
            onTap: () {},
          ),
          const Divider(),
          _buildMenuItem(
            context,
            isDark,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: () => _showLogoutDialog(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final name = user?.getStringValue('name') ?? 'User';
        final email = user?.getStringValue('email') ?? '';
        final avatarUrl = user != null ? ChatService.avatarUrl(user) : '';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(imageUrl: avatarUrl, name: name, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? WingBaseColors.darkTextPrimary
                            : WingBaseColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? WingBaseColors.darkTextSecondary
                            : WingBaseColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : WingBaseColors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? Colors.red
              : (isDark
                    ? WingBaseColors.darkTextPrimary
                    : WingBaseColors.lightTextPrimary),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? WingBaseColors.darkTextSecondary
              : WingBaseColors.lightTextSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showProfileDialog(BuildContext context, bool isDark) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final nameCtrl = TextEditingController(
      text: user?.getStringValue('name') ?? '',
    );
    final aboutCtrl = TextEditingController(
      text: user?.getStringValue('about') ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: aboutCtrl,
              decoration: const InputDecoration(labelText: 'About'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: Implement profile update
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
