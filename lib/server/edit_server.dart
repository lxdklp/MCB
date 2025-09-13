import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mcb/function/log.dart';

class EditServerPage extends StatefulWidget {
  const EditServerPage({
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
  EditServerPageState createState() => EditServerPageState();
}

class EditServerPageState extends State<EditServerPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
    _addressController.text = widget.address;
    _portController.text = widget.port;
    _tokenController.text = widget.token;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // 切换令牌可见性
  Future<void> _toggleTokenVisibility() async {
    setState(() {
      _obscureToken = !_obscureToken;
    });
  }

  // 保存服务器信息
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

  // 删除服务器
  Future<void> _deleteServer() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> servers = prefs.getStringList('servers') ?? [];
    servers.remove(widget.name);
    await prefs.setStringList('servers', servers);
    await prefs.remove('${widget.name}_config');
    LogUtil.log('删除服务器: ${widget.name}', level: 'INFO');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('服务器删除成功')),
    );
    Navigator.pop(context);
  }


  // 确认删除对话框
  Future<void> _showDeleteDialog() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定要删除服务器"${widget.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteServer();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑服务器'),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'save',
            onPressed: _saveServer,
            child: const Icon(Icons.save),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'delete',
            onPressed: _showDeleteDialog,
            child: const Icon(Icons.delete),
          ),
        ],
      )
    );
  }
}