import 'package:wingbase/Pages/CameraPage.dart';
import 'package:wingbase/Pages/ChatPage.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = TabController(length: 4, vsync: this, initialIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("WingBase"),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search)),
          PopupMenuButton(
            onSelected: (value) {
              print(value);
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(child: Text("New Group"), value: "New Group"),
                PopupMenuItem(
                  child: Text("Whatsapp Web"),
                  value: "Whatsapp Web",
                ),
                PopupMenuItem(child: Text("Settings"), value: "Settings"),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          tabs: [
            Icon(Icons.camera_alt),
            Tab(text: "Chats"),
            Tab(text: "Status"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [CameraPage(), ChatPage(), Text("Status")],
      ),
    );
  }
}
