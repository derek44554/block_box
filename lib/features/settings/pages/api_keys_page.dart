import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yaml/yaml.dart';

import '../services/api_keys_manager.dart';


/// 密钥管理页面
/// 
/// 用于管理各种 API 密钥
class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({super.key});

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  List<Map<String, dynamic>> _apiKeys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  /// 加载密钥列表
  Future<void> _loadApiKeys() async {
    setState(() => _isLoading = true);
    try {
      final keys = await ApiKeysManager.getApiKeys();
      if (mounted) {
        setState(() {
          _apiKeys = keys;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载密钥失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '密钥管理',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70, size: 24),
            onPressed: _addNewApiKey,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white70,
                ),
              )
            : _apiKeys.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _apiKeys.length,
                    itemBuilder: (context, index) {
                      final apiKey = _apiKeys[index];
                      return _buildApiKeyItem(apiKey);
                    },
                  ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.key_off_outlined,
            color: Colors.white.withOpacity(0.2),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            '暂无 API 密钥',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加新密钥',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 API 密钥项
  Widget _buildApiKeyItem(Map<String, dynamic> apiKey) {
    final bid = apiKey['bid'] ?? '';
    final key = apiKey['key'] ?? '';
    final name = apiKey['name'] ?? '';
    final intro = apiKey['intro'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：图标、名称和删除按钮
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.vpn_key,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (intro.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          intro,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                  onPressed: () => _deleteApiKey(apiKey),
                  tooltip: '删除',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // BID
            _buildFieldRow(
              label: 'BID',
              value: bid,
              icon: Icons.fingerprint,
            ),
            
            const SizedBox(height: 12),
            
            // Key
            _buildFieldRow(
              label: 'Key',
              value: key,
              icon: Icons.vpn_key_outlined,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建字段行
  Widget _buildFieldRow({
    required String label,
    required String value,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.3),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontFamily: label == 'Intro' ? null : 'monospace',
                  letterSpacing: label == 'Intro' ? 0.3 : 0.5,
                  height: 1.4,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 添加新密钥
  Future<void> _addNewApiKey() async {
    try {
      // 选择文件（使用 any 类型，因为 Android 不支持 yaml 扩展名）
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: '选择密钥文件 (.yaml)',
      );

      if (result == null || result.files.isEmpty) {
        return; // 用户取消选择
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法获取文件路径'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 验证文件扩展名
      final fileName = result.files.single.name.toLowerCase();
      if (!fileName.endsWith('.yaml') && !fileName.endsWith('.yml')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择 .yaml 或 .yml 文件'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final file = File(filePath);
      
      // 显示加载对话框
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );

      try {
        // 读取文件内容
        final String content = await file.readAsString();
        
        // 解析 YAML
        final dynamic yamlData = loadYaml(content);
        
        if (yamlData is! YamlMap) {
          throw Exception('YAML 文件格式错误');
        }

        // 转换为 Map
        final Map<String, dynamic> keyData = {
          'bid': yamlData['bid']?.toString() ?? '',
          'key': yamlData['key']?.toString() ?? '',
          'name': yamlData['name']?.toString() ?? '',
          'intro': yamlData['intro']?.toString() ?? '',
          'model': yamlData['model']?.toString() ?? '',
        };

        // 添加到本地存储
        final success = await ApiKeysManager.addApiKey(keyData);
        
        if (!mounted) return;
        Navigator.of(context).pop(); // 关闭加载对话框

        if (success) {
          // 重新加载列表
          await _loadApiKeys();
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密钥添加成功'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密钥添加失败，请检查文件格式或密钥是否已存在'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // 关闭加载对话框
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择文件失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 删除密钥
  Future<void> _deleteApiKey(Map<String, dynamic> apiKey) async {
    final bid = apiKey['bid'] as String;
    
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '确认删除',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '确定要删除密钥 "$bid" 吗？此操作无法撤销。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 执行删除
    final success = await ApiKeysManager.deleteApiKey(bid);
    
    if (!mounted) return;
    
    if (success) {
      // 重新加载列表
      await _loadApiKeys();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('密钥已删除'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
