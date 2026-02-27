import 'package:wingbase/Models/ChatModel.dart';
import 'package:wingbase/Pages/NewChatPage.dart';
import 'package:wingbase/components/ui/CustomCard.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<ChatModel> chats = [
    ChatModel(
      name: "Jane Doe",
      isGroup: false,
      currentMessage: "Hii Sahas",
      time: "20:12",
      icon: "person.svg",
    ),
    ChatModel(
      name: "Suhas kamble",
      isGroup: false,
      currentMessage: "Hey Dada",
      time: "01:12",
      icon: "person.svg",
    ),
    ChatModel(
      name: "Anant kamble",
      isGroup: false,
      currentMessage: "Dada kuthe aahes",
      time: "03:12",
      icon: "person.svg",
    ),
    ChatModel(
      name: "Ketan",
      isGroup: false,
      currentMessage: "Hey sahas",
      time: "01:16",
      icon: "person.svg",
    ),
    ChatModel(
      name: "Test4",
      isGroup: true,
      currentMessage: "Hey",
      time: "02:12",
      icon: "groups.svg",
    ),
    ChatModel(
      name: "Jay",
      isGroup: false,
      currentMessage: "Kedir MC",
      time: "07:30",
      icon: "person.svg",
    ),
    ChatModel(
      name: "Yash-kun",
      isGroup: false,
      currentMessage: "Chala Tekdi jaau",
      time: "05:30",
      icon: "person.svg",
    ),
    ChatModel(
      name: "Test1",
      isGroup: true,
      currentMessage: "Hey Sahas",
      time: "02:12",
      icon: "groups.svg",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => const NewChatPage(),
          ),
        ),
        shape: CircleBorder(),
        child: Icon(Icons.chat_rounded, size: 30),
      ),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) => CustomeCard(chatModel: chats[index]),
      ),
    );
  }
}
