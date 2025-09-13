import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mcb/function/log.dart';

class ServerManagementPage extends StatefulWidget {
  final String name;
  final String address;
  final String port;
  final String token;
  final WebSocketChannel? channel;
  final bool isConnected;
  final Function(String, [dynamic]) callAPI;


  const ServerManagementPage({
    super.key,
    required this.name,
    required this.address,
    required this.port,
    required this.token,
    required this.channel,
    required this.isConnected,
    required this.callAPI,
  });

  @override
  ServerManagementPageState createState() => ServerManagementPageState();
}

class ServerManagementPageState extends State<ServerManagementPage> {
  bool _isLoading = true;
  String _statusMessage = '';
  dynamic _serverStatus;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchServerStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchServerStatus();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 获取服务器状态
  Future<void> _fetchServerStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final jsonResponse = await widget.callAPI('server/status');
      if (jsonResponse.containsKey('result')) {
        final result = jsonResponse['result'];
        if (mounted) {
          setState(() {
            _isLoading = false;
            _serverStatus = result;
            _statusMessage = '';
          });
        }
        LogUtil.log('获取服务器状态成功: ${widget.name}', level: 'INFO');
      } else if (jsonResponse.containsKey('error')) {
        throw Exception('服务器错误: ${jsonResponse['error']}');
      } else {
        throw Exception('无效的响应格式');
      }
    } catch (e) {
      LogUtil.log('获取服务器状态失败: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '获取状态失败: ${_formatErrorMessage(e)}';
        });
      }
    }
  }

  // 格式化错误信息
  String _formatErrorMessage(Object error) {
    if (error is SocketException) {
      return '网络连接错误，请检查网络设置或服务器地址';
    } else if (error is TimeoutException) {
      return '连接超时，服务器可能未响应';
    } else if (error is FormatException) {
      return '数据格式错误，服务器返回了无效数据';
    } else if (error.toString().contains('WebSocket')) {
      return 'WebSocket连接失败,请确认服务器支持WebSocket';
    } else {
      return '发生未知错误: ${error.toString()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchServerStatus,
      child: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _statusMessage.isNotEmpty
          ? _buildErrorView()
          : _buildServerStatusView(),
    );
  }

  // 错误视图组件
  Widget _buildErrorView() {
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: _fetchServerStatus,
            ),
          ),
        ],
      ),
    );
  }

  // 显示服务器状态信息
  Widget _buildServerStatusView() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('服务器信息', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                _buildInfoRow('服务器名称', widget.name),
                _buildInfoRow('RPC地址', '${widget.address}:${widget.port}'),
                _buildInfoRow('连接状态', widget.isConnected ? '已连接' : '未连接'),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('服务器状态', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._buildStatusDetails(),
              ],
            ),
          ),
        ),
        if (widget.isConnected)
        _buildSendMessageCard(),
        _buildControlCard(),
      ],
    );
  }

  // 发送消息卡片
  Widget _buildSendMessageCard() {
    final TextEditingController messageController = TextEditingController();
    final TextEditingController translateParamsController = TextEditingController();
    bool isTranslatable = false;
    bool isOverlay = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('发送消息', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('消息类型:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('普通文本'),
                      selected: !isTranslatable,
                      onSelected: (selected) {
                        setState(() {
                          isTranslatable = !selected;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('本地化文本'),
                      selected: isTranslatable,
                      onSelected: (selected) {
                        setState(() {
                          isTranslatable = selected;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: isTranslatable ? '本地化键名' : '文本消息',
                    hintText: isTranslatable ? 'zh_cn' : '输入要发送的消息',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (isTranslatable)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      TextField(
                        controller: translateParamsController,
                        decoration: const InputDecoration(
                          labelText: '参数列表',
                          hintText: '使用逗号分隔多个参数，例如: 参数1,参数2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isOverlay,
                      onChanged: (value) {
                        setState(() {
                          isOverlay = value ?? false;
                        });
                      },
                    ),
                    const Text('在动作栏显示'),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('发送'),
                    onPressed: () async {
                      final currentContext = context;
                      final message = messageController.text.trim();
                      if (message.isEmpty) return;
                      try {
                        final Map<String, dynamic> messageData = {};
                        if (isTranslatable) {
                          messageData['translatable'] = message;
                          final paramsText = translateParamsController.text.trim();
                          if (paramsText.isNotEmpty) {
                            List<String> params = paramsText.split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            if (params.isNotEmpty) {
                              messageData['translatableParams'] = params;
                            }
                          }
                        } else {
                          messageData['literal'] = message;
                        }
                        await widget.callAPI('server/system_message', [
                          {
                            'message': messageData,
                            'overlay': isOverlay
                          }
                        ]);
                        if (mounted) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            const SnackBar(content: Text('消息已发送')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(content: Text('发送失败: ${_formatErrorMessage(e)}')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // 控制卡片
  Widget _buildControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('服务器控制', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('保存服务器'),
                    onPressed: _saveServer,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('停止服务器'),
                    onPressed: _stopServer,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

  // 服务器信息
  List<Widget> _buildStatusDetails() {
    final List<Widget> widgets = [];
    try {
      if (_serverStatus is Map) {
        if (_serverStatus.containsKey('started')) {
          final bool started = _serverStatus['started'] as bool;
          widgets.add(
            _buildInfoRow(
              '运行状态',
              started ? '正在运行' : '未运行',
            ),
          );
        }
        if (_serverStatus.containsKey('version') && _serverStatus['version'] is Map) {
          final Map versionInfo = _serverStatus['version'] as Map;
          if (versionInfo.containsKey('name')) {
            widgets.add(
              _buildInfoRow('游戏版本', versionInfo['name'].toString()),
            );
          }
          if (versionInfo.containsKey('protocol')) {
            widgets.add(
              _buildInfoRow('协议版本', versionInfo['protocol'].toString()),
            );
          }
        }
      }
      if (widgets.isEmpty) {
        widgets.add(const Text('没有可用的状态信息'));
      }
    } catch (e) {
      LogUtil.log('解析服务器状态时出错: $e', level: 'ERROR');
      widgets.add(Text('解析服务器状态时出错: $e', style: const TextStyle(color: Colors.red)));
    }
    return widgets;
  }

  // 信息行组件
  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  // 保存服务器
  Future<void> _saveServer() async {
    try {
      await widget.callAPI('server/save');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器保存命令已发送')),
        );
        Future.delayed(const Duration(seconds: 2), _fetchServerStatus);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${_formatErrorMessage(e)}')),
        );
      }
    }
  }

  // 停止服务器
  Future<void> _stopServer() async {
    try {
      await widget.callAPI('server/stop');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器停止命令已发送')),
        );
        Future.delayed(const Duration(seconds: 2), _fetchServerStatus);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止失败: ${_formatErrorMessage(e)}')),
        );
      }
    }
  }
}