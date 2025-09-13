import 'package:flutter/material.dart';
import 'package:mcb/setting/theme.dart'; // 引入主题设置页面

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  SettingPageState createState() => SettingPageState();
}

class SettingPageState extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body: ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('主题设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemePage()),
              );
            },
          ),
          )
        ],
      ),
    );
  }
}