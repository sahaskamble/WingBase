import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/chat_service.dart';
import 'package:wingbase/utils/colors.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: WingBaseColors.primary.withValues(alpha: 0.15),
          backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
              ? NetworkImage(imageUrl!)
              : null,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: radius * 0.75,
                    fontWeight: FontWeight.bold,
                    color: WingBaseColors.primary,
                  ),
                )
              : null,
        ),
        if (showOnlineIndicator && isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class UserAvatarFromRecord extends StatelessWidget {
  final RecordModel? user;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;

  const UserAvatarFromRecord({
    super.key,
    this.user,
    this.radius = 24,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return UserAvatar(
        name: '?',
        radius: radius,
        showOnlineIndicator: showOnlineIndicator,
        isOnline: isOnline,
      );
    }

    final name = user!.getStringValue('name');
    final avatarUrl = ChatService.avatarUrl(user!);

    return UserAvatar(
      imageUrl: avatarUrl,
      name: name,
      radius: radius,
      showOnlineIndicator: showOnlineIndicator,
      isOnline: isOnline,
    );
  }
}
