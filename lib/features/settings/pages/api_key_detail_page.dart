import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_keys_manager.dart';

/// 密钥详情页面
class ApiKeyDetailPage extends StatefulWidget {
  const ApiKeyDetailPage({super.key, required this.apiKey});

  final Map<String, dynamic> apiKey;

  @override
  State<ApiKeyDetailPage> createState() => _ApiKeyDetailPageState();
}

class _ApiKeyDetailPageState extends State<ApiKeyDetailPage> {
  bool _isExporting = false;
  bool _isKeyVisible = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final bid = widget.apiKey['bid'] ?? '';
    final key = widget.apiKey['key'] ?? '';
    final name = widget.apiKey['name'] ?? '';
    final intro = widget.apiKey['intro'] ?? '';
    final model = widget.apiKey['model'] ?? '';

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
          '密钥详情',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 密钥图标和名称
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.vpn_key,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (intro.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        intro,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // BID
              _buildDetailField(
                label: 'BID',
                value: bid,
                icon: Icons.fingerprint,
                onCopy: () => _copyToClipboard(bid, 'BID'),
              ),
              
              const SizedBox(height: 24),
              
              // Key (可隐藏)
              _buildSecretField(
                label: 'Key',
                value: key,
                icon: Icons.vpn_key_outlined,
                isVisible: _isKeyVisible,
                onToggleVisibility: () {
                  setState(() {
                    _isKeyVisible = !_isKeyVisible;
                  });
                },
                onCopy: () => _copyToClipboard(key, 'Key'),
              ),
              
              const SizedBox(height: 24),
              
              // Model
              _buildDetailField(
                label: 'Model',
                value: model,
                icon: Icons.category_outlined,
                onCopy: () => _copyToClipboard(model, 'Model'),
                isMonospace: true,
              ),
              
              const SizedBox(height: 40),
              
              // 导出按钮
              _buildExportButton(),
              
              const SizedBox(height: 12),
              
              // 删除按钮
              _buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建详情字段
  Widget _buildDetailField({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
    bool isMonospace = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (onCopy != null)
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 18,
                  ),
                  onPressed: onCopy,
                  tooltip: '复制',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontFamily: isMonospace ? 'monospace' : null,
              letterSpacing: isMonospace ? 0.5 : 0.3,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 复制到剪贴板
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 已复制到剪贴板'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 构建密钥字段（可隐藏显示）
  Widget _buildSecretField({
    required String label,
    required String value,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    VoidCallback? onCopy,
  }) {
    final displayValue = isVisible ? value : '•' * 32;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
                onPressed: onToggleVisibility,
                tooltip: isVisible ? '隐藏' : '显示',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              if (onCopy != null)
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 18,
                  ),
                  onPressed: onCopy,
                  tooltip: '复制',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            displayValue,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: isVisible ? 0.5 : 2.0,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建导出按钮
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _exportKey,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_outlined, size: 22),
        label: Text(
          _isExporting ? '导出中...' : '导出密钥',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  /// 导出密钥
  Future<void> _exportKey() async {
    setState(() => _isExporting = true);
    
    try {
      // 构建 YAML 内容
      final yamlContent = '''bid: ${widget.apiKey['bid']}
key: ${widget.apiKey['key']}
name: ${widget.apiKey['name']}
intro: ${widget.apiKey['intro']}
model: ${widget.apiKey['model']}
''';

      // 生成默认文件名
      final fileName = '${widget.apiKey['name']}_${DateTime.now().millisecondsSinceEpoch}.yaml';
      
      // 使用系统保存对话框让用户选择保存位置
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['yaml'],
      );
      
      if (outputFile == null) {
        // 用户取消了保存
        if (!mounted) return;
        setState(() => _isExporting = false);
        return;
      }
      
      // 写入文件
      final file = File(outputFile);
      await file.writeAsString(yamlContent);
      
      if (!mounted) return;
      
      setState(() => _isExporting = false);
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('密钥已导出到:\n$outputFile'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '确定',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isExporting = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 构建删除按钮
  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isDeleting ? null : _deleteKey,
        icon: _isDeleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_outline, size: 22),
        label: Text(
          _isDeleting ? '删除中...' : '删除密钥',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withValues(alpha: 0.15),
          foregroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  /// 删除密钥
  Future<void> _deleteKey() async {
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
          '确定要删除密钥 "${widget.apiKey['name']}" 吗？此操作无法撤销。',
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

    setState(() => _isDeleting = true);

    try {
      final bid = widget.apiKey['bid'] as String;
      final success = await ApiKeysManager.deleteApiKey(bid);

      if (!mounted) return;

      setState(() => _isDeleting = false);

      if (success) {
        // 返回 true 表示删除成功
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDeleting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
