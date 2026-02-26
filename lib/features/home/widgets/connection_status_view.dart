import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/crypto/bridge_transport.dart';
import '../../../state/connection_provider.dart';
import 'placeholder_message.dart';

class ConnectionStatusView extends StatefulWidget {
  const ConnectionStatusView({super.key});

  @override
  State<ConnectionStatusView> createState() => _ConnectionStatusViewState();
}

class _ConnectionStatusViewState extends State<ConnectionStatusView> {
  bool _isLoading = false;
  Map<String, dynamic>? _statusData;
  String? _errorMessage;
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchConnectionStatus();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchConnectionStatus() async {
    print('=== 开始获取连接状态 ===');
    
    final provider = context.read<ConnectionProvider>();
    final connection = provider.activeConnection;

    if (connection == null) {
      print('错误: 暂无连接');
      if (mounted) {
        setState(() {
          _errorMessage = '暂无连接';
          _isLoading = false;
        });
      }
      return;
    }

    print('当前连接: ${connection.address}');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        // 清空旧数据，确保UI能看到刷新效果
        _statusData = null;
      });
      print('设置 _isLoading = true, 清空旧数据');
    }

    try {
      print('发送获取状态请求...');
      final response = await BridgeTransport.post(
        connection: connection,
        payload: const {
          'protocol': 'cert',
          'routing': '/connect/status',
          'data': <String, dynamic>{},
          'receiver': '',
          'wait': true,
          'timeout': 30,
        },
      );

      print('获取状态响应: $response');
      print('响应类型: ${response.runtimeType}');
      
      final data = response['data'] as Map<String, dynamic>?;
      print('解析的data: $data');
      
      if (data != null) {
        print('节点总数: ${data['total']}');
        print('已连接: ${data['connected']}');
        print('已注册: ${data['registered']}');
        final nodes = data['nodes'] as List?;
        if (nodes != null) {
          print('节点列表长度: ${nodes.length}');
          for (var node in nodes) {
            print('  - 节点: ${node['bid_short']}, 状态: ${node['status']}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _statusData = data;
          _isLoading = false;
        });
        print('UI已更新: _isLoading = false, _statusData = $data');
      }
    } catch (e, stackTrace) {
      print('获取连接状态失败: $e');
      print('堆栈跟踪: $stackTrace');
      
      if (mounted) {
        setState(() {
          _errorMessage = '获取连接状态失败: ${e.toString()}';
          _isLoading = false;
        });
        print('设置 _isLoading = false (错误)');
      }
    }
    
    print('=== 获取连接状态结束 ===');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAddNodeDialog() {
    // 使用 StatefulBuilder 来管理对话框内的状态
    bool isAdding = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('添加节点'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请输入节点的IP地址和端口',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: '例如: 192.168.1.100:24001',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  enabled: !isAdding,
                  autofocus: true,
                  onSubmitted: (_) {
                    if (!isAdding) {
                      _handleAddNode(dialogContext, setDialogState, (value) {
                        isAdding = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '如果不指定端口，默认使用 24001',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isAdding ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: isAdding
                    ? null
                    : () {
                        _handleAddNode(dialogContext, setDialogState, (value) {
                          isAdding = value;
                        });
                      },
                child: isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAddNode(
    BuildContext dialogContext,
    StateSetter setDialogState,
    Function(bool) setIsAdding,
  ) async {
    final address = _addressController.text.trim();
    print('=== 开始添加节点 ===');
    print('输入地址: $address');
    
    if (address.isEmpty) {
      _showMessage('请输入节点地址');
      return;
    }

    final provider = context.read<ConnectionProvider>();
    final connection = provider.activeConnection;

    if (connection == null) {
      print('错误: 暂无连接');
      _showMessage('暂无连接');
      return;
    }

    print('当前连接: ${connection.address}');

    // 设置添加状态为加载中
    setDialogState(() {
      setIsAdding(true);
    });

    try {
      print('发送添加节点请求...');
      final response = await BridgeTransport.post(
        connection: connection,
        payload: {
          'protocol': 'cert',
          'routing': '/connect/add',
          'data': {'address': address},
          'receiver': '',
          'wait': true,
          'timeout': 10,
        },
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('添加节点超时');
          throw Exception('请求超时');
        },
      );

      print('添加节点响应: $response');
      print('响应 status_code: ${response['status_code']}');

      if (!mounted) return;

      // 检查响应状态码
      final statusCode = response['status_code'] as int?;
      if (statusCode != null && statusCode != 21) {
        final errorMsg = response['data']?['v'] ?? '添加失败';
        print('添加失败，状态码: $statusCode, 错误: $errorMsg');
        setDialogState(() {
          setIsAdding(false);
        });
        _showMessage('添加节点失败: $errorMsg');
      } else {
        _addressController.clear();
        print('关闭对话框');
        Navigator.of(dialogContext).pop(); // 关闭对话框
        _showMessage('节点添加成功，连接建立中...');
        
        print('延迟后刷新连接状态');
        // 延迟一下再刷新，给后端时间保存数据
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            print('执行刷新');
            _fetchConnectionStatus();
          }
        });
      }
    } catch (e, stackTrace) {
      print('添加节点失败: $e');
      print('堆栈跟踪: $stackTrace');
      
      if (mounted) {
        setDialogState(() {
          setIsAdding(false);
        });
        _showMessage('添加节点失败: ${e.toString()}');
      }
    }
    
    print('=== 添加节点流程结束 ===');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return PlaceholderMessage(text: _errorMessage!);
    }

    if (_statusData == null) {
      return const PlaceholderMessage(text: '暂无数据');
    }

    final total = _statusData!['total'] as int? ?? 0;
    final connected = _statusData!['connected'] as int? ?? 0;
    final registered = _statusData!['registered'] as int? ?? 0;
    final nodes = _statusData!['nodes'] as List<dynamic>? ?? [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchConnectionStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100), // 增加底部padding，为浮动按钮留空间
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(total, connected, registered),
              const SizedBox(height: 24),
              if (nodes.isNotEmpty) ...[
                const Text(
                  '节点列表',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...nodes.map((node) => _buildNodeCard(node as Map<String, dynamic>)),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '暂无连接节点',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNodeDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加节点'),
      ),
    );
  }

  Widget _buildSummaryCard(int total, int connected, int registered) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '连接概览',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('总数', total, Colors.blue),
              ),
              Expanded(
                child: _buildStatItem('已连接', connected, Colors.green),
              ),
              Expanded(
                child: _buildStatItem('已注册', registered, Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(Map<String, dynamic> node) {
    final bidShort = node['bid_short'] as String? ?? '';
    final status = node['status'] as String? ?? 'unknown';
    final hasWebsocket = node['has_websocket'] as bool? ?? false;
    final publicAddress = node['public_address'] as String?;
    final privateAddress = node['private_address'] as String?;
    final mac = node['mac'] as String?;
    
    // 获取节点数据
    final nodeData = node['node_data'] as Map<String, dynamic>?;
    final isPivot = nodeData?['pivot'] as bool? ?? false;
    final ipfsApi = nodeData?['ipfs_api'] as String?;
    
    // 获取签名数据
    final signatureData = node['signature_data'] as Map<String, dynamic>?;
    final permissionLevel = signatureData?['permission_level'] as int?;
    final validityPeriod = signatureData?['validity_period'] as String?;

    final statusColor = hasWebsocket ? Colors.green : Colors.orange;
    final statusText = status == 'connected' ? '已连接' : '已注册';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                bidShort,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 地址信息
          if (publicAddress != null) ...[
            _buildInfoRow('公网地址', publicAddress),
            const SizedBox(height: 6),
          ],
          if (privateAddress != null) ...[
            _buildInfoRow('内网地址', privateAddress),
            const SizedBox(height: 6),
          ],
          if (mac != null) ...[
            _buildInfoRow('MAC', mac),
            const SizedBox(height: 6),
          ],
          
          // 节点功能标签
          if (isPivot || permissionLevel != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPivot)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 12, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          '转发桥',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (permissionLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPermissionColor(permissionLevel).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getPermissionColor(permissionLevel).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 12,
                          color: _getPermissionColor(permissionLevel),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '权限 $permissionLevel',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getPermissionColor(permissionLevel),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          
          // IPFS API
          if (ipfsApi != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('IPFS', ipfsApi),
          ],
          
          // 有效期
          if (validityPeriod != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('有效期', _formatDate(validityPeriod)),
          ],
        ],
      ),
    );
  }

  Color _getPermissionColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
