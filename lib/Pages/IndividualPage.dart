import 'package:wingbase/Models/ChatModel.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class IndividualPage extends StatefulWidget {
  const IndividualPage({super.key, required this.chatModel});
  final ChatModel chatModel;

  @override
  State<IndividualPage> createState() => _IndividualPageState();
}

class _IndividualPageState extends State<IndividualPage> {
  bool showEmojiPicker = false;
  FocusNode focusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        showEmojiPicker = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        leadingWidth: 80,
        titleSpacing: 0,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 25),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blueGrey,
                child: SvgPicture.asset(
                  widget.chatModel.isGroup
                      ? "assets/groups.svg"
                      : "assets/person.svg",
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
        title: InkWell(
          onTap: () {},
          child: Container(
            margin: EdgeInsets.all(5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatModel.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "last seen today on ${widget.chatModel.time}",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.videocam)),
          IconButton(onPressed: () {}, icon: Icon(Icons.call)),
          PopupMenuButton(
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: "Contact Info",
                  child: Text("Contact info"),
                ),
                PopupMenuItem(value: "Clear chat", child: Text("Clear chat")),
                PopupMenuItem(value: "Delete chat", child: Text("Delete chat")),
              ];
            },
          ),
        ],
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: WillPopScope(
          child: Stack(
            children: [
              ListView(),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width - 55,
                            child: Card(
                              margin: EdgeInsets.only(
                                left: 5,
                                right: 5,
                                bottom: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: TextFormField(
                                focusNode: focusNode,
                                controller: textEditingController,
                                textAlignVertical: TextAlignVertical.center,
                                keyboardType: TextInputType.multiline,
                                maxLines: 5,
                                minLines: 1,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Type a message",
                                  contentPadding: EdgeInsets.all(5),
                                  prefixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        showEmojiPicker = !showEmojiPicker;
                                      });
                                    },
                                    icon: Icon(Icons.emoji_emotions),
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          showModalBottomSheet(
                                            backgroundColor: Colors.transparent,
                                            context: context,
                                            builder: (BuildContext context) =>
                                                bottomAttachMentPicker(),
                                          );
                                        },
                                        icon: Icon(Icons.attach_file),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: Icon(Icons.camera_alt),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, right: 2),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Color(0xFF128C7E),
                              child: IconButton(
                                onPressed: () {},
                                icon: Icon(Icons.mic, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      showEmojiPicker ? emojiSelect() : Container(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          onWillPop: () {
            if (showEmojiPicker) {
              setState(() {
                showEmojiPicker = false;
              });
            } else {
              Navigator.pop(context);
            }
            return Future.value(false);
          },
        ),
      ),
    );
  }

  // Emoji Picker with Latest Syntax
  Widget emojiSelect() {
    return EmojiPicker(
      textEditingController: textEditingController,
      onEmojiSelected: (Category? category, Emoji emoji) {
        print(emoji);
      },
      config: Config(
        height: 256,
        emojiViewConfig: EmojiViewConfig(
          columns: 7,
          emojiSizeMax: 25,
          backgroundColor: Color(0xFFEBEFF2),
        ),
        categoryViewConfig: CategoryViewConfig(
          initCategory: Category.RECENT,
          backgroundColor: Color(0xFFEBEFF2),
          indicatorColor: Color(0xFF128C7E), // WhatsApp green
          iconColorSelected: Color(0xFF128C7E),
        ),
        bottomActionBarConfig: BottomActionBarConfig(
          backgroundColor: Color(0xFF128C7E),
          buttonIconColor: Colors.white,
          buttonColor: Color(0xFF128C7E),
        ),
      ),
    );
  }

  Widget bottomAttachMentPicker() {
    return SizedBox(
      height: 278,
      width: MediaQuery.of(context).size.width,
      child: Card(
        margin: EdgeInsets.all(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconCreation(
                    Icons.insert_drive_file,
                    Colors.indigo,
                    "Document",
                  ),
                  SizedBox(width: 40),
                  iconCreation(Icons.camera_alt, Colors.pink, "Camera"),
                  SizedBox(width: 40),
                  iconCreation(Icons.insert_photo, Colors.purple, "Gallery"),
                ],
              ),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconCreation(Icons.headset, Colors.orange, "Audio"),
                  SizedBox(width: 40),
                  iconCreation(Icons.location_pin, Colors.teal, "Location"),
                  SizedBox(width: 40),
                  iconCreation(Icons.person, Colors.blue, "Contacts"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget iconCreation(IconData icon, Color color, String text) {
    return InkWell(
      onTap: () {
        print("Attachment Clicked!!!!");
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, size: 29, color: Colors.white),
          ),
          SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
