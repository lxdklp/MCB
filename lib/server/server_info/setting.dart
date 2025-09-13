import 'package:flutter/material.dart';
import 'package:mcb/function/log.dart';

class ServerSettingPage extends StatefulWidget {
  final String name;
  final String address;
  final String port;
  final String token;
  final Function(String, [Map<String, dynamic>?]) callAPI;

  const ServerSettingPage({
    super.key,
    required this.name,
    required this.address,
    required this.port,
    required this.token,
    required this.callAPI,
  });

  @override
  ServerSettingPageState createState() => ServerSettingPageState();
}

class ServerSettingPageState extends State<ServerSettingPage> {
  bool _isLoading = false;
  final TextEditingController _memoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _memoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            ],
          ),
        );
  }
}