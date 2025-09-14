// filepath: /Users/lxdklp/Code/mcb/lib/server/server_info.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:mcb/function/log.dart';
import 'package:mcb/server/server_info/management.dart';
import 'package:mcb/server/server_info/setting.dart';

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
  bool _isLoading = true;
  String _statusMessage = '正在连接到服务器...';
  Timer? _refreshTimer;
  bool _isConnectionError = false;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestId = 1;
  Timer? _reconnectTimer;
  int _selectedIndex = 0;

  // 导航项数据
  static const List<NavigationItem> _navigationItems = [
    NavigationItem(
      label: '状态',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    NavigationItem(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    runZonedGuarded(() {
      _establishConnection();
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && _isConnected) {
          // 保持连接活跃
        }
      });
    }, _handleError);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _closeConnection();
    LogUtil.log('${widget.name} 页面已关闭，WebSocket连接已断开', level: 'INFO');
    super.dispose();
  }

  // 全局错误处理函数
  Future<void> _handleError(Object error, StackTrace stack) async {
    LogUtil.log('未捕获的错误: $error\n$stack', level: 'ERROR');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = '发生错误: ${_formatErrorMessage(error)}';
      });
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

  // 关闭连接
  Future<void> _closeConnection() async {
    try {
      _pendingRequests.forEach((id, completer) {
        if (!completer.isCompleted) {
          completer.completeError('连接已关闭');
        }
      });
      _pendingRequests.clear();
      if (_channel != null) {
        LogUtil.log('正在关闭WebSocket连接: ${widget.address}:${widget.port}', level: 'INFO');
        _channel!.sink.close(WebSocketStatus.normalClosure, '正常关闭');
        _channel = null;
      }
      _isConnected = false;
    } catch (e) {
      LogUtil.log('关闭连接时出错: $e', level: 'WARNING');
    }
  }

  // 建立 WebSocket 连接
  Future<void> _establishConnection() async {
    if (_isConnected || _channel != null) {
      return;
    }
    try {
      final wsUrl = 'ws://${widget.address}:${widget.port}';
      LogUtil.log('建立 WebSocket 连接: $wsUrl', level: 'INFO');
      final headers = {
        'Authorization': 'Bearer ${widget.token}',
      };
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: headers,
        pingInterval: const Duration(seconds: 10),
      );
      // 监听 WebSocket 消息
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClosed,
      );
      _isConnected = true;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      LogUtil.log('建立 WebSocket 连接失败: $e', level: 'ERROR');
      await _handleConnectionError(e);
    }
  }

  // 处理 WebSocket 消息
  Future<void> _handleWebSocketMessage(dynamic message) async {
    LogUtil.log('收到 WebSocket 消息: $message', level: 'INFO');
    try {
      final response = jsonDecode(message.toString());
      if (response is Map<String, dynamic> && response.containsKey('id')) {
        final id = response['id'];
        final completer = _pendingRequests[id];
        if (completer != null) {
          // 返回完整的 JSON 响应
          completer.complete(response);
          _pendingRequests.remove(id);
        }
      }
    } catch (e) {
      LogUtil.log('解析 WebSocket 消息失败: $e', level: 'ERROR');
    }
  }

  // 处理 WebSocket 错误
  Future<void> _handleWebSocketError(Object error) async {
    LogUtil.log('WebSocket 错误: $error', level: 'ERROR');
    await _handleConnectionError(error);
  }

  // 处理 WebSocket 连接关闭
  Future<void> _handleWebSocketClosed() async {
    LogUtil.log('WebSocket 连接关闭', level: 'INFO');
    _isConnected = false;
    _pendingRequests.forEach((id, completer) {
      if (!completer.isCompleted) {
        completer.completeError('连接已关闭');
      }
    });
    _pendingRequests.clear();
    if (mounted) {
      await _scheduleReconnection();
    }
  }

  // 重新连接
  Future<void> _scheduleReconnection() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isConnected) {
        _establishConnection();
      }
    });
  }

  // 处理连接错误
  Future<void> _handleConnectionError(Object error) async {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = '连接错误: ${_formatErrorMessage(error)}';
        _isConnectionError = true;
      });
    }
    await _scheduleReconnection();
  }

  // JSON-RPC 调用
Future<Map<String, dynamic>> _callAPI(String method, [dynamic params]) async {
  if (!_isConnected || _channel == null) {
    await _establishConnection();
    if (!_isConnected || _channel == null) {
      throw Exception('无法建立连接');
    }
  }
  final completer = Completer<Map<String, dynamic>>();
  final id = _requestId++;
  // 创建 JSON-RPC 请求
  final request = {
    'jsonrpc': '2.0',
    'method': method,
    'id': id,
  };
  if (params != null) {
    request['params'] = params; // 支持任何类型的参数
  }
  _pendingRequests[id] = completer;
  LogUtil.log('发送 RPC 请求: ${jsonEncode(request)}', level: 'INFO');
  _channel!.sink.add(jsonEncode(request));
  Timer(const Duration(seconds: 30), () {
    if (!completer.isCompleted) {
      _pendingRequests.remove(id);
      completer.completeError(TimeoutException('请求超时'));
    }
  });
  return completer.future;
}

  // 获取子页面
  List<Widget> _getPages() {
    return [
      // 状态管理页面
      ServerManagementPage(
        name: widget.name,
        address: widget.address,
        port: widget.port,
        token: widget.token,
        channel: _channel,
        isConnected: _isConnected,
        callAPI: _callAPI,
      ),
      // 设置页面
      ServerSettingPage(
        name: widget.name,
        address: widget.address,
        port: widget.port,
        token: widget.token,
        callAPI: _callAPI,
      ),
    ];
  }

  // 切换导航项
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 连接错误或加载中的情况下显示错误页面
    if (_isConnectionError || _isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name),
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _establishConnection,
                    child: const Text('重新连接'),
                  ),
                ],
              ),
            ),
      );
    }

    // 获取屏幕宽度
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool useDrawer = screenWidth >= 600;
    final List<Widget> pages = _getPages();

    if (useDrawer) {
      // 侧边栏导航
      if (screenWidth >= 900) {
        // 大屏幕
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.name),
          ),
          body: Row(
            children: [
              NavigationRail(
                extended: true,
                destinations: _navigationItems.map((item) {
                  return NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  );
                }).toList(),
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                useIndicator: true,
                indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
              Expanded(
                child: pages[_selectedIndex],
              ),
            ],
          ),
        );
      } else {
        // 中等屏幕
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.name),
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
                destinations: _navigationItems.map((item) {
                  return NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  );
                }).toList(),
                backgroundColor: Theme.of(context).colorScheme.surface,
                minWidth: 80,
                minExtendedWidth: 180,
              ),
              Expanded(
                child: pages[_selectedIndex],
              ),
            ],
          ),
        );
      }
    } else {
      // 底部导航栏
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name),
        ),
        body: pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          destinations: _navigationItems.map((item) {
            return NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            );
          }).toList(),
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      );
    }
  }
}

// 导航项数据类
class NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}