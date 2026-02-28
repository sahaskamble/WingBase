import 'package:wingbase/Models/ChatModel.dart';
import 'package:wingbase/Pages/IndividualPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomeCard extends StatelessWidget {
  const CustomeCard({super.key, required this.chatModel});

  final ChatModel chatModel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) =>
              IndividualPage(chatModel: chatModel),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(10),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blueGrey,
          child: SvgPicture.asset(
            "assets/${chatModel.icon}",
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
            width: 30,
            height: 30,
          ),
        ),
        title: Text(
          chatModel.name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.done_all),
            SizedBox(width: 6),
            Text(chatModel.currentMessage),
          ],
        ),
        trailing: Text(chatModel.time),
      ),
    );
  }
}
