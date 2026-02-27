class ChatModel {
  String name;
  String icon;
  bool isGroup;
  String time;
  String currentMessage;
  ChatModel({
    required this.name, // 👈 required
    required this.icon,
    required this.isGroup,
    required this.time,
    required this.currentMessage,
  });
}
