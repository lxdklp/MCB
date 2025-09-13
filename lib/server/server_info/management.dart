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
  List<Map<String, dynamic>> _onlinePlayers = [];
  bool _isLoadingPlayers = false;
  String _playersErrorMessage = '';
  List<Map<String, dynamic>> _bannedPlayers = [];
  bool _isLoadingBans = false;
  String _bansErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchServerStatus();
    _fetchOnlinePlayers();
    _fetchBanList();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchServerStatus();
        _fetchOnlinePlayers();
        _fetchBanList();
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

// 获取在线玩家列表
  Future<void> _fetchOnlinePlayers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPlayers = true;
      _playersErrorMessage = '';
    });
    
    try {
      final jsonResponse = await widget.callAPI('players');
      
      if (jsonResponse.containsKey('result')) {
        final result = jsonResponse['result'];
        
        if (result is List) {
          if (mounted) {
            setState(() {
              _onlinePlayers = List<Map<String, dynamic>>.from(
                result.map((player) => {
                  'id': player['id'],
                  'name': player['name'],
                })
              );
              _isLoadingPlayers = false;
            });
          }
          
          LogUtil.log('获取在线玩家成功: ${_onlinePlayers.length} 名玩家', level: 'INFO');
        } else {
          throw Exception('返回的玩家数据格式无效');
        }
      } else if (jsonResponse.containsKey('error')) {
        throw Exception('服务器错误: ${jsonResponse['error']}');
      } else {
        throw Exception('无效的响应格式');
      }
    } catch (e) {
      LogUtil.log('获取在线玩家失败: $e', level: 'ERROR');
      
      if (mounted) {
        setState(() {
          _isLoadingPlayers = false;
          _playersErrorMessage = '获取玩家列表失败: ${_formatErrorMessage(e)}';
        });
      }
    }
  }

  // 获取封禁列表
  Future<void> _fetchBanList() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBans = true;
      _bansErrorMessage = '';
    });
    try {
      final jsonResponse = await widget.callAPI('bans');
      if (jsonResponse.containsKey('result')) {
        final result = jsonResponse['result'];
        if (result is List) {
          if (mounted) {
            setState(() {
              _bannedPlayers = List<Map<String, dynamic>>.from(
                result.map((ban) => Map<String, dynamic>.from(ban))
              );
              _isLoadingBans = false;
            });
          }
          LogUtil.log('获取封禁列表成功: ${_bannedPlayers.length} 名封禁玩家', level: 'INFO');
        } else {
          throw Exception('返回的封禁数据格式无效');
        }
      } else if (jsonResponse.containsKey('error')) {
        throw Exception('服务器错误: ${jsonResponse['error']}');
      } else {
        throw Exception('无效的响应格式');
      }
    } catch (e) {
      LogUtil.log('获取封禁列表失败: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          _isLoadingBans = false;
          _bansErrorMessage = '获取封禁列表失败: ${_formatErrorMessage(e)}';
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

  // 踢出玩家确认对话框
  Future<void> _showKickConfirmDialog(Map<String, dynamic> player) async {
    final playerName = player['name'] ?? '未知玩家';
    final playerUUID = player['id'] ?? '未知UUID';
    final currentContext = context;
    final reasonController = TextEditingController();
    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('踢出玩家'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要踢出玩家 "$playerName" 吗？'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '踢出理由',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final reason = reasonController.text.trim();
              try {
                await widget.callAPI('players/kick', [
                  {
                    "message": {"literal": reason.isEmpty ? "来自MCB的踢出" : reason},
                    "players": [{
                      "name": playerName,
                      "id": playerUUID
                  }]
                  }
                ]);
                if (mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(content: Text(reason.isEmpty
                        ? '已踢出玩家: $playerName'
                        : '已踢出玩家: $playerName (理由: $reason)')),
                  );
                  Future.delayed(const Duration(seconds: 1), _fetchOnlinePlayers);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(content: Text('踢出失败: ${_formatErrorMessage(e)}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('踢出'),
          ),
        ],
      ),
    );
  }

    // 封禁玩家确认对话框
  Future<void> _showBanConfirmDialog(Map<String, dynamic> player) async {
    final playerName = player['name'] ?? '未知玩家';
    final playerUUID = player['id'] ?? '未知UUID';
    final currentContext = context;
    final reasonController = TextEditingController();
    final sourceController = TextEditingController();
    // 封禁到期时间
    DateTime? expiryDate;
    String formattedExpiryDate = '永久封禁';
    showDialog(
      context: currentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('封禁玩家'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('确定要封禁玩家 "$playerName" 吗？\n这将阻止该玩家重新加入服务器。'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: '封禁理由',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: '封禁执行者',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final reason = reasonController.text.trim();
                try {
                  await widget.callAPI('bans/add', [[
                    {
                      "reason": reason.isEmpty ? "来自MCB的封禁" : reason,
                      "source": sourceController.text.trim().isEmpty ? "MCB客户端" : sourceController.text.trim(),
                      "expires": null,
                      "player": {
                        "name": playerName,
                        "id": playerUUID
                      }
                    }
                  ]]);
                  if (mounted) {
                    String message = reason.isEmpty
                        ? '已封禁玩家: $playerName'
                        : '已封禁玩家: $playerName (理由: $reason)';
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                    Future.delayed(const Duration(seconds: 1), _fetchOnlinePlayers);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(content: Text('封禁失败: ${_formatErrorMessage(e)}')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('封禁'),
            ),
          ],
        ),
      ),
    );
  }

  // 添加解除封禁确认对话框方法
  Future<void> _showUnbanConfirmDialog(Map<String, dynamic> player) async {
    final playerName = player['name'] ?? '未知玩家';
    final playerUUID = player['id'] ?? '未知UUID';
    final currentContext = context;
    
    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('解除封禁'),
        content: Text('确定要解除对玩家 "$playerName" 的封禁吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 解除封禁API调用
                await widget.callAPI('bans/remove', [[
                  {
                    "player": [{
                      "name": playerName,
                      "id": playerUUID
                    }]
                  }
                ]]);
                if (mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(content: Text('已解除对玩家 $playerName 的封禁')),
                  );
                  // 刷新封禁列表
                  _fetchBanList();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(content: Text('解除封禁失败: ${_formatErrorMessage(e)}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
            child: const Text('解除封禁'),
          ),
        ],
      ),
    );
  }

  // 添加清空封禁列表确认对话框方法
  Future<void> _showClearBansConfirmDialog() async {
    final currentContext = context;
    final bannedCount = _bannedPlayers.length;
    
    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('清空封禁列表'),
        content: Text('确定要清空所有封禁记录吗？\n这将解除对 $bannedCount 名玩家的封禁，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 调用清空封禁API
                await widget.callAPI('bans/clear');
                
                if (mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text('已清空所有封禁记录')),
                  );
                  // 刷新封禁列表
                  _fetchBanList();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(content: Text('清空封禁列表失败: ${_formatErrorMessage(e)}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('清空'),
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
        _buildPlayersCard(),
        _buildSendMessageCard(),
        _buildBanListCard(),
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
                const Text('发送全服消息', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

// 添加构建玩家列表卡片的方法

  Widget _buildPlayersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('在线玩家', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoadingPlayers ? null : _fetchOnlinePlayers,
                  tooltip: '刷新玩家列表',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingPlayers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_playersErrorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _playersErrorMessage,
                  style: TextStyle(color: Colors.red[700]),
                ),
              )
            else if (_onlinePlayers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('当前没有玩家在线'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _onlinePlayers.length,
                itemBuilder: (context, index) {
                  final player = _onlinePlayers[index];
                  return ListTile(
                    title: Text(player['name'] ?? '未知玩家'),
                    subtitle: Text('UUID: ${player['id'] ?? '未知UUID'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showPlayerActions(player),
                      tooltip: '玩家操作',
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 显示玩家操作菜单
  Future<void> _showPlayerActions(Map<String, dynamic> player) async {
    final currentContext = context;
    showModalBottomSheet(
      context: currentContext,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.message),
                title: Text('私信 ${player['name']}'),
                onTap: () {
                  Navigator.pop(context);
                  // 这里可以添加私信玩家的功能
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove),
                title: const Text('踢出玩家'),
                onTap: () async {
                  Navigator.pop(context);
                  await _showKickConfirmDialog(player);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('封禁玩家'),
                onTap: () async {
                  Navigator.pop(context);
                  await _showBanConfirmDialog(player);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 封禁列表卡片
  Widget _buildBanListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('封禁列表', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    // 添加清空按钮
                    IconButton(
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: _bannedPlayers.isEmpty || _isLoadingBans ? null : _showClearBansConfirmDialog,
                      tooltip: '清空封禁列表',
                    ),
                    // 保留原有的刷新按钮
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoadingBans ? null : _fetchBanList,
                      tooltip: '刷新封禁列表',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 其余内容保持不变...
            if (_isLoadingBans)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_bansErrorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _bansErrorMessage,
                  style: TextStyle(color: Colors.red[700]),
                ),
              )
            else if (_bannedPlayers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('当前没有封禁的玩家'),
              )
            else
              ListView.builder(
                // 保持现有代码不变...
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bannedPlayers.length,
                itemBuilder: (context, index) {
                  // 保持现有代码不变...
                  final ban = _bannedPlayers[index];
                  final player = ban['player'] as Map<String, dynamic>;
                  final playerName = player['name'] ?? '未知玩家';
                  
                  // 处理可能是对象或字符串的reason字段
                  String reasonText = '未指定原因';
                  if (ban.containsKey('reason')) {
                    if (ban['reason'] is Map) {
                      reasonText = (ban['reason'] as Map).containsKey('literal') 
                          ? ban['reason']['literal'].toString() 
                          : ban['reason'].toString();
                    } else {
                      reasonText = ban['reason'].toString();
                    }
                  }
                  
                  final source = ban['source'] ?? '未知来源';
                  
                  // 处理到期时间
                  String expiryText = '永久封禁';
                  if (ban.containsKey('expires') && ban['expires'] != null) {
                    expiryText = '到期时间: ${ban['expires']}';
                  }
                  
                  return Card(
                    // 保持现有代码不变...
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_off, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  playerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _showUnbanConfirmDialog(player),
                                tooltip: '解除封禁',
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildBanInfoRow('ID', player['id'] ?? '未知ID'),
                          _buildBanInfoRow('原因', reasonText),
                          _buildBanInfoRow('执行人', source),
                          _buildBanInfoRow('状态', expiryText),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 封禁信息行构建
  Widget _buildBanInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
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
}