import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/chat_service.dart';
import 'package:wingbase/utils/colors.dart';

class MessageBubble extends StatelessWidget {
  final RecordModel message;
  final bool showAvatar;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.onLongPress,
  });

  bool get _isMe =>
      message.getStringValue('senderId') == AuthService.currentUserId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = message.getStringValue('type');

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          mainAxisAlignment: _isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_isMe && showAvatar) _buildAvatar(),
            if (!_isMe && !showAvatar) const SizedBox(width: 32),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: _buildBubble(context, type, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, String type, bool isDark) {
    final bg = _isMe
        ? WingBaseColors.primary
        : (isDark ? WingBaseColors.darkCardBg : WingBaseColors.lightCardBg);

    final textColor = _isMe
        ? Colors.white
        : (isDark
              ? WingBaseColors.darkTextPrimary
              : WingBaseColors.lightTextPrimary);

    // Media messages have no padding around the image/video
    final isMedia = type == 'image' || type == 'video' || type == 'audio';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(_isMe ? 18 : 4),
          bottomRight: Radius.circular(_isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(_isMe ? 18 : 4),
          bottomRight: Radius.circular(_isMe ? 4 : 18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.expand['replyTo'] != null)
              _buildReplyPreview(context, isDark),

            if (type == 'image') _buildImageContent(context),
            if (type == 'video') _buildVideoContent(),
            if (type == 'audio') _buildAudioContent(textColor),
            if (type == 'text') _buildTextContent(textColor),

            _buildFooter(textColor, isMedia: isMedia),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Text(
        message.getStringValue('content'),
        style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final filename = message.getStringValue('mediaFile');
    final url = ChatService.fileUrl(message, filename);

    return GestureDetector(
      onTap: () => _showFullImage(context, url),
      child: Image.network(
        url,
        width: 260,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _mediaErrorPlaceholder(Icons.broken_image),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _mediaLoadingPlaceholder(),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullImageViewer(url: url)),
    );
  }

  Widget _buildVideoContent() {
    // Video - show play button overlay
    final filename = message.getStringValue('mediaFile');
    final videoUrl = filename.isNotEmpty
        ? ChatService.fileUrl(message, filename)
        : '';

    return Stack(
      alignment: Alignment.center,
      children: [
        videoUrl.isNotEmpty
            ? Image.network(
                videoUrl,
                width: 260,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _mediaErrorPlaceholder(Icons.videocam_off),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _mediaLoadingPlaceholder(),
              )
            : _mediaErrorPlaceholder(Icons.videocam),

        // Play button
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
        ),

        // Duration badge (placeholder)
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Video',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioContent(Color textColor) {
    final filename = message.getStringValue('mediaFile');
    final url = ChatService.fileUrl(message, filename);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: _AudioPlayerWidget(url: url, isMe: _isMe),
    );
  }

  Widget _buildReplyPreview(BuildContext context, bool isDark) {
    final replyExpand = message.expand['replyTo'];
    RecordModel? reply;

    final replyDyn = replyExpand as dynamic;
    if (replyDyn is RecordModel) {
      reply = replyDyn;
    } else if (replyDyn is List && replyDyn.length > 0) {
      final first = replyDyn[0];
      if (first is RecordModel) {
        reply = first as RecordModel;
      }
    }
    if (reply == null) return const SizedBox.shrink();

    final senderExpand = reply.expand['senderId'];
    String senderName = 'Unknown';
    final senderDyn = senderExpand as dynamic;
    if (senderDyn is RecordModel) {
      senderName = senderDyn.getStringValue('name');
    } else if (senderDyn is List && senderDyn.length > 0) {
      final first = senderDyn[0];
      if (first is RecordModel) {
        senderName = (first as RecordModel).getStringValue('name');
      }
    }
    final content = switch (reply.getStringValue('type')) {
      'image' => '📷 Photo',
      'video' => '🎥 Video',
      _ => reply.getStringValue('content'),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: _isMe ? Colors.white60 : WingBaseColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _isMe ? Colors.white : WingBaseColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: _isMe
                  ? Colors.white70
                  : (isDark
                        ? WingBaseColors.darkTextSecondary
                        : WingBaseColors.lightTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color textColor, {bool isMedia = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, isMedia ? 0 : 2, 8, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMedia) const Spacer(),
          Text(
            _formatTime(message.created.toString()),
            style: TextStyle(
              fontSize: 11,
              color: isMedia
                  ? Colors.white.withOpacity(0.85)
                  : textColor.withOpacity(0.6),
            ),
          ),
          if (_isMe) ...[
            const SizedBox(width: 4),
            _buildTicks(isMedia: isMedia),
          ],
        ],
      ),
    );
  }

  Widget _buildTicks({bool isMedia = false}) {
    final status = message.getStringValue('status');
    final isRead = status == 'read';
    return Icon(
      status == 'sent' ? Icons.done : Icons.done_all,
      size: 14,
      color: isRead
          ? Colors.lightBlue
          : (isMedia ? Colors.white70 : Colors.white70),
    );
  }

  Widget _buildAvatar() {
    final senderExpand = message.expand['senderId'];
    String avatarUrl = '';
    String name = '?';

    final senderDyn = senderExpand as dynamic;
    if (senderDyn is RecordModel) {
      avatarUrl = ChatService.avatarUrl(senderDyn);
      name = senderDyn.getStringValue('name');
    } else if (senderDyn is List && senderDyn.length > 0) {
      final first = senderDyn[0];
      if (first is RecordModel) {
        avatarUrl = ChatService.avatarUrl(first);
        name = first.getStringValue('name');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: WingBaseColors.primary.withOpacity(0.2),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 11))
            : null,
      ),
    );
  }

  Widget _mediaErrorPlaceholder(IconData icon) {
    return Container(
      width: 260,
      height: 200,
      color: Colors.grey.shade300,
      child: Icon(icon, color: Colors.grey.shade600, size: 40),
    );
  }

  Widget _mediaLoadingPlaceholder() {
    return Container(
      width: 260,
      height: 200,
      color: Colors.grey.shade200,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  String _formatTime(String createdStr) {
    final dt = DateTime.tryParse(createdStr) ?? DateTime.now();
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final bool isMe;

  const _AudioPlayerWidget({required this.url, required this.isMe});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setSourceUrl(widget.url);

      // Get duration after setting source
      await Future.delayed(const Duration(milliseconds: 500));
      final dur = await _player.getDuration();
      _duration = dur ?? const Duration(minutes: 1);
      _isLoading = false;
      if (mounted) setState(() {});

      _positionSub = _player.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _stateSub = _player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
        if (state == PlayerState.completed) {
          _player.seek(const Duration(seconds: 0));
          _player.pause();
        }
      });
    } catch (e) {
      debugPrint('Error initializing audio: $e');
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : WingBaseColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isLoading
              ? null
              : () async {
                  try {
                    if (_isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.resume();
                    }
                  } catch (e) {
                    debugPrint('Playback error: $e');
                  }
                },
          child: _isLoading
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: color,
                  size: 40,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: color,
                  inactiveTrackColor: color.withValues(alpha: 0.3),
                  thumbColor: color,
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _duration.inMilliseconds.toDouble().clamp(
                    1,
                    double.infinity,
                  ),
                  onChanged: (val) =>
                      _player.seek(Duration(milliseconds: val.toInt())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

class _FullImageViewer extends StatelessWidget {
  final String url;

  const _FullImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
