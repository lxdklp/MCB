import 'package:flutter/material.dart';

class ServerInfoPage extends StatefulWidget {
  const ServerInfoPage({
    super.key,
    required this.name,
    required this.address,
    required this.port,
    required this.token,
  });

  final String name;
  final String address;
  final String port;
  final String token;

  @override
  ServerInfoPageState createState() => ServerInfoPageState();
}

class ServerInfoPageState extends State<ServerInfoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body: Center(
        child: Text('服务器${widget.name}的详情页'),
      ),
    );
  }
}