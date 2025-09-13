import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mcb/function/log.dart';

class AddServerPage extends StatefulWidget {
  const AddServerPage({super.key});

  @override
  AddServerPageState createState() => AddServerPageState();
}

class AddServerPageState extends State<AddServerPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _obscureToken = true;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _toggleTokenVisibility() async {
    setState(() {
      _obscureToken = !_obscureToken;
    });
  }

  Future<void> _saveServer() async {
    String name = _nameController.text;
    String address = _addressController.text;
    String port = _portController.text;
    String token = _tokenController.text;
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写名称')),
      );
      return;
    }
    if (address.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写地址')),
      );
      return;
    }
    if (port.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写端口')),
      );
      return;
    }
    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写令牌')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    List<String> servers = prefs.getStringList('servers') ?? [];
    if (servers.contains(name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已存在相同名称的服务器')),
      );
      return;
    }
    servers.add(name);
    await prefs.setStringList('servers', servers);
    List<String> serverConfig = [name, address, port, token];
    await prefs.setStringList('${name}_config', serverConfig);
    LogUtil.log('保存服务器: $name, 地址: $address, 端口: $port, 令牌: $token', level: 'INFO');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('服务器添加成功')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加服务器'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '请输入名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '地址',
              hintText: '请输入地址',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '请输入端口',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            decoration: InputDecoration(
              labelText: '令牌',
              hintText: '请输入令牌',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
                onPressed: _toggleTokenVisibility,
              )
            ),
            obscureText: _obscureToken,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveServer,
        child: const Icon(Icons.save),
      ),
    );
  }
}